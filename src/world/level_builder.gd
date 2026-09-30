class_name LevelBuilder
extends RefCounted
## Turns a LevelData entry into a painted map plus a packed collision body.
##
## Tiles are plain Sprite2D children of one node (a few thousand of them is
## nothing for Godot) and collision is merged into horizontal runs so the
## hollow has a handful of shapes instead of one per stone.

const TILE := 16

## Tiles the player cannot walk through. Everything else is floor.
const SOLID := {
	"stone_wall": true, "stone_wall_top": true, "moss_stone": true,
	"wood_wall": true, "roof": true, "window_wall": true, "house_door": true,
	"marble_wall": true, "gold_trim": true, "pillar": true, "rubble": true,
	"grate": true, "stone_floor": false,
	"tree": true, "bush": true, "rock": true, "crate": true, "barrel": true,
	"chest_closed": true, "fence": true, "water": true, "water_deep": true,
	"lantern_off": true, "lantern_on": true, "crystal": true, "sign": true,
	"arch": false, "bridge": false, "lava": false, "hole": false,
	"cobweb": false, "stairs_up": false, "stairs_down": false,
}

## Tiles that hurt or animate.
const ANIMATED := {"water": true}
const HAZARD := {"lava": 1.0}

var size: Vector2i
var grid: Array = []            # Array[Array[String]] - authoritative tiles (props included)
var under: Array = []           # same size, but props do not overwrite the ground
var water_sprites: Array[Sprite2D] = []
var _water_time := 0.0


static func is_solid(name: String) -> bool:
	return bool(SOLID.get(name, false))


# --------------------------------------------------------------------------
static func build(level: Dictionary, tile_root: Node2D, solid_root: Node2D) -> LevelBuilder:
	var b := LevelBuilder.new()
	b.size = level.get("size", Vector2i(32, 24))
	b._paint(level)
	b._spawn_tiles(tile_root, level)
	b._build_collision(solid_root, level)
	return b


static func tile_center(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE + TILE * 0.5, cell.y * TILE + TILE * 0.5)


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y


func tile_at(c: Vector2i) -> String:
	if not in_bounds(c):
		return "void"
	return String(grid[c.y][c.x])


func set_tile(c: Vector2i, name: String) -> void:
	if in_bounds(c):
		grid[c.y][c.x] = name


func world_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(size) * TILE)


# --------------------------------------------------------------------------
# painting
# --------------------------------------------------------------------------
func _paint(level: Dictionary) -> void:
	var base := String(level.get("base", "grass"))
	grid = []
	under = []
	grid.resize(size.y)
	under.resize(size.y)
	for y in size.y:
		var row: Array = []
		row.resize(size.x)
		row.fill(base)
		grid[y] = row
		var row2: Array = []
		row2.resize(size.x)
		row2.fill(base)
		under[y] = row2
	for op in level.get("ops", []):
		_apply_op(op)


func _apply_op(op: Dictionary) -> void:
	var kind := String(op.get("op", ""))
	match kind:
		"rect":
			_fill(int(op["x"]), int(op["y"]), int(op["w"]), int(op["h"]), String(op["tile"]))
		"frame":
			var fx := int(op["x"])
			var fy := int(op["y"])
			var fw := int(op["w"])
			var fh := int(op["h"])
			var t := String(op["tile"])
			for x in range(fx, fx + fw):
				_put(x, fy, t)
				_put(x, fy + fh - 1, t)
			for y in range(fy, fy + fh):
				_put(fx, y, t)
				_put(fx + fw - 1, y, t)
		"hline":
			for x in range(int(op["x1"]), int(op["x2"]) + 1):
				_put(x, int(op["y"]), String(op["tile"]))
		"vline":
			for y in range(int(op["y1"]), int(op["y2"]) + 1):
				_put(int(op["x"]), y, String(op["tile"]))
		"path":
			var x1 := int(op["x1"])
			var y1 := int(op["y1"])
			var x2 := int(op["x2"])
			var y2 := int(op["y2"])
			var t := String(op["tile"])
			for x in range(mini(x1, x2), maxi(x1, x2) + 1):
				_put(x, y1, t)
			for y in range(mini(y1, y2), maxi(y1, y2) + 1):
				_put(x2, y, t)
		"blob":
			var cx := float(op["cx"])
			var cy := float(op["cy"])
			var rx := float(op["rx"])
			var ry := float(op["ry"])
			for y in range(int(cy - ry), int(cy + ry) + 1):
				for x in range(int(cx - rx), int(cx + rx) + 1):
					var nx := (float(x) - cx) / rx
					var ny := (float(y) - cy) / ry
					if nx * nx + ny * ny <= 1.0 + randf() * 0.18:
						_put(x, y, String(op["tile"]))
		"set":
			_put(int(op["x"]), int(op["y"]), String(op["tile"]))
		"house":
			_house(op)
		"scatter":
			_scatter(op)


func _put(x: int, y: int, tile: String) -> void:
	if x < 0 or y < 0 or x >= size.x or y >= size.y:
		return
	grid[y][x] = tile
	under[y][x] = tile


