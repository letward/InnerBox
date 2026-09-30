extends Node2D
## Title screen: the closed box, drifting motes, and a menu.

const TITLE_FONT_SIZE := 30

enum Item { CONTINUE, NEW, QUIT }

var _items: Array = []
var _sel := 0
var _label_box: VBoxContainer
var _hint: Label
var _motes: Array[Sprite2D] = []
var _t := 0.0


func _ready() -> void:
	Sfx.music("title")
	_build()
	_build_motes()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.055, 0.043, 0.086)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var cl := CanvasLayer.new()
	add_child(cl)
	cl.add_child(bg)

	# star field / motes
	var field := Node2D.new()
	field.name = "Field"
	add_child(field)

	var center := Control.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	cl.add_child(center)

	var box := Control.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -150
	box.offset_right = 150
	box.offset_top = -132
	box.offset_bottom = -40
	center.add_child(box)

	var title := Label.new()
	title.text = "INNERBOX"
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	title.add_theme_color_override("font_color", Color(0.97, 0.92, 0.82))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	title.add_theme_constant_override("outline_size", 8)
	box.add_child(title)

	var sub := Label.new()
	sub.text = "a music box that forgot how to close"
	sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 38
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 9)
	sub.add_theme_color_override("font_color", Color(0.66, 0.6, 0.84))
	sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	sub.add_theme_constant_override("outline_size", 5)
	box.add_child(sub)

	_label_box = VBoxContainer.new()
	_label_box.set_anchors_preset(Control.PRESET_CENTER)
	_label_box.offset_left = -110
	_label_box.offset_right = 110
	_label_box.offset_top = 10
	_label_box.offset_bottom = 120
	_label_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_label_box.add_theme_constant_override("separation", 4)
	center.add_child(_label_box)

	if Game.has_save():
		_items = ["Continue", "New game", "Quit"]
	else:
		_items = ["New game", "Quit"]

	for i in _items.size():
		var l := Label.new()
		l.text = String(_items[i])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 12)
		_label_box.add_child(l)

	_hint = Label.new()
	_hint.text = "W/S or arrows   ·   E / Enter"
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -26
	_hint.offset_bottom = -10
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 8)
	_hint.add_theme_color_override("font_color", Color(0.5, 0.46, 0.62))
	center.add_child(_hint)

	var controls := Label.new()
	controls.text = "WASD move   SPACE swing   SHIFT dash   E talk/open   I satchel   Q quests   ESC pause"
	controls.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	controls.offset_top = -62
	controls.offset_bottom = -46
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_theme_font_size_override("font_size", 7)
	controls.add_theme_color_override("font_color", Color(0.42, 0.39, 0.56))
	center.add_child(controls)

	_repaint()


func _build_motes() -> void:
	var field := get_node_or_null("Field")
	if field == null:
		return
	var tex := load("res://assets/tiles.png")
	for i in 40:
		var s := Sprite2D.new()
		s.texture = tex
		s.region_enabled = true
		var idx := TileIndex.id("core_glow")
		s.region_rect = Rect2((idx % TileIndex.COLUMNS) * 16, (idx / 16) * 16, 16, 16)
		s.position = Vector2(randf() * 512.0, randf() * 288.0)
		s.scale = Vector2.ONE * randf_range(0.1, 0.3)
		s.modulate = Color(0.8, 0.72, 1.0, randf_range(0.15, 0.5))
		field.add_child(s)
		_motes.append(s)


func _process(delta: float) -> void:
	_t += delta
	for i in _motes.size():
		var m := _motes[i]
		m.position.y -= (6.0 + float(i % 5)) * delta
		m.position.x += sin(_t * 0.7 + float(i)) * 4.0 * delta
		if m.position.y < -8.0:
			m.position.y = 296.0
			m.position.x = randf() * 512.0


func _repaint() -> void:
	for i in _label_box.get_child_count():
		var l := _label_box.get_child(i) as Label
		l.add_theme_color_override("font_color",
			Color(1.0, 0.85, 0.45) if i == _sel else Color(0.66, 0.62, 0.78))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		_sel = wrapi(_sel + 1, 0, _items.size())
		Sfx.play("menu", -10.0)
		_repaint()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		_sel = wrapi(_sel - 1, 0, _items.size())
		Sfx.play("menu", -10.0)
		_repaint()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		Sfx.play("confirm", -4.0)
		_activate()


func _activate() -> void:
	var choice := String(_items[_sel])
	if choice == "Quit":
		get_tree().quit()
		return
	if choice == "Continue":
		if Game.load_game():
			get_tree().change_scene_to_file("res://src/main.tscn")
			return
	Game.new_game(true)
	get_tree().change_scene_to_file("res://src/main.tscn")
