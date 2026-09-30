extends Node2D
## Game root: owns the world, the UI stack, and the state machine between
## playing / talking / in a menu / dead / won.

enum State { PLAY, DIALOGUE, MENU, TRANSITION, DEAD, WIN }

var state: int = State.PLAY
var world: World = null

var hud_layer: CanvasLayer
var menu_layer: CanvasLayer
var fade_layer: CanvasLayer

var hud: Hud
var dialogue: DialogueBox
var menu: MenuPanel
var fade: Fade

var _shot := false
var _shot_t := 0.0
var _shot_frames := 0
var _win_after_dialogue := false


func _ready() -> void:
	_build_ui()

	var area := "village"
	var spawn := "start"
	var talk := ""
	var menu_page := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot"):
			_shot = true
		elif a.begins_with("--area="):
			area = a.substr(7)
		elif a.begins_with("--spawn="):
			spawn = a.substr(8)
		elif a.begins_with("--talk="):
			talk = a.substr(7)
		elif a.begins_with("--menu="):
			menu_page = a.substr(7)

	await enter_area(area, spawn, false)
	if _shot:
		if menu_page != "":
			_open_menu(_menu_page_from(menu_page))
		if talk != "":
			open_dialogue(talk)
		return

	if not Game.started:
		Game.started = true
		Game.save_game()
		open_dialogue("box_intro")


func _menu_page_from(name: String) -> int:
	match name:
		"quests":
			return MenuPanel.Page.QUESTS
		"pause":
			return MenuPanel.Page.PAUSE
		"dead":
			return MenuPanel.Page.DEAD
		"win":
			return MenuPanel.Page.WIN
	return MenuPanel.Page.INVENTORY


func _build_ui() -> void:
	fade_layer = CanvasLayer.new()
	fade_layer.layer = 30
	add_child(fade_layer)
	fade = Fade.new()
	fade_layer.add_child(fade)

	hud_layer = CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)
	hud = Hud.new()
	hud_layer.add_child(hud)

	menu_layer = CanvasLayer.new()
	menu_layer.layer = 20
	add_child(menu_layer)
	dialogue = DialogueBox.new()
	menu_layer.add_child(dialogue)
	menu = MenuPanel.new()
	menu_layer.add_child(menu)
	menu.closed.connect(_on_menu_closed)


# --------------------------------------------------------------------------
# area flow
# --------------------------------------------------------------------------
func enter_area(area: String, spawn: String, do_fade: bool = true) -> void:
	if do_fade:
		state = State.TRANSITION
		await fade.fade_out(0.28)
	if world != null:
		world.queue_free()
		world = null
	await get_tree().process_frame

	Game.current_area = area
	Game.current_spawn = spawn
	world = World.new()
	add_child(world)
	world.build(area, spawn)
	world.travelled.connect(_on_travelled)
	world.notify.connect(func(t: String): hud.toast(t))
	world.player_died.connect(_on_player_died)
	world.boss_health.connect(_on_boss_health)
	world.boss_started.connect(_on_boss_started)
	world.boss_defeated.connect(_on_boss_defeated)

	Sfx.music(String(world.level.get("music", "village")))
	hud.show_area_card(String(world.level.get("name", "")),
		String(world.level.get("subtitle", "")))
	hud.set_prompt("")
	hud.set_boss_health(0, 0, false)

	if do_fade:
		await fade.fade_in(0.32)
		if world != null and world.player != null:
			world.player.lock(false)
		state = State.PLAY
	Game.save_game()


func _on_travelled(area: String, spawn: String) -> void:
	if state != State.PLAY:
		return
	if world != null and world.player != null:
		world.player.lock(true)
	enter_area(area, spawn, true)


# --------------------------------------------------------------------------
func _process(delta: float) -> void:
	if _shot:
		_shot_t += delta
		if _shot_t > 1.0 and _shot_frames < 3:
			_shoot()
		return
	if state != State.PLAY or world == null or world.player == null:
		return
	var p := world.player
	var e := world.nearest_interactable(p.global_position, p.facing_vector())
	hud.set_prompt(e.get_prompt() if e != null else "")
	if Input.is_action_just_pressed("interact") and e != null:
		_try_interact(e)
	_update_objective()


