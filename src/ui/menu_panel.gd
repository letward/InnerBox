class_name MenuPanel
extends Control
## Full-screen panels: inventory, quest log, pause, death, victory.

signal closed()
signal restart_requested()
signal quit_to_title_requested()

enum Page { INVENTORY, QUESTS, CODEX, PAUSE, DEAD, WIN }

const ITEMS_TEX := "res://assets/items.png"
const BG := Color(0.04, 0.035, 0.08, 0.93)
const EDGE := Color(0.5, 0.42, 0.74, 0.85)
const GOLD := Color(0.97, 0.82, 0.45)

var page: int = Page.INVENTORY
var selected := 0

var _frame: PanelContainer
var _title: Label
var _body: VBoxContainer
var _footer: Label
var _sel_index := 0
var _rows: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = BG
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_frame = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.07, 0.16, 0.98)
	sb.border_color = EDGE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(12)
	_frame.add_theme_stylebox_override("panel", sb)
	add_child(_frame)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	_frame.add_child(col)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 13)
	_title.add_theme_color_override("font_color", GOLD)
	col.add_child(_title)

	var rule := ColorRect.new()
	rule.color = EDGE
	rule.custom_minimum_size = Vector2(0, 1)
	col.add_child(rule)

	_body = VBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 3)
	col.add_child(_body)

	_footer = Label.new()
	_footer.add_theme_font_size_override("font_size", 7)
	_footer.add_theme_color_override("font_color", Color(0.6, 0.56, 0.74))
	_footer.text = "W/S move   E use   Q/Esc close"
	col.add_child(_footer)


# --------------------------------------------------------------------------
func _frame_rect() -> Rect2:
	var vp := get_viewport_rect().size
	return Rect2(30, 20, vp.x - 60, vp.y - 40)


func _process(_delta: float) -> void:
	_frame.position = _frame_rect().position
	_frame.size = _frame_rect().size


func open(p: int) -> void:
	page = p
	_sel_index = 0
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.12)
	match p:
		Page.INVENTORY:
			_title.text = "SATCHEL"
			_footer.text = "E / Enter  use item      Q / Esc  close"
		Page.QUESTS:
			_title.text = "WHAT THE BOX ASKS OF ME"
			_footer.text = "Q / Esc  close"
		Page.CODEX:
			_title.text = "CODEX"
			_footer.text = "Q / Esc  close" 
		Page.PAUSE:
			_title.text = "PAUSED"
			_footer.text = "W/S move   E confirm   Q / Esc resume"
		Page.DEAD:
			_title.text = "THE SONG PICKS ITSELF UP"
			_footer.text = "E / Enter  wake up at Hollowmere"
		Page.WIN:
			_title.text = "THE LID IS OPEN"
			_footer.text = "E / Enter  return to the title"
	_rebuild()


func close() -> void:
	visible = false
	closed.emit()


func _rebuild() -> void:
	for c in _body.get_children():
		c.queue_free()
	_rows.clear()
	match page:
		Page.INVENTORY:
			_build_inventory()
		Page.QUESTS:
			_build_quests()
		Page.CODEX:
			_build_codex()
		Page.PAUSE:
			_build_pause()
		Page.DEAD:
			_build_dead()
		Page.WIN:
			_build_win()
	_refresh_selection()


