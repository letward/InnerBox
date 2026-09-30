class_name Entity
extends Node2D
## Everything in a level that is not a tile or the player: NPCs, doors, chests,
## signs, braziers, pickups, pushable crates, pressure plates, the vault gate,
## the memory well and decorative sparks.
##
## One script, many kinds. Every kind answers three questions: what am I
## called when the player walks up to me, what happens when they press
## interact, and does something happen on my own (pickups, plates).

signal talked(node_id: String)
signal travelled(area: String, spawn: String)
signal notify(text: String)

const KIND_NPC := "npc"
const KIND_DOOR := "door"
const KIND_CHEST := "chest"
const KIND_SIGN := "sign"
const KIND_BRAZIER := "brazier"
const KIND_ALTAR := "altar"
const KIND_EMBER := "ember"
const KIND_CRATE := "crate"
const KIND_PLATE := "plate"
const KIND_GATE := "gate"
const KIND_WELL := "well"
const KIND_SPARK := "spark"
const KIND_DROP := "drop"

const TILE := 16
const ATLAS := "res://assets/tiles.png"
const ITEMS_TEX := "res://assets/items.png"

var kind := ""
var def: Dictionary = {}
var world: Node = null
var cell := Vector2i.ZERO
var sprite: Sprite2D = null
var solid_body: StaticBody2D = null

var used := false                 # chests, doors that have fired, etc.
var _t := 0.0


# --------------------------------------------------------------------------
static func to_cell(v: Variant) -> Vector2i:
	## Level data stores cells as [x, y] arrays; JSON-ish data is easier to read.
	if v is Vector2i:
		return v
	if v is Array and v.size() >= 2:
		return Vector2i(int(v[0]), int(v[1]))
	return Vector2i.ZERO


static func create(definition: Dictionary, world_ref: Node) -> Entity:
	var e := Entity.new()
	e.kind = String(definition.get("type", "spark"))
	e.def = definition
	e.world = world_ref
	e.cell = to_cell(definition.get("tile", [0, 0]))
	e.name = "%s_%s_%d_%d" % [e.kind, String(definition.get("id", "x")),
		e.cell.x, e.cell.y]
	e.position = Vector2(e.cell.x * TILE, e.cell.y * TILE)
	return e


func _ready() -> void:
	match kind:
		KIND_NPC, KIND_DOOR, KIND_CHEST, KIND_SIGN, KIND_BRAZIER, KIND_ALTAR, KIND_CRATE:
			add_to_group("interactable")
	match kind:
		KIND_EMBER:
			add_to_group("pickup")
	match kind:
		KIND_CRATE, KIND_PLATE, KIND_GATE:
			add_to_group("logic")


func _process(delta: float) -> void:
	_t += delta
	match kind:
		KIND_NPC:
			_animate_idle()
		KIND_SPARK:
			_animate_spark()
		KIND_EMBER:
			sprite.position.y = sin(_t * 3.0) * 2.0
			sprite.modulate.a = 0.75 + 0.25 * sin(_t * 4.0)


# --------------------------------------------------------------------------
# appearance
# --------------------------------------------------------------------------
func build_visual() -> void:
	match kind:
		KIND_NPC:
			sprite = _char_sprite("res://assets/npc_%s.png" % String(def.get("id", "pip")), 3, 3)
			sprite.frame = _row_for(String(def.get("face", "down")))
			sprite.offset = Vector2(0, -10)
		KIND_DOOR:
			sprite = _tile_sprite("arch")
		KIND_CHEST:
			sprite = _tile_sprite("chest_closed")
		KIND_SIGN:
			sprite = _tile_sprite("sign")
		KIND_BRAZIER:
			sprite = _tile_sprite("brazier_on" if Game.has_flag(_flag()) else "brazier_off")
		KIND_ALTAR:
			sprite = _tile_sprite("crystal")
			sprite.modulate = Color(0.45, 0.42, 0.6, 1.0) if not _altar_ready() else Color(1, 1, 1, 1)
		KIND_EMBER:
			sprite = _icon_sprite(ItemData.ICON_EMBER)
		KIND_PLATE:
			sprite = _tile_sprite("gold_trim" if _plate_pressed() else "grate")
		KIND_GATE:
			sprite = _tile_sprite("gold_trim")
		KIND_WELL:
			sprite = _tile_sprite("crystal")
			sprite.scale = Vector2(1.6, 1.6)
			sprite.position = Vector2(0, -8)
		KIND_SPARK:
			sprite = _tile_sprite("core_glow")
			sprite.scale = Vector2(0.45, 0.45)
			sprite.position = Vector2(0, -4)
		KIND_DROP:
			sprite = _icon_sprite(ItemData.item_icon(String(def.get("item", "gear"))))
			sprite.scale = Vector2(0.75, 0.75)
	if sprite != null:
		add_child(sprite)
		if kind == KIND_CRATE:
			_make_solid()
		elif kind == KIND_GATE and not Game.has_flag(String(def.get("solid_until", ""))):
			_make_solid()