## Keeps the tracker line and the pointing arrow in sync with the quest state.
func _update_objective() -> void:
	var t := QuestData.current_target()
	if t.is_empty():
		hud.set_objective("")
		return
	var text := String(t.get("text", ""))
	var dir := Vector2.ZERO
	if String(t.get("area", "")) == world.level_id and world.player != null:
		var cell: Vector2i = t.get("cell", Vector2i.ZERO)
		var goal := Vector2(cell.x * 16 + 8, cell.y * 16 + 8)
		var delta := goal - world.player.global_position
		if delta.length() > 46.0:
			dir = delta.normalized()
	hud.set_objective(text, dir)


func _try_interact(e: Entity) -> void:
	var node_id := e.interact(world.player)
	if node_id == "":
		return
	if node_id == "ending":
		_win_after_dialogue = true
	open_dialogue(node_id)


func _on_dialogue_finished() -> void:
	if _win_after_dialogue:
		_win_after_dialogue = false
		_win()
		return
	if state != State.DIALOGUE:
		return
	state = State.PLAY
	if world != null and world.player != null:
		world.player.lock(false)


func open_dialogue(node_id: String) -> void:
	if node_id == "":
		return
	state = State.DIALOGUE
	if world != null and world.player != null:
		world.player.lock(true)
	dialogue.start(node_id)
	dialogue.finished.connect(_on_dialogue_finished, CONNECT_ONE_SHOT)


# --------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if _shot:
		return
#	dialogue.handle_input(event)
	menu.handle_input(event)
	if event.is_echo():
		return

	if event.is_action_pressed("pause"):
		if state == State.MENU:
			menu.close()
		elif state == State.PLAY:
			_open_menu(MenuPanel.Page.PAUSE)
		return

	if event.is_action_pressed("open_quests"):
		if state == State.PLAY:
			_open_menu(MenuPanel.Page.QUESTS)
		elif state == State.MENU:
			menu.close()
		return

	if event.is_action_pressed("open_inventory"):
		if state == State.PLAY:
			_open_menu(MenuPanel.Page.INVENTORY)
		elif state == State.MENU and menu.page == MenuPanel.Page.INVENTORY:
			menu.close()
		return

	if event.is_action_pressed("open_codex"):
		if state == State.PLAY:
			_open_menu(MenuPanel.Page.CODEX)
		elif state == State.MENU and menu.page == MenuPanel.Page.CODEX:
			menu.close()
		return


func _open_menu(p: int) -> void:
	state = State.MENU
	if world != null and world.player != null:
		world.player.lock(true)
	menu.open(p)


func _on_menu_closed() -> void:
	if state != State.MENU:
		return
	state = State.PLAY
	if world != null and world.player != null:
		world.player.lock(false)


# --------------------------------------------------------------------------
func _on_player_died() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	dialogue.stop()
	Sfx.stop_music(0.6)
	await get_tree().create_timer(1.0).timeout
	Game.hearts = Game.max_hearts
	Game.hearts_changed.emit(Game.hearts, Game.max_hearts)
	await enter_area("village", "start", true)
	state = State.DEAD
	menu.restart_requested.connect(_on_restart, CONNECT_ONE_SHOT)
	menu.open(MenuPanel.Page.DEAD)


func _on_restart() -> void:
	state = State.PLAY
	Sfx.music("village", 0.8)
	Game.hearts = Game.max_hearts
	Game.hearts_changed.emit(Game.hearts, Game.max_hearts)
	menu.close()


func _win() -> void:
	state = State.WIN
	dialogue.stop()
	Game.hearts = Game.max_hearts
	Game.hearts_changed.emit(Game.hearts, Game.max_hearts)
	Game.save_game()
	menu.quit_to_title_requested.connect(_to_title, CONNECT_ONE_SHOT)
	menu.open(MenuPanel.Page.WIN)


func _to_title() -> void:
	get_tree().change_scene_to_file("res://src/title.tscn")


func _on_boss_started() -> void:
	Sfx.music("boss", 0.4)


func _on_boss_defeated() -> void:
	await get_tree().create_timer(2.4).timeout
	if state == State.PLAY and world != null:
		open_dialogue("box_boss_end")


func _on_boss_health(current: int, maximum: int, shown: bool) -> void:
	hud.set_boss_health(current, maximum, shown)


func _shoot() -> void:
	_shot_frames += 1
	var img := get_viewport().get_texture().get_image()
	var path := "user://shot_%d.png" % _shot_frames
	img.save_png(path)
	print("SHOT ", ProjectSettings.globalize_path(path))
	if _shot_frames >= 3:
		get_tree().quit()
