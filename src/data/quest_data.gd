class_name QuestData
extends RefCounted
## Quest definitions plus a resolver that turns quest state into the objective
## line the log shows. Keeping this as data (not a node) means the log, the
## NPCs and the tracker all read from one place.

const QUESTS := {
	"shattered_latch": {"title": "The Shattered Latch"},
	"amber_light": {"title": "Amber Light"},
	"iron_tongue": {"title": "Iron Tongue"},
	"corroded_heart": {"title": "The Corroded Heart"},
	"what_the_box_remembers": {"title": "What the Box Remembers"},
	"paper_moon": {"title": "Paper Moon", "side": true},
}


## Returns a human objective for a quest id, given the current game state.
static func objective_for(id: String) -> String:
	match id:
		"shattered_latch":
			return "Speak with Elder Marrow in Hollowmere."
		"amber_light":
			if not Game.has_flag("shard_from_wood"):
				if Game.item_count("ember") < 3:
					return "Collect 3 Embers in Whisperwood. (%d/3)" % mini(3, Game.item_count("ember"))
				return "Light the 3 braziers in Whisperwood."
			return "Bring the Memory Shard back to Elder Marrow."
		"iron_tongue":
			if not Game.has_flag("vault_open"):
				return "Open the vault in the Rust Hollow. Stand on all 3 plates."
			if not Game.has_item("key"):
				return "Take the Rust Key from the vault."
			return "Unlock the Corroded Gate and go through."
		"corroded_heart":
			return "Defeat the Corrosion at the Core."
		"what_the_box_remembers":
			return "Set the three shards into the Memory Well, south of Hollowmere."
		"paper_moon":
			if not Game.has_item("moon"):
				return "Find Pip's Paper Moon somewhere in the Rust Hollow."
			return "Return the Paper Moon to Pip."
	return ""


static func title_for(id: String) -> String:
	return String(QUESTS.get(id, {}).get("title", id))


static func is_side(id: String) -> bool:
	return bool(QUESTS.get(id, {}).get("side", false))


## Where the player should be going right now.
## Returns {"text": String, "area": String, "cell": Vector2i}.
## The first active main quest wins; side quests only show when nothing else does.
static func current_target() -> Dictionary:
	for id in Game.quest_order:
		if Game.quest_state(id) != "active":
			continue
		if is_side(id):
			continue
		var t := _target_for(id)
		if not t.is_empty():
			return t
	for id in Game.quest_order:
		if Game.quest_state(id) == "active" and is_side(id):
			var t := _target_for(id)
			if not t.is_empty():
				return t
	return {}


static func _t(text: String, area: String, cell: Vector2i) -> Dictionary:
	return {"text": text, "area": area, "cell": cell}


static func _target_for(id: String) -> Dictionary:
	match id:
		"shattered_latch":
			return _t("Speak with Elder Marrow", "village", Vector2i(22, 16))
		"amber_light":
			if not Game.has_flag("shard_from_wood"):
				if Game.item_count("ember") < 3:
					return _t("Find Embers in Whisperwood", "woods", Vector2i(14, 12))
				return _t("Light the three braziers", "woods", Vector2i(24, 24))
			return _t("Bring the shard to Elder Marrow", "village", Vector2i(22, 16))
		"iron_tongue":
			if not Game.has_flag("vault_open"):
				return _t("Stand on all three plates", "hollow", Vector2i(37, 19))
			if not Game.has_item("key"):
				return _t("Take the Rust Key", "hollow", Vector2i(38, 35))
			return _t("Unlock the Corroded Gate", "hollow", Vector2i(46, 20))
		"corroded_heart":
			return _t("Face the Corrosion", "core", Vector2i(15, 8))
		"what_the_box_remembers":
			return _t("Set the shards in the Memory Well", "village", Vector2i(24, 31))
		"paper_moon":
			if Game.has_item("moon"):
				return _t("Return the Paper Moon to Pip", "village", Vector2i(12, 22))
			return _t("Search the Rust Hollow for Pip's moon", "hollow", Vector2i(10, 34))
	return {}


## Log entries: every quest that has been accepted and is not finished, plus
## recently finished ones (so the player sees the tick).
static func build_log() -> Array:
	var out: Array = []
	for id in Game.quest_order:
		if not QUESTS.has(id):
			continue
		var state := Game.quest_state(id)
		if state == "":
			continue
		var obj := objective_for(id) if state == "active" else "Complete."
		out.append({"id": id, "title": title_for(id), "objective": obj, "done": state == "done"})
	return out