func _build_inventory() -> void:
	var ids := Game.inventory.keys()
	ids.sort()
	if ids.is_empty():
		_add_text("Your hands are empty. That will not last.", Color(0.7, 0.68, 0.8), false)
		return
	for i in ids.size():
		var id := String(ids[i])
		var item := ItemData.get_item(id)
		var qty := Game.item_count(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(16, 16)
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var tex := AtlasTexture.new()
		tex.atlas = load(ITEMS_TEX)
		tex.region = ItemData.region(int(item.get("icon", 0)))
		tex.filter_clip = true
		icon.texture = tex
		row.add_child(icon)

		var nm := Label.new()
		nm.text = String(item.get("name", id)) + (" x%d" % qty if qty > 1 else "")
		nm.add_theme_font_size_override("font_size", 9)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if ItemData.is_usable(id):
			nm.add_theme_color_override("font_color", Color(0.72, 0.95, 0.74))
		row.add_child(nm)

		var usable := Label.new()
		usable.text = "use" if ItemData.is_usable(id) else ""
		usable.add_theme_font_size_override("font_size", 7)
		usable.add_theme_color_override("font_color", GOLD)
		row.add_child(usable)

		_body.add_child(row)
		_rows.append({"node": row, "id": id})

	var desc := Label.new()
	desc.name = "Desc"
	desc.add_theme_font_size_override("font_size", 8)
	desc.add_theme_color_override("font_color", Color(0.66, 0.63, 0.78))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(0, 26)
	_body.add_child(desc)


func _build_quests() -> void:
	var log := QuestData.build_log()
	if log.is_empty():
		_add_text("You have not been asked for anything yet.", Color(0.7, 0.68, 0.8), false)
		return
	for entry in log:
		var done := bool(entry["done"])
		var head := Label.new()
		head.text = ("✓ " if done else "• ") + String(entry["title"])
		head.add_theme_font_size_override("font_size", 10)
		head.add_theme_color_override("font_color",
			Color(0.55, 0.78, 0.6) if done else GOLD)
		_body.add_child(head)

		var obj := Label.new()
		obj.text = "    " + String(entry["objective"])
		obj.add_theme_font_size_override("font_size", 8)
		obj.add_theme_color_override("font_color",
			Color(0.5, 0.55, 0.58) if done else Color(0.78, 0.75, 0.88))
		_body.add_child(obj)
		_body.add_child(_spacer(3))


func _build_codex() -> void:
	var found := ItemData.found_lore()
	if found.is_empty():
		_add_text("Nothing here yet.", Color(0.7, 0.68, 0.8), false)
		_add_text("Echoes are left where the box still remembers something. Fight something new and it writes itself down.",
			Color(0.6, 0.58, 0.72), false)
		return
	for id in found:
		var head := Label.new()
		head.text = String(ItemData.get_item(id).get("name", id))
		head.add_theme_font_size_override("font_size", 10)
		head.add_theme_color_override("font_color", Color(0.78, 0.72, 0.96))
		_body.add_child(head)

		var txt := Label.new()
		txt.text = String(ItemData.get_item(id).get("desc", ""))
		txt.add_theme_font_size_override("font_size", 8)
		txt.add_theme_color_override("font_color", Color(0.74, 0.72, 0.86))
		txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.add_child(txt)
		_body.add_child(_spacer(4))


func _build_pause() -> void:
	var entries := [
		{"text": "Resume", "action": "resume"},
		{"text": "Quest log", "action": "quests"},
		{"text": "Codex", "action": "codex"},
		{"text": "Save the song", "action": "save"},
		{"text": "Return to title", "action": "title"},
	]
	for e in entries:
		var l := _add_text(String(e["text"]), GOLD, true)
		l.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_rows.append({"node": l, "id": String(e["action"])})


func _build_dead() -> void:
	_add_text("You come apart into a note that nobody was playing.", Color(0.86, 0.8, 0.9), false)
	_add_text("Somewhere in the box, the song picks itself up and starts again.",
		Color(0.7, 0.66, 0.8), false)
	_add_text("", Color.WHITE, false)
	_add_text("Wake up in Hollowmere. The shards stay with you.", GOLD, false)


func _build_win() -> void:
	_add_text("The lid is open. The box is playing again.", GOLD, false)
	_add_text("", Color.WHITE, false)
	_add_text("Quests finished: %d / %d" % [_finished_count(), QuestData.QUESTS.size()],
		Color(0.8, 0.78, 0.9), false)
	_add_text("Codex entries found: %d / %d"
		% [ItemData.found_lore().size(), ItemData.found_lore_total()],
		Color(0.8, 0.78, 0.9), false)


func _finished_count() -> int:
	var n := 0
	for q in QuestData.QUESTS.keys():
		if Game.quest_state(String(q)) == "done":
			n += 1
	return n


func _add_text(text: String, color: Color, selectable: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 9)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(l)
	return l


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


# --------------------------------------------------------------------------
func _refresh_selection() -> void:
	for i in _rows.size():
		var row: Dictionary = _rows[i]
		var node: Control = row["node"]
		if node is HBoxContainer:
			node.modulate = Color(1, 1, 1) if i == _sel_index else Color(0.72, 0.7, 0.78)
		else:
			node.add_theme_color_override("font_color",
				GOLD if i == _sel_index else Color(0.78, 0.75, 0.88))
	var desc := _body.get_node_or_null("Desc")
	if desc is Label and _sel_index < _rows.size():
		(desc as Label).text = ItemData.item_desc(String(_rows[_sel_index]["id"]))


func handle_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		_move(1)
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		_move(-1)
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("open_quests") \
			or event.is_action_pressed("open_codex") or event.is_action_pressed("pause"):
		Sfx.play("menu", -8.0)
		if page == Page.PAUSE:
			close()
		elif page != Page.DEAD and page != Page.WIN:
			close()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		_confirm()


func _move(dir: int) -> void:
	if _rows.is_empty():
		return
	_sel_index = wrapi(_sel_index + dir, 0, _rows.size())
	Sfx.play("menu", -12.0)
	_refresh_selection()


func _confirm() -> void:
	Sfx.play("confirm", -6.0)
	match page:
		Page.INVENTORY:
			_use_selected()
		Page.PAUSE:
			_pause_choice()
		Page.DEAD:
			restart_requested.emit()
		Page.WIN:
			quit_to_title_requested.emit()


func _use_selected() -> void:
	if _sel_index >= _rows.size():
		return
	var id := String(_rows[_sel_index]["id"])
	if not ItemData.is_usable(id):
		Sfx.play("block", -6.0)
		return
	if id == "salve":
		if Game.hearts >= Game.max_hearts:
			Sfx.play("block", -6.0)
			return
		Game.remove_item("salve", 1)
		Game.heal_player(3)
		Sfx.play("heal")
		_rebuild()
		return
	if id == "charm":
		Game.remove_item("charm", 1)
		Game.max_hearts += 1
		Game.hearts = Game.max_hearts
		Game.hearts_changed.emit(Game.hearts, Game.max_hearts)
		Sfx.play("objective")
		Game.report("The charm holds. One heart more.")
		_rebuild()
		return
	Sfx.play("block", -6.0)


func _pause_choice() -> void:
	if _sel_index >= _rows.size():
		return
	match String(_rows[_sel_index]["id"]):
		"resume":
			close()
		"quests":
			open(Page.QUESTS)
		"codex":
			open(Page.CODEX)
		"save":
			Game.save_game()
			close()
		"title":
			quit_to_title_requested.emit()
