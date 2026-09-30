class_name DialogueBox
extends Control
## Bottom dialogue panel: portrait, name plate, typewriter text and choices.

signal finished()

const PORTRAIT_TEX := "res://assets/portraits.png"
const PORTRAIT_ORDER := ["elder", "tink", "pip", "corrosion", "box"]

const PANEL_BG := Color(0.07, 0.055, 0.12, 0.96)
const PANEL_EDGE := Color(0.55, 0.45, 0.78, 0.9)
const NAME_BG := Color(0.16, 0.12, 0.28, 1.0)
const TEXT_COL := Color(0.94, 0.92, 0.86)
const CHOICE_COL := Color(1.0, 0.85, 0.45)

const CPS := 46.0            # characters per second
const PORTRAIT_SCALE := 2.0

var _root: Control
var _panel: PanelContainer
var _name_label: Label
var _portrait: TextureRect
var _text: RichTextLabel
var _choice_box: VBoxContainer
var _continue_hint: Label

var _node_id := ""
var _node: Dictionary = {}
var _line_index := 0
var _revealed := 0.0
var _full_text := ""
var _typing := false
var _active := false
var _choices: Array = []
var _choice_index := 0
var _blink := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()


func _panel_rect() -> Rect2:
	var vp := get_viewport_rect().size
	return Rect2(12, vp.y - 92, vp.x - 24, 84)


func _build() -> void:
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = PANEL_EDGE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(8)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	_panel.add_child(row)

	var frame := PanelContainer.new()
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color(0.12, 0.09, 0.2, 1.0)
	fsb.border_color = Color(0.45, 0.38, 0.66, 1.0)
	fsb.set_border_width_all(1)
	frame.add_theme_stylebox_override("panel", fsb)
	frame.custom_minimum_size = Vector2(38, 38)
	row.add_child(frame)

	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(38, 38)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(_portrait)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 3)
	row.add_child(col)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 10)
	_name_label.add_theme_color_override("font_color", Color(0.98, 0.86, 0.55))
	col.add_child(_name_label)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.add_theme_font_size_override("normal_font_size", 11)
	_text.add_theme_color_override("default_color", TEXT_COL)
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.custom_minimum_size = Vector2(0, 46)
	col.add_child(_text)

	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 1)
	_choice_box.visible = false
	col.add_child(_choice_box)

	_continue_hint = Label.new()
	_continue_hint.text = "E / SPACE  ▸"
	_continue_hint.add_theme_font_size_override("font_size", 9)
	_continue_hint.add_theme_color_override("font_color", Color(0.62, 0.58, 0.75))
	_continue_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(_continue_hint)


# --------------------------------------------------------------------------
func start(node_id: String) -> void:
	_node_id = node_id
	_node = DialogueData.get_node(node_id)
	_active = true
	_line_index = 0
	_choices = []
	_choice_index = 0
	visible = true
	_panel.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(_panel, "modulate:a", 1.0, 0.12)
	_show_line()


func stop() -> void:
	_active = false
	visible = false
	_choice_box.visible = false


func is_active() -> bool:
	return _active


func _show_line() -> void:
	var lines: Array = _node.get("lines", [])
	if _line_index >= lines.size():
		_show_choices()
		return
	var who := String(_node.get("speaker", ""))
	_name_label.text = who
	_name_label.visible = who != ""
	_set_portrait(String(_node.get("portrait", "box")))
	_full_text = String(lines[_line_index])
	_text.text = ""
	_revealed = 0.0
	_typing = true
	_choice_box.visible = false
	_continue_hint.visible = false
	_line_index += 1


func _set_portrait(id: String) -> void:
	var idx := maxi(0, PORTRAIT_ORDER.find(id))
	var atlas := AtlasTexture.new()
	atlas.atlas = load(PORTRAIT_TEX)
	atlas.region = Rect2(idx * 32, 0, 32, 32)
	atlas.filter_clip = true
	_portrait.texture = atlas
	_portrait.scale = Vector2.ONE


