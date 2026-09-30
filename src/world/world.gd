class_name World
extends Node2D
## The live level: tiles, collision, entities, actors, camera, effects.
##
## main.gd builds one of these per area change and throws it away again. All
## state that has to survive the throw lives in the Game autoload instead.

signal travelled(area: String, spawn: String)
signal notify(text: String)
signal shake_requested(strength: float, time: float)
signal player_died()
signal boss_health(current: int, maximum: int, visible: bool)
signal boss_started()
signal boss_defeated()

const TILE := 16

var level_id := ""
var level: Dictionary = {}
var builder: LevelBuilder = null

var tiles: Node2D
var solids: Node2D
var entities: Node2D
var actors: Node2D
var fx: Node2D

var player: Player = null
var camera: Camera2D = null

var _crates: Array[Entity] = []
var _plates: Array[Entity] = []
var _shake_strength := 0.0
var _shake_time := 0.0
var _shake_base := Vector2.ZERO
var _player_spawn := Vector2i.ZERO
var _has_boss := false


# --------------------------------------------------------------------------
func build(area_id: String, spawn_id: String) -> void:
	level_id = area_id
	level = LevelData.get_level(area_id)
	_apply_grade()

	tiles = _new_node("Tiles")
	solids = _new_node("Solids")
	entities = _new_node("Entities")
	actors = _new_node("Actors")
	fx = _new_node("Fx")

	builder = LevelBuilder.build(level, tiles, solids)
	var clear := String(level.get("clear", "deep"))
	var bg := Polygon2D.new()
	var s := builder.world_rect().size
	bg.polygon = PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)])
	bg.color = _color(clear)
	bg.z_index = -20
	tiles.add_child(bg)

	_spawn_entities()
	_spawn_player(spawn_id)
	_setup_camera()
	_evaluate_plates()
	boss_health.emit(0, 0, false)
	add_to_group("world")


## A single CanvasModulate gives each area its own colour grade for free: the
## hollow goes cold and dim, the core goes hot, the village stays neutral.
func _apply_grade() -> void:
	var tint: Variant = level.get("tint", null)
	if tint == null:
		return
	var cm := CanvasModulate.new()
	cm.color = tint
	add_child(cm)


func _new_node(n: String) -> Node2D:
	var x := Node2D.new()
	x.name = n
	add_child(x)
	return x


func _color(name: String) -> Color:
	match name:
		"black":
			return Color(0.02, 0.02, 0.03)
		"deep":
			return Color(0.106, 0.078, 0.188)
	return Color(0.055, 0.043, 0.086)


# --------------------------------------------------------------------------
func _spawn_entities() -> void:
	for def in level.get("entities", []):
		var d: Dictionary = def
		var type := String(d.get("type", "spark"))
		if type in ["chest", "ember"]:
			_clear_for_pickup(Entity.to_cell(d.get("tile")))
		match type:
			"door":
				if not bool(d.get("no_tile", false)):
					builder.set_tile(Entity.to_cell(d.get("tile")), String(d.get("tile_name", "arch")))
			"plate":
				builder.set_tile(Entity.to_cell(d.get("tile")), "brick_floor")
			"brazier":
				builder.set_tile(Entity.to_cell(d.get("tile")), "stone_floor")
		var e := Entity.create(d, self)
		e.travelled.connect(_on_entity_travelled)
		e.notify.connect(_on_entity_notify)
		entities.add_child(e)
		e.build_visual()
		match type:
			"crate":
				_crates.append(e)
			"plate":
				_plates.append(e)
			"npc", "door", "chest", "sign", "brazier", "altar":
				pass
			"enemy":
				var en := Enemy.spawn(String(d.get("kind", "tick")), Entity.to_cell(d.get("tile")), self)
				add_enemy(en)
			"boss":
				_spawn_boss(Entity.to_cell(d.get("tile", [15, 7])))


func _spawn_boss(cell: Vector2i) -> void:
	var b := Boss.new()
	b.world = self
	b.position = Vector2(cell.x * TILE + 8, cell.y * TILE + 8)
	actors.add_child(b)
	b.engaged.connect(func():
		boss_started.emit()
		boss_health.emit(b.hp, b.MAX_HP, true))
	b.health_changed.connect(func(cur, mx): boss_health.emit(cur, mx, true))
	b.defeated.connect(func():
		boss_health.emit(0, 0, false)
		boss_defeated.emit())
	_has_boss = true


