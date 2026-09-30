extends Node
## Global game state: health, inventory, quest flags, save/load.
##
## Everything that must survive an area change lives here. The level itself is
## throwaway; this object is not.

signal hearts_changed(value: int, maximum: int)
signal inventory_changed()
signal quest_changed(quest_id: String)
signal objective_completed(text: String)
signal flag_changed(flag: String, value: Variant)

const SAVE_PATH := "user://innerbox_save.cfg"
const SAVE_VERSION := 1

# --- health ---------------------------------------------------------------
var hearts: int = 6
var max_hearts: int = 6

# --- items ----------------------------------------------------------------
var inventory: Dictionary = {}
var flags: Dictionary = {}
var quests: Dictionary = {}          # quest_id -> "active" | "done"
var quest_order: Array[String] = []

var started: bool = false
var current_area: String = "village"
var current_spawn: String = "start"


func _ready() -> void:
	add_to_group("game")
	new_game(false)


# --------------------------------------------------------------------------
# new game / save / load
# --------------------------------------------------------------------------
func new_game(apply: bool = true) -> void:
	hearts = max_hearts
	inventory = {"salve": 2}
	flags = {}
	quests = {"shattered_latch": "active"}
	quest_order = ["shattered_latch"]
	started = false
	if apply:
		hearts_changed.emit(hearts, max_hearts)
		inventory_changed.emit()
		for q in quest_order:
			quest_changed.emit(q)


func has_save() -> bool:
	var cfg := ConfigFile.new()
	return cfg.load(SAVE_PATH) == OK


func save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("s", "version", SAVE_VERSION)
	cfg.set_value("s", "hearts", hearts)
	cfg.set_value("s", "max_hearts", max_hearts)
	cfg.set_value("s", "inventory", inventory)
	cfg.set_value("s", "flags", flags)
	cfg.set_value("s", "quests", quests)
	cfg.set_value("s", "quest_order", quest_order)
	cfg.set_value("s", "area", current_area)
	cfg.set_value("s", "spawn", current_spawn)
	cfg.set_value("s", "started", started)
	cfg.save(SAVE_PATH)


func load_game() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return false
	hearts = int(cfg.get_value("s", "hearts", 6))
	max_hearts = int(cfg.get_value("s", "max_hearts", 6))
	inventory = cfg.get_value("s", "inventory", {})
	flags = cfg.get_value("s", "flags", {})
	quests = cfg.get_value("s", "quests", {})
	quest_order = []
	for q in cfg.get_value("s", "quest_order", []):
		quest_order.append(String(q))
	current_area = cfg.get_value("s", "area", "village")
	current_spawn = cfg.get_value("s", "spawn", "start")
	started = bool(cfg.get_value("s", "started", false))
	hearts_changed.emit(hearts, max_hearts)
	inventory_changed.emit()
	for q in quest_order:
		quest_changed.emit(q)
	return true


func erase_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


# --------------------------------------------------------------------------
# health
# --------------------------------------------------------------------------
func damage_player(amount: int) -> void:
	if hearts <= 0:
		return
	hearts = maxi(0, hearts - amount)
	hearts_changed.emit(hearts, max_hearts)
	if hearts == 1:
		Sfx.play("warn")


func heal_player(amount: int) -> int:
	var before := hearts
	hearts = mini(max_hearts, hearts + amount)
	if hearts != before:
		hearts_changed.emit(hearts, max_hearts)
	return hearts - before


# --------------------------------------------------------------------------
# inventory
# --------------------------------------------------------------------------
func has_item(id: String, count: int = 1) -> bool:
	return int(inventory.get(id, 0)) >= count


func add_item(id: String, count: int = 1) -> void:
	inventory[id] = int(inventory.get(id, 0)) + count
	inventory_changed.emit()


func remove_item(id: String, count: int = 1) -> bool:
	if not has_item(id, count):
		return false
	var left := int(inventory[id]) - count
	if left <= 0:
		inventory.erase(id)
	else:
		inventory[id] = left
	inventory_changed.emit()
	return true


func item_count(id: String) -> int:
	return int(inventory.get(id, 0))


# --------------------------------------------------------------------------
# flags / quests
# --------------------------------------------------------------------------
func get_flag(name: String, fallback: Variant = false) -> Variant:
	return flags.get(name, fallback)


func set_flag(name: String, value: Variant = true) -> void:
	flags[name] = value
	flag_changed.emit(name, value)


func has_flag(name: String) -> bool:
	return bool(flags.get(name, false))


func start_quest(id: String) -> void:
	if quests.has(id):
		return
	quests[id] = "active"
	quest_order.append(id)
	quest_changed.emit(id)
	objective_completed.emit("New objective")


func complete_quest(id: String) -> void:
	if not quests.has(id):
		return
	quests[id] = "done"
	quest_changed.emit(id)


func quest_state(id: String) -> String:
	return String(quests.get(id, ""))


func is_quest_active(id: String) -> bool:
	return quests.get(id, "") == "active"


func report(text: String) -> void:
	objective_completed.emit(text)
