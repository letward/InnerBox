extends SceneTree
## Debug helper: paints a level headless and prints the tiles around a cell.

func _init() -> void:
	for id in ["village", "woods", "hollow", "core"]:
		var level: Dictionary = LevelData.get_level(id)
		print("=== ", id, " size=", level.get("size"), " ops=", (level.get("ops", []) as Array).size(),
			" entities=", (level.get("entities", []) as Array).size())
		var tiles := Node2D.new()
		var solids := Node2D.new()
		get_root().add_child(tiles)
		get_root().add_child(solids)
		var b := LevelBuilder.build(level, tiles, solids)
		var filled := 0
		for y in b.size.y:
			for x in b.size.x:
				if b.grid[y][x] != "void":
					filled += 1
		print("   non-void cells: ", filled, "/", b.size.x * b.size.y,
			"  tile sprites=", tiles.get_child_count())
		var spawns: Dictionary = level.get("spawns", {})
		for sname in spawns.keys():
			var c: Vector2i = spawns[sname]
			var row := ""
			for dy in range(-2, 3):
				var line := "     y=%d: " % (c.y + dy)
				for dx in range(-3, 4):
					line += String(b.tile_at(Vector2i(c.x + dx, c.y + dy))).substr(0, 6) + " "
				print(line)
			print("   spawn '", sname, "' at ", c)
			break
		tiles.queue_free()
		solids.queue_free()
	quit()