## Scenery is authored by seeded scatter and content by hand, so the two can
## collide: a lamp post lands where a chest was placed. A pickup outranks
## scenery, so it clears the prop back to the ground underneath. If the ground
## itself is a wall (a genuine authoring mistake) step out to a free neighbour.
func _clear_for_pickup(cell: Vector2i) -> void:
	var top := builder.tile_at(cell)
	if not LevelBuilder.is_solid(top):
		return
	var ground := builder.ground_at(cell)
	if not builder.is_solid(ground):
		builder.set_tile(cell, ground)
		return
	var fixed := _free_cell(cell)
	if fixed != cell:
		builder.set_tile(cell, builder.ground_at(fixed))
		push_warning("pickup at %s sat inside %s; ground cleared", [cell, top])


func _spawn_player(spawn_id: String) -> void:
	var spawns: Dictionary = level.get("spawns", {})
	var cell := Vector2i(4, 4)
	if spawns.has(spawn_id):
		cell = spawns[spawn_id]
	elif spawns.has("start"):
		cell = spawns["start"]
	elif not spawns.is_empty():
		cell = spawns.values()[0]
	cell = _free_cell(cell)
	_player_spawn = cell
	player = Player.new()
	player.world = self
	actors.add_child(player)
	player.position = Vector2(cell.x * TILE + 8, cell.y * TILE + 8)
	player.died.connect(func(): player_died.emit())


## If a spawn point is buried in geometry, step out to the nearest free tile so
## the player never starts stuck inside a wall.
func _free_cell(cell: Vector2i) -> Vector2i:
	if not builder.is_solid(builder.tile_at(cell)):
		return cell
	for r in range(1, 8):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var c := Vector2i(cell.x + dx, cell.y + dy)
				if builder.in_bounds(c) and not builder.is_solid(builder.tile_at(c)):
					return c
	return cell


func _setup_camera() -> void:
	camera = Camera2D.new()
	camera.zoom = Vector2(2.0, 2.0)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 9.0
	var r := builder.world_rect()
	camera.limit_left = int(r.position.x)
	camera.limit_top = int(r.position.y)
	camera.limit_right = int(r.position.x + r.size.x)
	camera.limit_bottom = int(r.position.y + r.size.y)
	add_child(camera)
	camera.make_current()
	camera.global_position = player.global_position
	_shake_base = camera.global_position


# --------------------------------------------------------------------------
# queries used by actors and entities
# --------------------------------------------------------------------------
func get_player() -> Node2D:
	return player


func player_cell() -> Vector2i:
	if player == null:
		return Vector2i.ZERO
	return Vector2i(int(player.position.x / TILE), int(player.position.y / TILE))


func tile_name(cell: Vector2i) -> String:
	return builder.tile_at(cell) if builder != null else "void"


func is_blocked(cell: Vector2i, flying: bool = false) -> bool:
	if not builder.in_bounds(cell):
		return true
	var name := builder.tile_at(cell)
	if flying and (name == "water" or name == "water_deep" or name == "lava" or name == "hole"):
		return false
	return LevelBuilder.is_solid(name)


func bullet_blocked(pos: Vector2) -> bool:
	var cell := Vector2i(int(pos.x / TILE), int(pos.y / TILE))
	return is_blocked(cell, true)


## What stops a crate from being pushed into this cell. Plates are flush with
## the floor, so a crate must be allowed to land on one.
func has_blocker_at(cell: Vector2i) -> bool:
	if is_blocked(cell):
		return true
	for c in _crates:
		if c.cell == cell:
			return true
	return false


# --------------------------------------------------------------------------
# combat
# --------------------------------------------------------------------------
func player_swing(origin: Vector2, facing: Vector2) -> void:
	var hit := false
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or not (e is Node2D):
			continue
		var to: Vector2 = (e as Node2D).global_position - origin
		if to.length() > 24.0:
			continue
		if to.normalized().dot(facing) < 0.15:
			continue
		if e.has_method("hurt"):
			e.hurt(1, origin)
			hit = true
			spawn_hit_spark((e as Node2D).global_position)
	if hit:
		Sfx.play("hit", -1.0, randf_range(0.95, 1.08))
		shake(2.5, 0.12)


func spawn_hit_spark(pos: Vector2) -> void:
	for i in 6:
		var s := Sprite2D.new()
		s.texture = load("res://assets/bullet.png")
		s.centered = true
		s.region_enabled = false
		s.hframes = 4
		s.position = pos
		s.scale = Vector2(0.5, 0.5)
		fx.add_child(s)
		var dir := Vector2.RIGHT.rotated(TAU * float(i) / 6.0)
		var tw := create_tween()
		tw.tween_property(s, "position", pos + dir * 12.0, 0.22)
		tw.parallel().tween_property(s, "modulate:a", 0.0, 0.22)
		tw.tween_callback(s.queue_free)


func player_moved(p: Player) -> void:
	var cell := Vector2i(int(p.position.x / TILE), int(p.position.y / TILE))
	for node in get_tree().get_nodes_in_group("pickup"):
		if node is Entity:
			var e := node as Entity
			if e.cell == cell:
				e.pickup_here(cell)
	if not p.is_locked() and tile_name(cell) == "lava":
		p.take_damage(1, p.position + Vector2(0, 1))


