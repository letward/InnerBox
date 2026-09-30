extends Node
## Story/content integrity check. Run headless:
##   godot --headless --script res://tools/verify_story.gd
##
## Checks that every cross-reference in the content data resolves, then walks
## the whole quest chain the way a player would and asserts the ending is
## reachable. Exits non-zero on the first failure count.

var errors: Array[String] = []
var checks := 0


func _ready() -> void:
	check_dialogue_graph()
	check_item_refs()
	check_quest_refs()
	check_tiles()
	check_doors()
	check_spawns()
	check_reachable_items()
	simulate_playthrough()

	print("\n=== %d checks, %d problems ===" % [checks, errors.size()])
	for e in errors:
		print("  FAIL: ", e)
	if errors.is_empty():
		print("  all good")
	get_tree().quit(0 if errors.is_empty() else 1)


func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		errors.append(msg)


# --------------------------------------------------------------------------
func check_dialogue_graph() -> void:
	for id in DialogueData.LINES.keys():
		var node: Dictionary = DialogueData.LINES[id]
		ok(node.has("lines") and (node["lines"] as Array).size() > 0,
			"dialogue '%s' has no lines" % id)
		ok(node.has("portrait"), "dialogue '%s' has no portrait" % id)
		ok(not String(node.get("speaker", "")).is_empty()
			or String(node.get("portrait", "")) == "box",
			"dialogue '%s' has neither speaker nor narrator portrait" % id)
		for ch in node.get("choices", []):
			var nxt := String((ch as Dictionary).get("next", ""))
			if nxt != "":
				ok(DialogueData.LINES.has(nxt),
					"dialogue '%s' points at missing node '%s'" % [id, nxt])
			for key in ["flag", "quest", "done"]:
				var v := String((ch as Dictionary).get("effects", {}).get(key, ""))
				if key == "flag":
					continue
				ok(v == "" or QuestData.QUESTS.has(v),
					"dialogue '%s' effect %s -> unknown quest '%s'" % [id, key, v])
			var give = (ch as Dictionary).get("effects", {}).get("give", null)
			if give != null:
				ok(ItemData.ITEMS.has(String((give as Array)[0])),
					"dialogue '%s' gives unknown item '%s'" % [id, str((give as Array)[0])])


func check_item_refs() -> void:
	for level_id in LevelData.LEVELS.keys():
		for e in (LevelData.LEVELS[level_id]["entities"] as Array):
			var d: Dictionary = e
			if d.has("item"):
				ok(ItemData.ITEMS.has(String(d["item"])),
					"level %s entity gives unknown item '%s'" % [level_id, str(d["item"])])
	for e in DialogueData.LINES.values():
		for ch in e.get("choices", []):
			var fx: Dictionary = (ch as Dictionary).get("effects", {})
			for key in ["give", "take"]:
				if fx.has(key):
					ok(ItemData.ITEMS.has(String((fx[key] as Array)[0])),
						"effect %s references unknown item" % key)
			for pair in fx.get("extra", []):
				ok(ItemData.ITEMS.has(String((pair as Array)[0])),
					"effect extra references unknown item '%s'" % str((pair as Array)[0]))


func check_quest_refs() -> void:
	for id in QuestData.QUESTS.keys():
		ok(not String(QuestData.objective_for(id)).is_empty(),
			"quest '%s' has no objective text" % id)
		ok(not QuestData._target_for(id).is_empty(),
			"quest '%s' has no world target" % id)
		var t := QuestData._target_for(id)
		if not t.is_empty():
			ok(LevelData.LEVELS.has(String(t["area"])),
				"quest '%s' targets unknown area '%s'" % [id, t["area"]])
			var lvl: Dictionary = LevelData.get_level(String(t["area"]))
			var c: Vector2i = t["cell"]
			ok(c.x >= 0 and c.y >= 0 and c.x < int(lvl["size"].x) and c.y < int(lvl["size"].y),
				"quest '%s' target cell out of bounds" % id)