func _process(delta: float) -> void:
	var r := _panel_rect()
	_panel.position = r.position
	_panel.size = r.size
	if not _active:
		return
	_blink += delta
	if _continue_hint != null and _continue_hint.visible:
		_continue_hint.modulate.a = 0.45 + 0.55 * (0.5 + 0.5 * sin(_blink * 7.0))
	if _typing:
		_revealed += CPS * delta
		_text.text = _full_text.substr(0, int(_revealed))
		if _revealed >= float(_full_text.length()):
			_typing = false
			_finish_line()


func _finish_line() -> void:
	_text.text = _full_text
	var lines: Array = _node.get("lines", [])
	if _line_index < lines.size():
		_continue_hint.visible = true
	else:
		_continue_hint.visible = false


func _show_choices() -> void:
	_choices = _node.get("choices", [])
	if _choices.is_empty():
		_choice_box.visible = false
		_finish_node()
		return
	_choice_index = 0
	_choice_box.visible = true
	_rebuild_choices()


func _rebuild_choices() -> void:
	for c in _choice_box.get_children():
		c.queue_free()
	for i in _choices.size():
		var ch: Dictionary = _choices[i]
		var l := Label.new()
		l.text = ("▸ " if i == _choice_index else "   ") + String(ch.get("text", "..."))
		l.add_theme_font_size_override("font_size", 11)
		l.add_theme_color_override("font_color",
			CHOICE_COL if i == _choice_index else Color(0.72, 0.7, 0.8))
		_choice_box.add_child(l)


func _process_input(event: InputEvent) -> void:
	if not _active or not visible:
		return
	var pressed := event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") \
		or event.is_action_pressed("attack")
	var cancel := event.is_action_pressed("ui_cancel")
	if not pressed and not cancel:
		return
	get_viewport().set_input_as_handled()
	if _typing:
		_typing = false
		_revealed = float(_full_text.length())
		_finish_line()
		return
	if _choice_box.visible and not _choices.is_empty():
		if cancel:
			_finish_node()
			return
		var ch: Dictionary = _choices[_choice_index]
		if not _apply_effects(ch.get("effects", {})):
			Sfx.play("block", -6.0)
			return
		Sfx.play("confirm", -4.0)
		var nxt := String(ch.get("next", ""))
		if nxt == "":
			_finish_node()
		else:
			_node_id = nxt
			_node = DialogueData.get_node(nxt)
			_line_index = 0
			_show_line()
		return
	if _line_index < (_node.get("lines", []) as Array).size():
		Sfx.play("menu", -12.0)
		_show_line()


func _move_choice(dir: int) -> void:
	if _choices.is_empty():
		return
	_choice_index = wrapi(_choice_index + dir, 0, _choices.size())
	Sfx.play("menu", -12.0)
	_rebuild_choices()


func _apply_effects(fx: Dictionary) -> bool:
	if fx.is_empty():
		return true
	if fx.has("take"):
		var t: Array = fx["take"]
		if not Game.remove_item(String(t[0]), int(t[1]) if t.size() > 1 else 1):
			return false
	if fx.has("flag"):
		Game.set_flag(String(fx["flag"]), true)
	if fx.has("values"):
		for k in (fx["values"] as Dictionary).keys():
			Game.set_flag(String(k), (fx["values"] as Dictionary)[k])
	if fx.has("quest"):
		Game.start_quest(String(fx["quest"]))
	if fx.has("done"):
		Game.complete_quest(String(fx["done"]))
	if fx.has("give"):
		var g: Array = fx["give"]
		Game.add_item(String(g[0]), int(g[1]) if g.size() > 1 else 1)
	if fx.has("extra"):
		for pair in (fx["extra"] as Array):
			var p: Array = pair
			Game.add_item(String(p[0]), int(p[1]) if p.size() > 1 else 1)
	if fx.has("heal") and int(fx["heal"]) > 0:
		Game.heal_player(int(fx["heal"]))
	return true


func _finish_node() -> void:
	_active = false
	visible = false
	finished.emit()