## Scatter places a prop ON the ground instead of replacing it, so the tile
## underneath keeps showing through the transparent parts of the prop art.
func _scatter_put(x: int, y: int, tile: String) -> void:
	if x < 0 or y < 0 or x >= size.x or y >= size.y:
		return
	grid[y][x] = tile


func _fill(x: int, y: int, w: int, h: int, tile: String) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_put(xx, yy, tile)


## A house seen from above: roof everywhere, a wooden facade along the bottom
## row, one door and one window in it.
func _house(op: Dictionary) -> void:
	var x := int(op["x"])
	var y := int(op["y"])
	var w := int(op["w"])
	var h := int(op["h"])
	var door_x := int(op.get("door_x", x + w / 2))
	var win_x := int(op.get("win_x", x + 1))
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_put(xx, yy, "roof")
	# facade strip along the bottom
	for xx in range(x, x + w):
		_put(xx, y + h - 1, "wood_wall")
	_put(x + 1, y + h - 2, "roof")
	_put(x + w - 2, y + h - 2, "roof")
	if win_x >= x and win_x < x + w:
		_put(win_x, y + h - 1, "window_wall")
		if win_x + 1 < x + w and win_x + 1 != door_x:
			_put(win_x + 1, y + h - 1, "window_wall")
	_put(door_x, y + h - 1, "house_door")
	# doorstep
	_put(door_x, y + h, "path")


func _scatter(op: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(op.get("seed", 1))
	var tile := String(op["tile"])
	var count := int(op["n"])
	var region := Vector4i(0, 0, size.x, size.y)
	if op.has("x"):
		region = Vector4i(int(op["x"]), int(op["y"]), int(op.get("w", 1)), int(op.get("h", 1)))
	var only := {}
	for t in String(op.get("only", "")).split(",", false):
		only[t.strip_edges()] = true
	var not_ := {}
	for t in String(op.get("not", "")).split(",", false):
		not_[t.strip_edges()] = true
	var placed := 0
	var guard := count * 40 + 400
	while placed < count and guard > 0:
		guard -= 1
		var x := rng.randi_range(region.x, region.x + region.z - 1)
		var y := rng.randi_range(region.y, region.y + region.w - 1)
		if not in_bounds(Vector2i(x, y)):
			continue
		var cur := String(grid[y][x])
		if not only.is_empty() and not only.has(cur):
			continue
		if not_.has(cur):
			continue
		if String(under[y][x]) == tile:
			continue
		# keep scatter away from tile edges so nothing looks cut in half
		if x <= 1 or y <= 1 or x >= size.x - 2 or y >= size.y - 2:
			continue
		_scatter_put(x, y, tile)
		placed += 1


# --------------------------------------------------------------------------
# rendering
# --------------------------------------------------------------------------
func _spawn_tiles(root: Node2D, level: Dictionary) -> void:
	var atlas: Texture2D = load(TileIndex.SHEET_PATH)
	var water_tex: Texture2D = load(TileIndex.WATER_SHEET)
	var skip := {}
	for skip_name in String(level.get("skip_tiles", "")).split(",", false):
		skip[skip_name.strip_edges()] = true
	var cols := TileIndex.COLUMNS
	for y in size.y:
		for x in size.x:
			var ground := String(under[y][x])
			var top := String(grid[y][x])
			if ground != "void" and not skip.has(ground):
				_add_tile(root, atlas, water_tex, cols, ground, x, y, -10)
			if top != ground and top != "void" and not skip.has(top):
				_add_tile(root, atlas, water_tex, cols, top, x, y, -9)


func _add_tile(root: Node2D, atlas: Texture2D, water_tex: Texture2D, cols: int,
		name: String, x: int, y: int, z: int) -> void:
	var s := Sprite2D.new()
	s.centered = false
	s.texture = atlas
	s.region_enabled = true
	if ANIMATED.has(name) and water_tex != null:
		s.texture = water_tex
		s.region_rect = Rect2(0, 0, TILE, TILE)
		water_sprites.append(s)
	else:
		var idx := TileIndex.id(name)
		s.region_rect = Rect2((idx % cols) * TILE, (idx / cols) * TILE, TILE, TILE)
	s.position = Vector2(x * TILE, y * TILE)
	s.z_index = z
	root.add_child(s)


## Merge solid tiles into horizontal runs, one shape each.
func _build_collision(root: Node2D, level: Dictionary) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	for y in size.y:
		var x := 0
		while x < size.x:
			if not is_solid(String(grid[y][x])):
				x += 1
				continue
			var run := 0
			while x + run < size.x and is_solid(String(grid[y][x + run])):
				run += 1
			var shape := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2(run * TILE, TILE)
			shape.shape = rect
			shape.position = Vector2(x * TILE + run * TILE * 0.5, y * TILE + TILE * 0.5)
			body.add_child(shape)
			x += run


# --------------------------------------------------------------------------
func animate_water(delta: float) -> void:
	_water_time += delta
	var frame := int(_water_time * 4.0) % 4
	for s in water_sprites:
		s.region_rect = Rect2(frame * TILE, 0, TILE, TILE)