func check_tiles() -> void:
	var ops_tiles := {
		"rect": ["tile"], "frame": ["tile"], "hline": ["tile"], "vline": ["tile"],
		"path": ["tile"], "blob": ["tile"], "set": ["tile"], "scatter": ["tile"],
		"house": [],
	}
	for level_id in LevelData.LEVELS.keys():
		var lvl: Dictionary = LevelData.LEVELS[level_id]
		ok(TileIndex.has(String(lvl.get("base", ""))),
			"level %s base tile '%s' does not exist" % [level_id, str(lvl.get("base"))])
		for op in lvl["ops"]:
			var d: Dictionary = op
			var kind := String(d.get("op", ""))
			ok(ops_tiles.has(kind), "level %s uses unknown op '%s'" % [level_id, kind])
			for key in ops_tiles.get(kind, []):
				ok(TileIndex.has(String(d.get(key, ""))),
					"level %s op %s references unknown tile '%s'"
					% [level_id, kind, str(d.get(key))])
		for e in lvl["entities"]:
			var d2: Dictionary = e
			if d2.has("tile_name"):
				ok(TileIndex.has(String(d2["tile_name"])),
					"level %s door uses unknown tile '%s'" % [level_id, str(d2["tile_name"])])
			if d2.has("node"):
				ok(DialogueData.LINES.has(String(d2["node"])),
					"level %s sign points at missing dialogue '%s'" % [level_id, str(d2["node"])])


func check_doors() -> void:
	for level_id in LevelData.LEVELS.keys():
		for e in (LevelData.LEVELS[level_id]["entities"] as Array):
			var d: Dictionary = e
			if String(d.get("type", "")) != "door":
				continue
			var to := String(d.get("to", ""))
			ok(LevelData.LEVELS.has(to),
				"level %s has a door to unknown area '%s'" % [level_id, to])
			if LevelData.LEVELS.has(to):
				var dest: Dictionary = LevelData.LEVELS[to]
				ok((dest["spawns"] as Dictionary).has(String(d.get("spawn", ""))),
					"door %s -> %s points at unknown spawn '%s'"
					% [level_id, to, str(d.get("spawn"))])
			if d.has("needs_item"):
				ok(ItemData.ITEMS.has(String(d["needs_item"])),
					"door in %s needs unknown item" % level_id)


func check_spawns() -> void:
	for level_id in LevelData.LEVELS.keys():
		var lvl: Dictionary = LevelData.LEVELS[level_id]
		ok(not (lvl["spawns"] as Dictionary).is_empty(),
			"level %s has no spawn points" % level_id)
		for sname in (lvl["spawns"] as Dictionary).keys():
			var c: Vector2i = lvl["spawns"][sname]
			ok(c.x >= 0 and c.y >= 0 and c.x < int(lvl["size"].x) and c.y < int(lvl["size"].y),
				"level %s spawn '%s' is out of bounds" % [level_id, sname])


## Every chest/pickup must actually be reachable. Scenery is seeded scatter and
## content is hand-placed, so a lamp post can land on a chest; World clears the
## prop back to the ground at load time. What must never happen is a pickup
## authored inside a wall, because nothing can rescue that.
const WALLS := [
	"stone_wall", "stone_wall_top", "moss_stone", "wood_wall", "roof",
	"window_wall", "house_door", "marble_wall", "gold_trim", "pillar",
	"water", "water_deep",
]


func check_reachable_items() -> void:
	var rescued := 0
	for level_id in LevelData.LEVELS.keys():
		var lvl: Dictionary = LevelData.LEVELS[level_id]
		var tiles := Node2D.new()
		var solids := Node2D.new()
		add_child(tiles)
		add_child(solids)
		var b := LevelBuilder.build(lvl, tiles, solids)
		for e in lvl["entities"]:
			var d: Dictionary = e
			var t := String(d.get("type", ""))
			if t != "chest" and t != "ember":
				continue
			var c := Entity.to_cell(d.get("tile"))
			ok(b.in_bounds(c), "level %s entity %s out of bounds" % [level_id, t])
			var tile := b.tile_at(c)
			ok(not WALLS.has(tile),
				"level %s: %s at %s is inside a wall (%s)" % [level_id, t, str(c), tile])
			# resolve the same way World does and require the result to be usable
			var resolved := b.ground_at(c) if LevelBuilder.is_solid(tile) else tile
			ok(not LevelBuilder.is_solid(resolved),
				"level %s: %s at %s cannot be reached" % [level_id, t, str(c)])
			if LevelBuilder.is_solid(tile):
				rescued += 1
		tiles.queue_free()
		solids.queue_free()
	print("   (%d pickups sit on scenery and are cleared to the ground at load)"
		% rescued)


