class_name Hud
extends Control
## Hearts, key-item strip, interaction prompt, toasts, boss bar, area card.
##
## Every floating overlay is positioned explicitly from the viewport rect in
## _process instead of relying on anchor presets - one layout source of truth,
## nothing to fight.

const ITEMS_TEX := "res://assets/items.png"

const GOLD := Color(0.97, 0.82, 0.45)
const HEART_SIZE := 11

var _heart_row: HBoxContainer
var _item_row: HBoxContainer
var _prompt: Label
var _toast: Label
var _boss_box: Control
var _boss_fill: ColorRect
var _area_card: Control
var _area_box: VBoxContainer

var _toast_t := 0.0
var _area_t := 0.0
var _blink := 0.0
var _boss_ratio := 1.0

# objective tracker
var _goal_label: Label
var _arrow: Polygon2D
var _arrow_dir := Vector2.ZERO
var _arrow_pulse := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _build() -> void:
	_heart_row = HBoxContainer.new()
	_heart_row.add_theme_constant_override("separation", 1)
	_heart_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_heart_row)

	_item_row = HBoxContainer.new()
	_item_row.add_theme_constant_override("separation", 3)
	_item_row.alignment = BoxContainer.ALIGNMENT_END
	_item_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_item_row)

	_prompt = _make_label(10, Color(1.0, 0.88, 0.55))
	_toast = _make_label(10, Color(0.74, 0.95, 0.79))
	add_child(_prompt)
	add_child(_toast)

	# ---- boss bar ------------------------------------------------------
	_boss_box = Control.new()
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_box.visible = false
	add_child(_boss_box)

	var name_l := _make_label(9, Color(1.0, 0.55, 0.4))
	name_l.text = "THE CORROSION"
	_boss_box.add_child(name_l)

	var frame := ColorRect.new()
	frame.color = Color(0.1, 0.06, 0.08, 0.92)
	frame.position = Vector2(0, 13)
	frame.size = Vector2(100, 5)
	frame.name = "Frame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_box.add_child(frame)

	_boss_fill = ColorRect.new()
	_boss_fill.color = Color(0.86, 0.3, 0.2)
	_boss_fill.position = Vector2(0, 13)
	_boss_fill.size = Vector2(100, 5)
	_boss_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_box.add_child(_boss_fill)

	# ---- area card -----------------------------------------------------
	_area_card = Control.new()
	_area_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_area_card)
	_area_box = VBoxContainer.new()
	_area_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_area_box.add_theme_constant_override("separation", 1)
	_area_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area_card.add_child(_area_box)

	# ---- objective tracker ---------------------------------------------
	_goal_label = _make_label(8, Color(0.86, 0.82, 0.96))
	_goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_goal_label.text = ""
	add_child(_goal_label)

	_arrow = Polygon2D.new()
	_arrow.polygon = PackedVector2Array([
		Vector2(6, 0), Vector2(-4, -5), Vector2(-4, 5)])
	_arrow.color = Color(0.97, 0.85, 0.5, 0.9)
	_arrow.visible = false
	add_child(_arrow)

	Game.hearts_changed.connect(_on_hearts)
	Game.inventory_changed.connect(_refresh_items)
	_on_hearts(Game.hearts, Game.max_hearts)
	_refresh_items()


func _make_label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size = Vector2(400, 14)
	l.position = Vector2(-200, 0)
	return l


# --------------------------------------------------------------------------
func _on_hearts(current: int, maximum: int) -> void:
	for c in _heart_row.get_children():
		_heart_row.remove_child(c)
		c.queue_free()
	for i in maximum:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(HEART_SIZE, HEART_SIZE)
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var filled := current - i * 2
		icon.texture = _tex(ItemData.heart_region(0 if filled >= 2 else (1 if filled == 1 else 2)))
		icon.modulate = Color(1, 1, 1, 1) if filled >= 1 else Color(0.75, 0.75, 0.8, 0.7)
		_heart_row.add_child(icon)


func _tex(r: Rect2) -> AtlasTexture:
	var t := AtlasTexture.new()
	t.atlas = load(ITEMS_TEX)
	t.region = r
	t.filter_clip = true
	return t


func _icon(icon_id: int) -> TextureRect:
	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(16, 16)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.texture = _tex(ItemData.region(icon_id))
	return tr


