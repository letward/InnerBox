class_name LevelData
extends RefCounted
## All five areas of InnerBox, described as data.
##
## Maps are not hand-drawn ASCII: each level starts from a base tile and then a
## list of ops paints it (rects, lines, blobs, houses, scatter). That keeps the
## layouts editable and makes it impossible to author a ragged map.
##
## Op keys:
##   rect    x y w h tile
##   frame   x y w h tile            (border only, used before a rect to wall it in)
##   hline   x1 x2 y tile
##   vline   x y1 y2 tile
##   path    x1 y1 x2 y2 tile        (L: horizontal first, then vertical)
##   blob    cx cy rx ry tile
##   set     x y tile
##   house   x y w h [door_x] [win_x]
##   room    x y w h floor [wall]
##   scatter tile n seed [x y w h] [only=a,b] [not=a,b]

const LEVELS := {

# ==========================================================================
"village": {
	"name": "HOLLOWMERE",
	"subtitle": "the village inside the box",
	"music": "village",
	"size": Vector2i(48, 36),
	"base": "grass",
	"clear": "deep",
	"ops": [
		# ground variation
		{"op": "blob", "cx": 12, "cy": 8, "rx": 7, "ry": 5, "tile": "grass_flowers"},
		{"op": "blob", "cx": 40, "cy": 10, "rx": 6, "ry": 4, "tile": "grass_flowers"},
		{"op": "blob", "cx": 34, "cy": 33, "rx": 8, "ry": 3, "tile": "grass_tuft"},

		# the pond and its stream
		{"op": "blob", "cx": 41, "cy": 31, "rx": 6, "ry": 4, "tile": "sand"},
		{"op": "blob", "cx": 41, "cy": 31, "rx": 5, "ry": 3, "tile": "water"},
		{"op": "hline", "x1": 30, "x2": 41, "y": 28, "tile": "water"},
		{"op": "hline", "x1": 30, "x2": 41, "y": 28, "tile": "sand"},
		{"op": "hline", "x1": 31, "x2": 41, "y": 28, "tile": "water"},
		{"op": "vline", "x": 33, "y1": 28, "y2": 29, "tile": "sand"},
		{"op": "set", "x": 33, "y": 28, "tile": "bridge"},
		{"op": "set", "x": 33, "y": 29, "tile": "bridge"},

		# village plaza and crossroads
		{"op": "rect", "x": 16, "y": 12, "w": 16, "h": 11, "tile": "stone_floor"},
		{"op": "path", "x1": 23, "y1": 1, "x2": 23, "y2": 34, "tile": "path"},
		{"op": "path", "x1": 1, "y1": 21, "x2": 46, "y2": 21, "tile": "path"},
		{"op": "rect", "x": 19, "y": 27, "w": 9, "h": 6, "tile": "path"},

		# houses
		{"op": "house", "x": 5, "y": 6, "w": 9, "h": 7, "door_x": 9, "win_x": 6},
		{"op": "house", "x": 33, "y": 5, "w": 10, "h": 7, "door_x": 38, "win_x": 35},
		{"op": "house", "x": 4, "y": 26, "w": 9, "h": 7, "door_x": 8, "win_x": 11},
		{"op": "house", "x": 14, "y": 2, "w": 8, "h": 6, "door_x": 17, "win_x": 19},
		{"op": "house", "x": 38, "y": 15, "w": 8, "h": 6, "door_x": 41, "win_x": 43},

		# garden fences
		{"op": "frame", "x": 27, "y": 27, "w": 10, "h": 8, "tile": "fence"},
		{"op": "rect", "x": 28, "y": 28, "w": 8, "h": 6, "tile": "grass_tuft"},
		{"op": "set", "x": 30, "y": 30, "tile": "flower_red"},
		{"op": "set", "x": 32, "y": 31, "tile": "flower_red"},
		{"op": "set", "x": 34, "y": 30, "tile": "mushroom"},
		{"op": "set", "x": 30, "y": 32, "tile": "mushroom"},

		# scatter
		{"op": "scatter", "tile": "tree", "n": 46, "seed": 11,
		 "only": "grass,grass_flowers,grass_tuft"},
		{"op": "scatter", "tile": "bush", "n": 26, "seed": 12,
		 "only": "grass,grass_flowers,grass_tuft"},
		{"op": "scatter", "tile": "rock", "n": 8, "seed": 13,
		 "only": "grass,grass_flowers"},
		{"op": "scatter", "tile": "flower_red", "n": 22, "seed": 14,
		 "only": "grass,grass_flowers"},
		{"op": "scatter", "tile": "lantern_off", "n": 7, "seed": 15,
		 "only": "path,stone_floor"},
	],
	"spawns": {
		"start": Vector2i(23, 20),
		"from_woods": Vector2i(23, 4),
		"from_hollow": Vector2i(45, 20),
	},
	"entities": [
		{"type": "npc", "id": "elder", "tile": [22, 15], "face": "down"},
		{"type": "npc", "id": "tink", "tile": [28, 19], "face": "left"},
		{"type": "npc", "id": "pip", "tile": [12, 22], "face": "right"},
		{"type": "sign", "tile": [26, 16], "node": "sign_village"},
		{"type": "well", "tile": [24, 31]},
		{"type": "spark", "tile": [24, 32]},
		{"type": "spark", "tile": [22, 32]},
		{"type": "spark", "tile": [26, 32]},
		{"type": "door", "tile": [23, 2], "to": "woods", "spawn": "from_village",
		 "tile_name": "arch", "label": "Whisperwood"},
		{"type": "door", "tile": [46, 20], "to": "hollow", "spawn": "from_village",
		 "tile_name": "arch", "label": "The Rust Hollow"},
		{"type": "chest", "tile": [31, 29], "item": "salve", "qty": 2, "id": "chest_village_1"},
		{"type": "chest", "tile": [20, 29], "item": "echo_village", "qty": 1, "id": "chest_echo_village"},
		{"type": "chest", "tile": [26, 29], "item": "cog", "qty": 2, "id": "chest_cogs_1"},
	],
},

# ==========================================================================
"woods": {
	"name": "WHISPERWOOD",
	"subtitle": "where the lanterns were",
	"music": "wilds",
	"size": Vector2i(56, 44),
	"base": "grass_dark",
	"clear": "black",
	"ops": [
		{"op": "blob", "cx": 16, "cy": 24, "rx": 13, "ry": 10, "tile": "grass"},
		{"op": "blob", "cx": 46, "cy": 36, "rx": 8, "ry": 6, "tile": "grass"},
		{"op": "blob", "cx": 8, "cy": 38, "rx": 7, "ry": 5, "tile": "grass"},

		# the stream running south to north on the east side
		{"op": "vline", "x": 41, "y1": 1, "y2": 42, "tile": "sand"},
		{"op": "vline", "x": 41, "y1": 1, "y2": 42, "tile": "water"},
		{"op": "set", "x": 40, "y": 22, "tile": "bridge"},
		{"op": "set", "x": 41, "y": 22, "tile": "bridge"},
		{"op": "set", "x": 42, "y": 22, "tile": "bridge"},

		# little clearings so the loose embers are never buried under a tree
		{"op": "blob", "cx": 14, "cy": 12, "rx": 2, "ry": 2, "tile": "path"},
		{"op": "blob", "cx": 46, "cy": 11, "rx": 2, "ry": 2, "tile": "path"},
		{"op": "blob", "cx": 46, "cy": 38, "rx": 2, "ry": 2, "tile": "path"},

		# the path in from the village, around the clearing, out east
		{"op": "vline", "x": 8, "y1": 1, "y2": 9, "tile": "path"},
		{"op": "hline", "x1": 8, "x2": 24, "y": 9, "tile": "path"},
		{"op": "vline", "x": 24, "y1": 9, "y2": 22, "tile": "path"},
		{"op": "hline", "x1": 24, "x2": 42, "y": 22, "tile": "path"},
		{"op": "vline", "x": 24, "y1": 22, "y2": 34, "tile": "path"},
		{"op": "hline", "x1": 24, "x2": 41, "y": 34, "tile": "path"},

		# the shrine clearing
		{"op": "rect", "x": 17, "y": 18, "w": 15, "h": 14, "tile": "grass_tuft"},
		{"op": "frame", "x": 17, "y": 18, "w": 15, "h": 14, "tile": "stone_floor"},
		{"op": "frame", "x": 18, "y": 19, "w": 13, "h": 12, "tile": "grass_tuft"},

		{"op": "scatter", "tile": "tree", "n": 150, "seed": 21,
		 "only": "grass_dark,grass", "not": "water,sand,path,bridge"},
		{"op": "scatter", "tile": "bush", "n": 60, "seed": 22,
		 "only": "grass_dark,grass", "not": "water,sand,path,bridge"},
		{"op": "scatter", "tile": "rock", "n": 18, "seed": 23, "only": "grass_dark"},
		{"op": "scatter", "tile": "mushroom", "n": 22, "seed": 24,
		 "only": "grass_dark", "not": "water,sand,path"},
		{"op": "scatter", "tile": "grass_tuft", "n": 70, "seed": 25,
		 "only": "grass_dark", "not": "water,sand,path"},
	],
	"spawns": {
		"from_village": Vector2i(8, 4),
		"from_hollow": Vector2i(52, 22),
	},
	"entities": [
		{"type": "door", "tile": [8, 2], "to": "village", "spawn": "from_woods",
		 "tile_name": "arch", "label": "Hollowmere"},
		{"type": "door", "tile": [54, 22], "to": "hollow", "spawn": "from_woods",
		 "tile_name": "arch", "label": "The Rust Hollow"},

		{"type": "brazier", "tile": [20, 21], "id": "brazier_w1"},
		{"type": "brazier", "tile": [29, 21], "id": "brazier_w2"},
		{"type": "brazier", "tile": [24, 29], "id": "brazier_w3"},
		{"type": "altar", "tile": [24, 24]},

		{"type": "ember", "tile": [14, 12], "id": "ember_w1"},
		{"type": "ember", "tile": [47, 11], "id": "ember_w2"},
		{"type": "ember", "tile": [46, 38], "id": "ember_w3"},

		{"type": "chest", "tile": [33, 34], "item": "salve", "qty": 2, "id": "chest_woods_1"},
		{"type": "chest", "tile": [19, 24], "item": "echo_wood", "qty": 1, "id": "chest_echo_wood"},
		{"type": "chest", "tile": [7, 32], "item": "salve", "qty": 1, "id": "chest_woods_2"},
		{"type": "sign", "tile": [26, 10], "node": "sign_woods"},
		{"type": "sign", "tile": [38, 20], "node": "sign_woods2"},

		{"type": "enemy", "kind": "tick", "tile": [18, 11]},
		{"type": "enemy", "kind": "tick", "tile": [31, 14]},
		{"type": "enemy", "kind": "tick", "tile": [12, 27]},
		{"type": "enemy", "kind": "tick", "tile": [34, 26]},
		{"type": "enemy", "kind": "tick", "tile": [27, 37]},
		{"type": "enemy", "kind": "tick", "tile": [45, 29]},
		{"type": "enemy", "kind": "moth", "tile": [21, 15]},
		{"type": "enemy", "kind": "moth", "tile": [28, 25]},
		{"type": "enemy", "kind": "moth", "tile": [37, 30]},
		{"type": "enemy", "kind": "moth", "tile": [14, 36]},
	],
},

# ==========================================================================
"hollow": {
	"name": "THE RUST HOLLOW",
	"subtitle": "the room the box forgot to lock",
	"music": "wilds",
	"size": Vector2i(48, 40),
	"base": "void",
	"clear": "black",
	"ops": [
		# entry hall
		{"op": "frame", "x": 2, "y": 15, "w": 17, "h": 12, "tile": "stone_wall"},
		{"op": "rect", "x": 3, "y": 16, "w": 15, "h": 10, "tile": "stone_floor"},
		{"op": "rect", "x": 3, "y": 19, "w": 15, "h": 4, "tile": "moss_stone"},
		{"op": "set", "x": 6, "y": 16, "tile": "rubble"},
		{"op": "set", "x": 12, "y": 24, "tile": "rubble"},
		{"op": "set", "x": 9, "y": 22, "tile": "mushroom"},

		# corridor east
		{"op": "hline", "x1": 19, "x2": 28, "y": 20, "tile": "stone_floor"},
		{"op": "vline", "x": 20, "y1": 20, "y2": 20, "tile": "stone_floor"},

		# the vault chamber (south)
		{"op": "vline", "x": 8, "y1": 25, "y2": 28, "tile": "stone_floor"},
		{"op": "frame", "x": 2, "y": 28, "w": 15, "h": 10, "tile": "stone_wall"},
		{"op": "rect", "x": 3, "y": 29, "w": 13, "h": 8, "tile": "stone_floor"},
		{"op": "rect", "x": 4, "y": 30, "w": 11, "h": 6, "tile": "brick_floor"},

		# the plate room
		{"op": "frame", "x": 28, "y": 8, "w": 19, "h": 22, "tile": "stone_wall"},
		{"op": "rect", "x": 29, "y": 9, "w": 17, "h": 20, "tile": "stone_floor"},
		{"op": "hline", "x1": 29, "x2": 45, "y": 19, "tile": "brick_floor"},
		{"op": "vline", "x": 37, "y1": 9, "y2": 28, "tile": "brick_floor"},
		{"op": "set", "x": 33, "y": 12, "tile": "rubble"},
		{"op": "set", "x": 43, "y": 26, "tile": "rubble"},
		{"op": "set", "x": 30, "y": 27, "tile": "cobweb"},
		{"op": "set", "x": 45, "y": 10, "tile": "cobweb"},

		# the vault behind the plate room
		{"op": "hline", "x1": 34, "x2": 41, "y": 30, "tile": "stone_floor"},
		{"op": "frame", "x": 32, "y": 32, "w": 12, "h": 7, "tile": "stone_wall"},
		{"op": "rect", "x": 33, "y": 33, "w": 10, "h": 5, "tile": "brick_floor"},
		{"op": "set", "x": 38, "y": 34, "tile": "chest_closed"},

		# a shaft of daylight from the village gate
		{"op": "set", "x": 2, "y": 20, "tile": "stone_wall_top"},
		{"op": "set", "x": 3, "y": 20, "tile": "arch"},

		{"op": "scatter", "tile": "rubble", "n": 26, "seed": 31, "only": "stone_floor,brick_floor"},
		{"op": "scatter", "tile": "cobweb", "n": 14, "seed": 32, "only": "stone_floor"},
		{"op": "scatter", "tile": "lantern_off", "n": 9, "seed": 33, "only": "stone_floor,brick_floor"},
	],
	"spawns": {
		"from_village": Vector2i(5, 20),
		"from_woods": Vector2i(5, 20),
		"from_core": Vector2i(45, 19),
	},
	"entities": [
		{"type": "door", "tile": [1, 20], "to": "village", "spawn": "from_hollow",
		 "tile_name": "arch", "label": "Hollowmere", "no_tile": true},
		{"type": "door", "tile": [46, 20], "to": "woods", "spawn": "from_hollow",
		 "tile_name": "arch", "label": "Whisperwood"},

		{"type": "plate", "tile": [32, 12], "id": "plate_1"},
		{"type": "plate", "tile": [42, 12], "id": "plate_2"},
		{"type": "plate", "tile": [37, 26], "id": "plate_3"},
		{"type": "crate", "tile": [30, 25], "id": "crate_1"},
		{"type": "crate", "tile": [44, 25], "id": "crate_2"},
		{"type": "crate", "tile": [30, 11], "id": "crate_3"},

		{"type": "gate", "tile": [38, 31], "id": "vault_gate", "solid_until": "vault_open"},
		{"type": "chest", "tile": [37, 35], "item": "key", "qty": 1, "id": "chest_key",
		 "locked_flag": "vault_open", "locked_text": "The vault is sealed. Three plates, three crates."},
		{"type": "chest", "tile": [40, 35], "item": "shard", "qty": 1, "id": "chest_shard_hollow",
		 "locked_flag": "vault_open", "locked_text": "The vault is sealed. Three plates, three crates."},
		{"type": "chest", "tile": [34, 36], "item": "charm", "qty": 1, "id": "chest_charm",
		 "locked_flag": "vault_open", "locked_text": "The vault is sealed. Three plates, three crates."},
		{"type": "chest", "tile": [10, 34], "item": "moon", "qty": 1, "id": "chest_moon"},
		{"type": "chest", "tile": [6, 32], "item": "echo_elder", "qty": 1, "id": "chest_echo_hollow"},

		{"type": "door", "tile": [47, 19], "to": "core", "spawn": "from_hollow",
		 "tile_name": "arch", "label": "The Core", "needs_item": "key",
		 "locked_text": "The Corroded Gate. Something down there still has the key.",
		 "on_enter": {"done": "iron_tongue", "quest": "corroded_heart"}},

		{"type": "sign", "tile": [6, 19], "node": "sign_hollow"},
		{"type": "spark", "tile": [12, 18]},
		{"type": "spark", "tile": [31, 16]},
		{"type": "spark", "tile": [44, 16]},
		{"type": "spark", "tile": [36, 21]},
		{"type": "spark", "tile": [5, 32]},
		{"type": "spark", "tile": [39, 35]},

		{"type": "enemy", "kind": "tick", "tile": [8, 20]},
		{"type": "enemy", "kind": "tick", "tile": [14, 18]},
		{"type": "enemy", "kind": "tick", "tile": [24, 20]},
		{"type": "enemy", "kind": "tick", "tile": [34, 22]},
		{"type": "enemy", "kind": "tick", "tile": [41, 22]},
		{"type": "enemy", "kind": "tick", "tile": [36, 34]},
		{"type": "enemy", "kind": "moth", "tile": [10, 21]},
		{"type": "enemy", "kind": "moth", "tile": [31, 14]},
		{"type": "enemy", "kind": "moth", "tile": [43, 22]},
	],
},

# ==========================================================================
"core": {
	"name": "THE CORE",
	"subtitle": "the middle of the song",
	"music": "boss",
	"size": Vector2i(30, 22),
	"base": "void",
	"clear": "black",
	"ops": [
		{"op": "frame", "x": 1, "y": 1, "w": 28, "h": 20, "tile": "marble_wall"},
		{"op": "rect", "x": 2, "y": 2, "w": 26, "h": 18, "tile": "marble_floor"},
		{"op": "frame", "x": 4, "y": 4, "w": 22, "h": 14, "tile": "gold_trim"},
		{"op": "rect", "x": 5, "y": 5, "w": 20, "h": 12, "tile": "marble_floor"},
		{"op": "blob", "cx": 15, "cy": 11, "rx": 6, "ry": 4, "tile": "gold_trim"},
		{"op": "blob", "cx": 15, "cy": 11, "rx": 4, "ry": 3, "tile": "marble_floor"},
		{"op": "set", "x": 6, "y": 6, "tile": "pillar"},
		{"op": "set", "x": 23, "y": 6, "tile": "pillar"},
		{"op": "set", "x": 6, "y": 15, "tile": "pillar"},
		{"op": "set", "x": 23, "y": 15, "tile": "pillar"},
		{"op": "set", "x": 15, "y": 11, "tile": "core_glow"},
		{"op": "set", "x": 2, "y": 10, "tile": "arch"},
		{"op": "rect", "x": 3, "y": 10, "w": 2, "h": 1, "tile": "marble_floor"},
	],
	"spawns": {
		"from_hollow": Vector2i(5, 10),
	},
	"entities": [
		{"type": "boss", "tile": [15, 7]},
		{"type": "sign", "tile": [8, 18], "node": "sign_core"},
		{"type": "chest", "tile": [24, 16], "item": "salve", "qty": 3, "id": "chest_core_1"},
		{"type": "spark", "tile": [10, 8]},
		{"type": "spark", "tile": [20, 8]},
		{"type": "spark", "tile": [10, 14]},
		{"type": "spark", "tile": [20, 14]},
	],
},

}


static func has_level(id: String) -> bool:
	return LEVELS.has(id)


static func get_level(id: String) -> Dictionary:
	return LEVELS.get(id, LEVELS["village"])
