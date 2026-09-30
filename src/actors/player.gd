class_name Player
extends CharacterBody2D
## The survivor. Walks, swings the lantern-cutter, dashes, and takes damage.

signal died()

const SPEED := 74.0
const DASH_SPEED := 205.0
const DASH_TIME := 0.18
const DASH_COOLDOWN := 0.55
const ATTACK_TIME := 0.30
const ATTACK_HIT_AT := 0.10
const ATTACK_COOLDOWN := 0.34
const INVULN_TIME := 1.05
const KNOCKBACK := 118.0

const TEX := "res://assets/player.png"
const COLS := 5           # idle, walk1, walk2, atk1, atk2
const ROWS := 4           # down, up, left, right

var world: Node = null
var sprite: Sprite2D
var shadow: Polygon2D

var facing := Vector2.DOWN
var _facing_row := 0
var _walk_t := 0.0
var _anim_lock := 0.0

var _attack_t := -1.0
var _attack_cd := 0.0
var _dash_t := 0.0
var _dash_cd := 0.0
var _invuln := 0.0
var _hurt_flash := 0.0
var _locked := false
var _step_t := 0.0


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 8)
	shape.shape = rect
	shape.position = Vector2(0, -4)
	add_child(shape)

	shadow = Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(12):
		var a := TAU * float(i) / 12.0
		pts.append(Vector2(cos(a) * 6.0, sin(a) * 3.0))
	shadow.polygon = pts
	shadow.color = Color(0, 0, 0, 0.30)
	shadow.position = Vector2(0, -1)
	add_child(shadow)

	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.texture = load(TEX)
	sprite.hframes = COLS
	sprite.vframes = ROWS
	sprite.offset = Vector2(0, -10)
	add_child(sprite)


func facing_vector() -> Vector2:
	return facing


func is_locked() -> bool:
	return _locked


func lock(value: bool) -> void:
	_locked = value
	if value:
		velocity = Vector2.ZERO


func _physics_process(delta: float) -> void:
	_timers(delta)
	if _locked:
		velocity = Vector2.ZERO
		_update_sprite(delta)
		return

	var input := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down"))
	if input.length() > 1.0:
		input = input.normalized()

	if _attack_t < 0.0 and input != Vector2.ZERO:
		facing = input.normalized()
		_facing_row = _row_for(facing)

	if _dash_t > 0.0:
		velocity = facing * DASH_SPEED
	else:
		var speed := SPEED
		if _attack_t >= 0.0:
			speed *= 0.25
		velocity = input * speed

	move_and_slide()

	if input != Vector2.ZERO:
		_step_t += delta * input.length()
		if _step_t > 0.32:
			_step_t = 0.0
			Sfx.play("step", -12.0, randf_range(0.9, 1.1))

	_update_sprite(delta)


func _timers(delta: float) -> void:
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_dash_cd = maxf(0.0, _dash_cd - delta)
	_anim_lock = maxf(0.0, _anim_lock - delta)
	_invuln = maxf(0.0, _invuln - delta)
	_hurt_flash = maxf(0.0, _hurt_flash - delta)

	if _attack_t >= 0.0:
		_attack_t += delta
		if _attack_t >= ATTACK_HIT_AT and not _hit_done:
			_hit_done = true
			_swing()
		if _attack_t >= ATTACK_TIME:
			_attack_t = -1.0
			_hit_done = false
	if _dash_t > 0.0:
		_dash_t -= delta

	if not _locked:
		if Input.is_action_just_pressed("attack") and _attack_cd <= 0.0 and _attack_t < 0.0:
			_attack_t = 0.0
			_attack_cd = ATTACK_COOLDOWN
			_hit_done = false
			Sfx.play("swing", -4.0, randf_range(0.94, 1.08))
		if Input.is_action_just_pressed("dash") and _dash_cd <= 0.0 and _dash_t <= 0.0:
			_dash_t = DASH_TIME
			# the Crank winds the box a little tighter, and it winds you too
			_dash_cd = DASH_COOLDOWN * (0.45 if Game.has_flag("has_crank") else 1.0)
			Sfx.play("swing", -10.0, 1.6)

	if world != null:
		world.player_moved(self)


var _hit_done := false


func _swing() -> void:
	if world == null:
		return
	world.player_swing(global_position, facing)


func push_blocked(dir: Vector2) -> void:
	position -= dir * 4.0


func take_damage(amount: int, from: Vector2 = Vector2.ZERO) -> bool:
	if _invuln > 0.0 or _locked:
		return false
	_invuln = INVULN_TIME
	_hurt_flash = 0.28
	Game.damage_player(amount)
	Sfx.play("hurt")
	var away := (global_position - from)
	if away.length() < 1.0:
		away = -facing
	velocity = away.normalized() * KNOCKBACK
	if Game.hearts <= 0:
		died.emit()
	return true


func heal(amount: int) -> void:
	if Game.heal_player(amount) > 0:
		Sfx.play("heal")


func teleport(cell: Vector2i) -> void:
	position = Vector2(cell.x * 16, cell.y * 16 + 8)
	velocity = Vector2.ZERO
	_invuln = 0.7


# --------------------------------------------------------------------------
func _row_for(f: Vector2) -> int:
	if absf(f.x) > absf(f.y):
		return 2 if f.x < 0.0 else 3
	return 1 if f.y < 0.0 else 0


func _update_sprite(delta: float) -> void:
	if sprite == null:
		return
	var moving := velocity.length() > 8.0

	if _attack_t >= 0.0:
		sprite.frame = _facing_row * COLS + (3 if _attack_t < ATTACK_TIME * 0.5 else 4)
	elif _dash_t > 0.0:
		sprite.modulate = Color(0.7, 0.85, 1.0, 1.0)
		sprite.frame = _facing_row * COLS + 2
	elif moving:
		_walk_t += delta
		sprite.frame = _facing_row * COLS + (1 if fmod(_walk_t, 0.32) < 0.16 else 2)
		sprite.modulate = Color(1, 1, 1, 1)
	else:
		_walk_t = 0.0
		sprite.frame = _facing_row * COLS + 0
		sprite.modulate = Color(1, 1, 1, 1)

	if _invuln > 0.0:
		var blink := int(_invuln * 22.0) % 2 == 0
		sprite.modulate.a = 0.35 if blink else 1.0
	if _hurt_flash > 0.0:
		sprite.modulate = Color(1.0, 0.45, 0.45, sprite.modulate.a)
	if shadow != null:
		shadow.visible = _dash_t <= 0.0