# --------------------------------------------------------------------------
## Walk the intended path through the game the way a player would and assert
## the state machine actually gets to the ending.
func simulate_playthrough() -> void:
	Game.new_game(true)

	# --- act 1: talk to the elder
	Game.complete_quest("shattered_latch")
	Game.start_quest("amber_light")
	ok(Game.quest_state("amber_light") == "active", "amber_light did not start")
	ok(QuestData.current_target() != {}, "no target after act 1")
	ok(String(QuestData.objective_for("amber_light")).contains("Ember"),
		"objective for amber_light does not mention embers")

	# --- act 2: embers + braziers
	Game.add_item("ember", 3)
	ok(QuestData.objective_for("amber_light").contains("brazier"),
		"objective does not move to braziers with 3 embers")
	for id in ["brazier_w1", "brazier_w2", "brazier_w3"]:
		Game.set_flag("lit_" + id, true)
	Game.set_flag("all_lights", true)
	Game.set_flag("shard_from_wood", true)
	Game.add_item("shard", 1)
	ok(QuestData.objective_for("amber_light").contains("Elder"),
		"objective does not point back to the elder with a shard")
	ok(QuestData.current_target()["area"] == "village",
		"target should be the village once the wood shard is held")

	# --- act 3: hand it in
	Game.remove_item("shard", 1)
	Game.complete_quest("amber_light")
	Game.start_quest("iron_tongue")
	ok(Game.item_count("shard") == 0, "shard was not consumed by the elder")

	# --- act 4: vault puzzle
	Game.set_flag("vault_open", true)
	ok(QuestData.objective_for("iron_tongue").contains("Key"),
		"objective does not ask for the key after the vault opens")
	Game.add_item("key", 1)
	Game.add_item("shard", 1)     # vault shard
	Game.add_item("charm", 1)
	ok(String(QuestData.objective_for("iron_tongue")).contains("Gate"),
		"objective does not ask for the gate once the key is held")

	# the gate door closes act 3 and opens act 4
	var gate := _find_door("hollow", "core")
	ok(not gate.is_empty(), "hollow has no door to the core")
	if not gate.is_empty():
		var fx: Dictionary = gate.get("on_enter", {})
		ok(String(fx.get("done", "")) == "iron_tongue",
			"core gate does not complete iron_tongue")
		ok(String(fx.get("quest", "")) == "corroded_heart",
			"core gate does not start corroded_heart")
		Game.complete_quest(String(fx["done"]))
		Game.start_quest(String(fx["quest"]))
	ok(Game.quest_state("corroded_heart") == "active", "boss quest did not start")
	ok(QuestData.current_target()["area"] == "core", "target should be the core for the boss")

	# --- act 5: boss drops the third shard
	Game.add_item("shard", 1)
	Game.complete_quest("corroded_heart")
	Game.start_quest("what_the_box_remembers")
	ok(Game.item_count("shard") == 2, "expected 2 shards before the vault one is counted")
	ok(QuestData.current_target()["area"] == "village",
		"target should be the well in the village")

	# --- act 6: the well needs three
	Game.add_item("shard", 1)
	ok(Game.item_count("shard") == 3, "player cannot ever hold three shards")
	ok(QuestData.objective_for("what_the_box_remembers").contains("Well"),
		"final objective does not name the well")

	# --- side quest must be completable too
	Game.start_quest("paper_moon")
	ok(QuestData.QUESTS.has("paper_moon"), "paper_moon is not a known quest")
	Game.add_item("moon", 1)
	ok(String(QuestData.objective_for("paper_moon")).contains("Pip"),
		"paper_moon does not point back to Pip")

	# --- ending
	Game.set_flag("ending_seen", true)
	ok(DialogueData.LINES.has("ending"), "ending dialogue is missing")
	var log := QuestData.build_log()
	ok(log.size() >= 6, "quest log does not list every quest (%d)" % log.size())

	# --- every quest objective resolves to non-empty text in every state
	for q in QuestData.QUESTS.keys():
		ok(not String(QuestData.objective_for(String(q))).is_empty(),
			"quest %s has an empty objective" % q)


func _find_door(from_area: String, to_area: String) -> Dictionary:
	for e in (LevelData.LEVELS[from_area]["entities"] as Array):
		var d: Dictionary = e
		if String(d.get("type", "")) == "door" and String(d.get("to", "")) == to_area:
			return d
	return {}
