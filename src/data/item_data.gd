class_name ItemData
extends RefCounted
## Static item definitions. `icon` is an index into assets/items.png (16px cells).

const ICON_SALVE := 0
const ICON_EMBER := 1
const ICON_SHARD := 2
const ICON_KEY := 3
const ICON_GEAR := 4
const ICON_MOON := 5
const ICON_COIN := 6
const ICON_COG := 7
const ICON_CHARM := 8
const ICON_ECHO := 9
const ICON_TICK := 10
const ICON_MOTH := 11
const ICON_LATCH := 12

## The icon sheet is laid out 5 cells per row (see tools/gen_assets.py).
const SHEET_COLS := 5
const SHEET_ROWS := 4
const HEART_FULL := 15
const HEART_HALF := 16
const HEART_EMPTY := 17


## Pixel rect of an item icon inside assets/items.png.
static func region(icon: int) -> Rect2:
	return Rect2((icon % SHEET_COLS) * 16, (icon / SHEET_COLS) * 16, 16, 16)


## Pixel rect of a heart glyph: 0 = full, 1 = half, 2 = empty.
static func heart_region(index: int) -> Rect2:
	var idx := HEART_FULL + index
	return Rect2((idx % SHEET_COLS) * 16, (idx / SHEET_COLS) * 16, 9, 9)

const ITEMS := {
	"salve": {
		"name": "Rust Salve",
		"icon": ICON_SALVE,
		"usable": true,
		"desc": "Tastes like pennies and rust. Restores 3 hearts.",
	},
	"ember": {
		"name": "Ember",
		"icon": ICON_EMBER,
		"usable": false,
		"desc": "A coal that refuses to go out. Light a brazier with it.",
	},
	"shard": {
		"name": "Memory Shard",
		"icon": ICON_SHARD,
		"usable": false,
		"desc": "A piece of something that happened. It hums when you hold it.",
	},
	"key": {
		"name": "Rust Key",
		"icon": ICON_KEY,
		"usable": false,
		"desc": "A key that has been rusting since before the box was closed.",
	},
	"gear": {
		"name": "Rusted Gear",
		"icon": ICON_GEAR,
		"usable": false,
		"desc": "Tink pays two salves for one. She says it is for a clock.",
	},
	"moon": {
		"name": "Paper Moon",
		"icon": ICON_MOON,
		"usable": false,
		"desc": "Folded from the page of a book nobody in the box has read.",
	},
	"coin": {
		"name": "Brass Coin",
		"icon": ICON_COIN,
		"usable": false,
		"desc": "Old money. The box has plenty, if you can reach it.",
	},
	"cog": {
		"name": "Brass Cog",
		"icon": ICON_COG,
		"usable": false,
		"desc": "Still turns. Tink trades three of them for a salve.",
	},
	"charm": {
		"name": "Paper Charm",
		"icon": ICON_CHARM,
		"usable": true,
		"desc": "Folded by Pip's hands. Wear it: your heart has one room more in it.",
	},
	"echo_village": {
		"name": "Echo: the Winding",
		"icon": ICON_ECHO,
		"lore": true,
		"usable": false,
		"desc": "Someone turned this handle forty thousand times.",
	},
	"echo_elder": {
		"name": "Echo: the Keeper",
		"icon": ICON_ECHO,
		"lore": true,
		"usable": false,
		"desc": "Marrow remembers standing at the same window for a hundred years.",
	},
	"echo_wood": {
		"name": "Echo: the Lanterns",
		"icon": ICON_ECHO,
		"lore": true,
		"usable": false,
		"desc": "The wood remembers being lit. That is the whole of it.",
	},
	"echo_core": {
		"name": "Echo: the Latch",
		"icon": ICON_ECHO,
		"lore": true,
		"usable": false,
		"desc": "It was never locked from the outside.",
	},
	"tally_tick": {
		"name": "Note: Rust Tick",
		"icon": ICON_TICK,
		"lore": true,
		"usable": false,
		"desc": "It used to keep time for the box. Two beats, then a pause.",
	},
	"tally_moth": {
		"name": "Note: Gloom Moth",
		"icon": ICON_MOTH,
		"lore": true,
		"usable": false,
		"desc": "It hunts what is still warm. That includes you.",
	},
}


static func get_item(id: String) -> Dictionary:
	return ITEMS.get(id, {"name": id, "icon": ICON_COIN, "usable": false, "desc": ""})


static func item_name(id: String) -> String:
	return String(get_item(id).get("name", id))


static func item_desc(id: String) -> String:
	return String(get_item(id).get("desc", ""))


static func item_icon(id: String) -> int:
	return int(get_item(id).get("icon", ICON_COIN))


static func is_usable(id: String) -> bool:
	return bool(get_item(id).get("usable", false))


static func is_lore(id: String) -> bool:
	return bool(get_item(id).get("lore", false))


## Everything that can be picked up, in a stable display order.
static func collectible_ids() -> Array:
	var out: Array = []
	for id in ITEMS.keys():
		if not is_lore(id):
			out.append(id)
	out.sort()
	return out


## Lore the player has actually found, for the Codex panel.
static func found_lore() -> Array:
	var out: Array = []
	for id in ITEMS.keys():
		if is_lore(id) and int(Game.inventory.get(id, 0)) > 0:
			out.append(id)
	out.sort()
	return out