func _evaluate_plates() -> void:
	for pl in _plates:
		var pressed := false
		for c in _crates:
			if c.cell == pl.cell:
				pressed = true
				break
		pl.set_meta("pressed", pressed)
		pl.refresh()
	_check_vault()


func add_enemy(e: Enemy) -> void:
	actors.add_child(e)
	e.killed.connect(_on_enemy_killed)


func _on_enemy_killed(e: Node) -> void:
	spawn_hit_spark((e as Node2D).global_position)


func _on_entity_travelled(area: String, spawn: String) -> void:
	travelled.emit(area, spawn)


func _on_entity_notify(text: String) -> void:
	notify.emit(text)


func on_crate_moved(crate: Entity) -> void:
	spawn_ring(crate.global_position, 18.0, Color(0.8, 0.7, 0.5))
	_evaluate_plates()


func _check_vault() -> void:
	var pressed := 0
	for pl in _plates:
		if bool(pl.get_meta("pressed", false)):
			pressed += 1
	if pressed == _plates.size() and _plates.size() > 0 and not Game.has_flag("vault_open"):
		Game.set_flag("vault_open", true)
		Sfx.play("objective")
		notify.emit("Three plates. The vault is open.")
		shake(4.0, 0.6)
		spawn_text(player.global_position + Vector2(0, -24), "THE VAULT OPENS",
			Color(0.95, 0.8, 0.4))
		for node in entities.get_children():
			if node is Entity and (node as Entity).kind == Entity.KIND_GATE:
				(node as Entity).refresh()


# --------------------------------------------------------------------------
# items dropped by enemies
# --------------------------------------------------------------------------
func spawn_drop(item: String, qty: int, at: Vector2) -> void:
	var e := Entity.create({
		"type": Entity.KIND_DROP,
		"item": item,
		"qty": qty,
		"id": "drop_%d" % int(Time.get_ticks_msec()),
	}, self)
	e.cell = Vector2i(int(at.x / TILE), int(at.y / TILE))
	e.position = at
	entities.add_child(e)
	e.build_visual()


# --------------------------------------------------------------------------
# effects
# --------------------------------------------------------------------------
func add_fx(n: Node2D) -> void:
	fx.add_child(n)


func shake(strength: float, time: float) -> void:
	_shake_strength = maxf(_shake_strength, strength)
	_shake_time = maxf(_shake_time, time)
	shake_requested.emit(_shake_strength, _shake_time)


func spawn_ring(at: Vector2, radius: float, color: Color) -> void:
	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * float(i) / 20.0
		pts.append(Vector2(cos(a) * 4.0, sin(a) * 2.0))
	poly.polygon = pts
	poly.color = color
	poly.position = at
	fx.add_child(poly)
	var tw := create_tween()
	tw.tween_property(poly, "scale", Vector2(radius / 4.0, radius / 2.0), 0.35)
	tw.parallel().tween_property(poly, "modulate:a", 0.0, 0.35)
	tw.tween_callback(poly.queue_free)


func spawn_text(at: Vector2, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	l.position = at
	l.z_index = 20
	fx.add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position", at + Vector2(0, -22), 1.4)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.4)
	tw.tween_callback(l.queue_free)


func _process(delta: float) -> void:
	if builder != null:
		builder.animate_water(delta)
	if camera != null and player != null:
		var target := player.global_position
		if _shake_time > 0.0:
			_shake_time -= delta
			var amp := _shake_strength * clampf(_shake_time * 4.0, 0.0, 1.0)
			target += Vector2(randf_range(-amp, amp), randf_range(-amp, amp))
			if _shake_time <= 0.0:
				_shake_strength = 0.0
		camera.global_position = camera.global_position.lerp(target, 0.28)


# --------------------------------------------------------------------------
# interaction
# --------------------------------------------------------------------------
func nearest_interactable(origin: Vector2, facing: Vector2) -> Entity:
	var best: Entity = null
	var best_d := 26.0
	for n in get_tree().get_nodes_in_group("interactable"):
		if not (n is Entity):
			continue
		var e := n as Entity
		if not e.is_active():
			continue
		var to: Vector2 = e.global_position + Vector2(0, 6) - origin
		var d := to.length()
		if d > best_d:
			continue
		if d > 6.0 and to.normalized().dot(facing) < 0.25:
			continue
		best = e
		best_d = d
	return best


# --------------------------------------------------------------------------
func boss_health_hidden() -> void:
	_has_boss = false
	boss_health.emit(0, 0, false)


func find_boss() -> Boss:
	for n in get_tree().get_nodes_in_group("boss"):
		if n is Boss:
			return n
	return null