func _make_solid() -> void:
	solid_body = StaticBody2D.new()
	solid_body.collision_layer = 1
	solid_body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TILE, TILE)
	shape.shape = rect
	solid_body.add_child(shape)
	add_child(solid_body)


func _tile_sprite(tile_name: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.texture = load(ATLAS)
	s.region_enabled = true
	var idx := TileIndex.id(tile_name)
	s.region_rect = Rect2((idx % TileIndex.COLUMNS) * TILE, (idx / TileIndex.COLUMNS) * TILE, TILE, TILE)
	return s


func _icon_sprite(icon: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.texture = load(ITEMS_TEX)
	s.region_enabled = true
	s.region_rect = ItemData.region(icon)
	return s


func _char_sprite(path: String, cols: int, rows: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.texture = load(path)
	s.hframes = cols
	s.vframes = rows
	return s


func _row_for(face: String) -> int:
	match face:
		"up":
			return 1
		"left", "right":
			return 2
	return 0


# --------------------------------------------------------------------------
# interaction
# --------------------------------------------------------------------------
func is_active() -> bool:
	match kind:
		KIND_CHEST:
			return not Game.has_flag("opened_" + String(def.get("id", "")))
		KIND_EMBER:
			return not used
		KIND_PLATE, KIND_SPARK, KIND_BRAZIER, KIND_ALTAR, KIND_WELL, KIND_SIGN, KIND_NPC:
			return true
		KIND_DOOR:
			return true
		KIND_GATE:
			return not Game.has_flag(String(def.get("solid_until", "")))
	return true


func get_prompt() -> String:
	match kind:
		KIND_NPC:
			return "Talk"
		KIND_CHEST:
			return "Open"
		KIND_SIGN:
			return "Read"
		KIND_DOOR:
			return "Enter " + String(def.get("label", "door"))
		KIND_BRAZIER:
			if Game.has_flag(_flag()):
				return ""
			return "Light brazier" if Game.has_item("ember") else "Needs an Ember"
		KIND_ALTAR:
			return "Reach out" if _altar_ready() else ""
		KIND_CRATE:
			return "Push"
		KIND_WELL:
			return "Set the shards"
	return ""


## Returns "" if nothing to say, otherwise a dialogue node id.
func interact(player: Node2D) -> String:
	match kind:
		KIND_NPC:
			return _npc_line()
		KIND_SIGN:
			return String(def.get("node", "sign_village"))
		KIND_CHEST:
			return _open_chest()
		KIND_BRAZIER:
			return _light_brazier()
		KIND_ALTAR:
			if _altar_ready():
				return "box_brazier_all"
			return ""
		KIND_CRATE:
			_push(player)
			return ""
		KIND_GATE:
			return ""
		KIND_WELL:
			return _use_well()
		KIND_DOOR:
			_enter_door()
			return ""
	return ""


# ---- npc -----------------------------------------------------------------
func _npc_line() -> String:
	var who := String(def.get("id", "pip"))
	match who:
		"elder":
			if Game.has_flag("ending_seen"):
				return "elder_after"
			if Game.is_quest_active("shattered_latch"):
				return "elder_intro"
			if Game.is_quest_active("amber_light"):
				if Game.has_flag("shard_from_wood"):
					return "elder_wait_shard" if not Game.has_item("shard") else "elder_shard_back"
				if Game.item_count("ember") < 3:
					return "elder_wait_ambers"
				return "elder_wait_lights"
			if Game.is_quest_active("what_the_box_remembers"):
				return "elder_wait_well"
			if Game.is_quest_active("corroded_heart"):
				return "elder_wait_core"
			if Game.is_quest_active("iron_tongue"):
				if not Game.has_item("key"):
					return "elder_wait_key"
				return "elder_wait_gate"
			return "elder_idle"
		"tink":
			return "tink_intro"
		"pip":
			if Game.has_flag("has_crank"):
				return "pip_crank_done"
			if Game.has_item("crank"):
				return "pip_crank_give"
			if Game.quest_state("paper_moon") == "done":
				return "pip_crank_ask"
			if Game.has_item("moon"):
				return "pip_again"
			return "pip_intro"
	return "pip_idle"


func _animate_idle() -> void:
	if sprite == null:
		return
	var row := _row_for(String(def.get("face", "down")))
	if row == 0:
		sprite.frame = row * 3 + (1 if fmod(_t, 3.0) < 0.35 else 0)
	else:
		sprite.frame = row * 3


# ---- chest ---------------------------------------------------------------
func _open_chest() -> String:
	var lock := String(def.get("locked_flag", ""))
	if lock != "" and not Game.has_flag(lock):
		var txt := String(def.get("locked_text", "It will not open."))
		notify.emit(txt)
		Sfx.play("block")
		return ""
	var cid := String(def.get("id", ""))
	if Game.has_flag("opened_" + cid):
		notify.emit("Empty.")
		return ""
	Game.set_flag("opened_" + cid, true)
	var item := String(def.get("item", "coin"))
	var qty := int(def.get("qty", 1))
	Game.add_item(item, qty)
	Sfx.play("pickup")
	notify.emit("Found %s%s" % [ItemData.item_name(item), " x%d" % qty if qty > 1 else ""])
	if sprite != null:
		sprite.region_rect = Rect2(
			(TileIndex.id("chest_open") % TileIndex.COLUMNS) * TILE,
			(TileIndex.id("chest_open") / TileIndex.COLUMNS) * TILE, TILE, TILE)
		if qty > 1:
			var dup := _icon_sprite(ItemData.item_icon(item))
			dup.position = Vector2(0, -10)
			add_child(dup)
			var tw := create_tween()
			tw.tween_property(dup, "position", Vector2(0, -40), 0.8)
			tw.parallel().tween_property(dup, "modulate:a", 0.0, 0.8)
			tw.tween_callback(dup.queue_free)
	return ""


# ---- brazier / altar -----------------------------------------------------
func _flag() -> String:
	return "lit_" + String(def.get("id", "brazier"))


func _light_brazier() -> String:
	if Game.has_flag(_flag()):
		return ""
	if not Game.has_item("ember"):
		notify.emit("The brazier is cold. It needs an Ember.")
		Sfx.play("block")
		return ""
	Game.remove_item("ember")
	Game.set_flag(_flag(), true)
	Sfx.play("pickup")
	if sprite != null:
		sprite.region_rect = Rect2(
			(TileIndex.id("brazier_on") % TileIndex.COLUMNS) * TILE,
			(TileIndex.id("brazier_on") / TileIndex.COLUMNS) * TILE, TILE, TILE)
		var tw := create_tween()
		tw.tween_property(sprite, "scale", Vector2(1.25, 1.25), 0.12)
		tw.tween_property(sprite, "scale", Vector2.ONE, 0.18)
	var lit := 0
	for k in ["brazier_w1", "brazier_w2", "brazier_w3"]:
		if Game.has_flag("lit_" + k):
			lit += 1
	if lit >= 3:
		Game.set_flag("all_lights", true)
		notify.emit("The wood remembers its shape.")
		Sfx.play("objective")
	return "box_brazier"


func _altar_ready() -> bool:
	return Game.has_flag("all_lights") and not Game.has_flag("shard_from_wood")


# ---- door ----------------------------------------------------------------
func _enter_door() -> void:
	var need := String(def.get("needs_item", ""))
	if need != "" and not Game.has_item(need):
		notify.emit(String(def.get("locked_text", "It is locked.")))
		Sfx.play("block")
		return
	Sfx.play("door")
	_apply_on_enter(def.get("on_enter", {}))
	travelled.emit(String(def.get("to", "")), String(def.get("spawn", "start")))


## A door can close a quest and open the next one as you step through it.
func _apply_on_enter(fx: Dictionary) -> void:
	if fx.is_empty():
		return
	if fx.has("done"):
		Game.complete_quest(String(fx["done"]))
	if fx.has("quest"):
		Game.start_quest(String(fx["quest"]))
	if fx.has("flag"):
		Game.set_flag(String(fx["flag"]), true)


# ---- crate ---------------------------------------------------------------
func _push(player: Node2D) -> void:
	if player == null or world == null:
		return
	var dir: Vector2 = player.facing_vector()
	if dir == Vector2.ZERO:
		return
	var target: Vector2i = cell + Vector2i(roundi(dir.x), roundi(dir.y))
	if world.has_blocker_at(target):
		Sfx.play("block")
		return
	cell = target
	position = Vector2(cell.x * TILE, cell.y * TILE)
	Sfx.play("push")
	var target_player: Vector2i = cell - Vector2i(roundi(dir.x), roundi(dir.y))
	if world.get_player_cell() == target_player:
		player.push_blocked(dir)
	world.on_crate_moved(self)


# ---- plate ---------------------------------------------------------------
func _plate_pressed() -> bool:
	return bool(get_meta("pressed", false))


func refresh() -> void:
	if sprite == null:
		return
	if kind == KIND_PLATE:
		var idx := TileIndex.id("gold_trim" if _plate_pressed() else "grate")
		sprite.region_rect = Rect2((idx % TileIndex.COLUMNS) * TILE, (idx / TileIndex.COLUMNS) * TILE, TILE, TILE)
	elif kind == KIND_ALTAR:
		sprite.modulate = Color(1, 1, 1, 1) if _altar_ready() else Color(0.45, 0.42, 0.6, 1.0)
	elif kind == KIND_GATE:
		var open_now := Game.has_flag(String(def.get("solid_until", "")))
		if open_now:
			if solid_body != null:
				solid_body.queue_free()
				solid_body = null
			sprite.visible = false
		else:
			sprite.visible = true


# ---- well ----------------------------------------------------------------
func _use_well() -> String:
	var shards := Game.item_count("shard")
	if Game.has_flag("ending_seen"):
		notify.emit("It is already open.")
		return ""
	if shards >= 3:
		Game.set_flag("ending_seen", true)
		return "ending"
	return "box_well_wait"


# ---- sparkle -------------------------------------------------------------
func _animate_spark() -> void:
	if sprite == null:
		return
	sprite.position.y = -4.0 + sin(_t * 2.0 + float(cell.x)) * 3.0
	sprite.position.x = sin(_t * 1.3 + float(cell.y)) * 2.0
	sprite.modulate.a = 0.35 + 0.35 * (0.5 + 0.5 * sin(_t * 2.6 + float(cell.x + cell.y)))


func pickup_here(_player_cell: Vector2i) -> void:
	if used:
		return
	used = true
	var item := String(def.get("item", "ember"))
	var qty := int(def.get("qty", 1))
	Game.add_item(item, qty)
	Sfx.play("pickup")
	if kind == KIND_EMBER:
		Game.set_flag("got_" + String(def.get("id", "")), true)
		notify.emit("Picked up an Ember.")
	else:
		notify.emit("Found %s." % ItemData.item_name(item))
	if sprite != null:
		var tw := create_tween()
		tw.tween_property(sprite, "position", Vector2(0, -30), 0.35)
		tw.parallel().tween_property(sprite, "modulate:a", 0.0, 0.35)
		tw.tween_callback(func():
			remove_from_group("pickup")
			queue_free())