func _refresh_items() -> void:
	for c in _item_row.get_children():
		_item_row.remove_child(c)
		c.queue_free()
	for id in ["shard", "key", "moon", "ember"]:
		var n := Game.item_count(id)
		if n <= 0:
			continue
		_item_row.add_child(_icon(ItemData.item_icon(id)))
		if n > 1:
			var l := _make_label(9, GOLD)
			l.text = "x%d" % n
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			l.size = Vector2(30, 14)
			l.position = Vector2.ZERO
			_item_row.add_child(l)


# --------------------------------------------------------------------------
func set_prompt(text: String) -> void:
	_prompt.text = ("[E] " + text) if text != "" else ""


## Shows the current objective line. `dir` is the world-space direction to the
## goal, or Vector2.ZERO when the goal is in another area (or already reached).
func set_objective(text: String, dir: Vector2 = Vector2.ZERO) -> void:
	_goal_label.text = ("» " + text) if text != "" else ""
	_arrow_dir = dir if dir.length() > 0.05 else Vector2.ZERO
	_arrow.visible = _arrow_dir != Vector2.ZERO


func toast(text: String) -> void:
	_toast.text = text
	_toast_t = 2.8
	_toast.modulate.a = 1.0


func set_boss_health(current: int, maximum: int, shown: bool) -> void:
	_boss_box.visible = shown
	_boss_ratio = clampf(float(current) / float(maximum), 0.0, 1.0) if maximum > 0 else 0.0


func show_area_card(title: String, subtitle: String) -> void:
	for c in _area_box.get_children():
		_area_box.remove_child(c)
		c.queue_free()
	var t := _make_label(15, Color(0.98, 0.94, 0.86))
	t.text = title
	t.add_theme_constant_override("outline_size", 6)
	_area_box.add_child(t)
	if subtitle != "":
		var s := _make_label(8, Color(0.78, 0.72, 0.94))
		s.text = subtitle
		s.add_theme_constant_override("outline_size", 5)
		_area_box.add_child(s)
	_area_card.visible = true
	_area_card.modulate.a = 1.0
	_area_t = 3.0


# --------------------------------------------------------------------------
func _process(delta: float) -> void:
	var vp := get_viewport_rect().size

	_heart_row.position = Vector2(8, 6)
	_item_row.position = Vector2(vp.x - _item_row.size.x - 8, 8)

	_prompt.size = Vector2(vp.x, 14)
	_prompt.position = Vector2(0, vp.y - 104)
	_toast.size = Vector2(vp.x, 14)
	_toast.position = Vector2(0, vp.y - 124)

	_goal_label.size = Vector2(vp.x - 16, 12)
	_goal_label.position = Vector2(10, vp.y - 142)

	if _arrow_dir != Vector2.ZERO:
		_arrow_pulse += delta
		var orbit := 34.0 + sin(_arrow_pulse * 3.0) * 2.0
		_arrow.position = vp * 0.5 + _arrow_dir * orbit
		_arrow.rotation = _arrow_dir.angle()
		_arrow.visible = true
	else:
		_arrow.visible = false

	var bar_w: float = clampf(vp.x - 200.0, 120.0, 320.0)
	_boss_box.position = Vector2((vp.x - bar_w) * 0.5, 40)
	_boss_box.size = Vector2(bar_w, 18)
	_boss_fill.size.x = bar_w * _boss_ratio
	var frame := _boss_box.get_node_or_null("Frame")
	if frame is ColorRect:
		(frame as ColorRect).size = Vector2(bar_w, 5)

	_area_card.position = Vector2.ZERO
	_area_card.size = vp
	_area_box.position = Vector2.ZERO
	_area_box.size = vp

	_blink += delta
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t < 0.7:
			_toast.modulate.a = clampf(_toast_t / 0.7, 0.0, 1.0)
	if _area_t > 0.0:
		_area_t -= delta
		var a := 1.0
		if _area_t > 2.3:
			a = (3.0 - _area_t) / 0.7
		elif _area_t < 0.7:
			a = _area_t / 0.7
		_area_card.modulate.a = clampf(a, 0.0, 1.0)
		if _area_t <= 0.0:
			_area_card.visible = false
