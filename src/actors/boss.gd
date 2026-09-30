class_name Boss
extends CharacterBody2D
## The Corrosion. Three phases, one idea: it opens, and keeps opening.
##
## Phase 1  chase + slam
## Phase 2  radial spit
## Phase 3  faster, summons ticks, shockwave slam

signal health_changed(current: int, maximum: int)
signal defeated()
signal engaged()

enum State { IDLE, INTRO, CHASE, WINDUP, SLAM, SPIT, SUMMON, HURT, DEAD }

const TEX := "res://assets/boss.png"
const TILE := 16
const MAX_HP := 60

var world: Node = null
var sprite: Sprite2D
var hp := MAX_HP

var _state: int = State.IDLE
var _t := 0.0
var _state_t := 0.0
var _dead := false
var _phase := 1
var _knock := Vector2.ZERO
var _flash := 0.0
var _next := State.CHASE
var _shake := 0.0


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	collision_layer = 4
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	hp = MAX_HP
	z_index = 2

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(34, 26)
	shape.shape = rect
	shape.position = Vector2(0, -13)
	add_child(shape)

	sprite = Sprite2D.new()
	sprite.centered = true
	sprite.texture = load(TEX)
	sprite.hframes = 3
	sprite.vframes = 3
	sprite.position = Vector2(0, -24)
	add_child(sprite)
	health_changed.emit(hp, MAX_HP)


func phase() -> int:
	return _phase


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_t += delta
	_state_t += delta
	_flash = maxf(0.0, _flash - delta)
	_knock = _knock.move_toward(Vector2.ZERO, 260.0 * delta)

	_phase = 1
	if hp <= MAX_HP / 3:
		_phase = 3
	elif hp <= (MAX_HP * 2) / 3:
		_phase = 2

	var player: Node2D = world.get_player() if world != null else null
	var to_p := Vector2.ZERO
	if player != null:
		to_p = player.global_position - global_position

	match _state:
		State.IDLE:
			var idle_player: Node2D = world.get_player() if world != null else null
			if idle_player != null and global_position.distance_to(idle_player.global_position) < 150.0:
				_set_state(State.INTRO)
		State.INTRO:
			velocity = Vector2.ZERO
			if _state_t > 2.2:
				_set_state(State.CHASE)
		State.CHASE:
			_chase(to_p, delta)
		State.WINDUP:
			velocity = Vector2.ZERO
			if _state_t > 0.55:
				_set_state(State.SLAM)
		State.SLAM:
			if _state_t > 0.45:
				_slam_hit(player)
				_set_state(State.CHASE)
		State.SPIT:
			velocity = Vector2.ZERO
			if _state_t > 0.45:
				_spit(player)
				_set_state(State.CHASE)
		State.SUMMON:
			velocity = Vector2.ZERO
			if _state_t > 0.7:
				_summon()
				_set_state(State.CHASE)
		State.HURT:
			velocity = _knock
			if _state_t > 0.35:
				_set_state(State.CHASE)

	if _state != State.HURT:
		velocity += _knock
	move_and_slide()
	_update_sprite()


func _set_state(s: int) -> void:
	_state = s
	_state_t = 0.0
	match s:
		State.INTRO:
			Sfx.play("roar")
			engaged.emit()
			if world != null:
				world.shake(6.0, 0.9)
				world.spawn_text(global_position, "THE CORROSION", Color(1.0, 0.45, 0.3))
		State.WINDUP:
			if world != null:
				world.shake(2.0, 0.5)
		State.SLAM:
			if world != null:
				world.shake(7.0, 0.4)


func _chase(to_p: Vector2, delta: float) -> void:
	var dist := to_p.length()
	var dir := to_p.normalized() if dist > 0.001 else Vector2.ZERO
	if dist < 34.0:
		dir = -dir
	var spd := 40.0 + 10.0 * float(_phase)
	velocity = dir * spd + _knock

	# after recovering from an attack, immediately pick the next one
	if _state_t > 0.45:
		var roll := randf()
		if _phase >= 2 and roll < 0.32:
			_set_state(State.SPIT)
		elif _phase >= 3 and roll < 0.52:
			_set_state(State.SUMMON)
		else:
			_set_state(State.WINDUP)


func _slam_hit(player: Node2D) -> void:
	if world != null:
		world.shake(8.0, 0.35)
		world.spawn_ring(global_position + Vector2(0, -4), 46.0, Color(0.85, 0.45, 0.25))
	Sfx.play("hit", 2.0, 0.65)
	if player != null and player.global_position.distance_to(global_position) < 46.0:
		if player.has_method("take_damage"):
			player.take_damage(2, global_position)


func _spit(player: Node2D) -> void:
	if player == null or world == null:
		return
	var base := (player.global_position - global_position).normalized()
	var count := 6 + _phase * 2
	for i in count:
		var ang := TAU * float(i) / float(count) + _t
		var b := preload("res://src/actors/projectile.gd").new()
		b.world = world
		b.position = global_position + Vector2(0, -16)
		b.setup(base.rotated(ang - base.angle()) if i == 0 else base.rotated(ang * 0.5))
		if i > 0:
			b.setup((base.rotated(ang)).normalized())
		world.add_fx(b)
	Sfx.play("swing", 0.0, 0.7)


func _summon() -> void:
	if world == null:
		return
	var n := 1 + _phase
	for i in n:
		var ang := TAU * float(i) / float(n) + randf() * 0.5
		var off := Vector2(cos(ang), sin(ang) * 0.5) * 34.0
		var e := Enemy.spawn("tick", Vector2i.ZERO, world)
		e.position = global_position + off
		world.add_enemy(e)
	Sfx.play("roar", -6.0, 1.35)


func hurt(amount: int, from: Vector2 = Vector2.ZERO) -> void:
	if _dead:
		return
	hp = maxi(0, hp - amount)
	_flash = 0.14
	_knock = (global_position - from).normalized() * 60.0
	Sfx.play("enemy_hurt", 0.0, 0.75)
	health_changed.emit(hp, MAX_HP)
	if hp <= 0:
		_die()
	else:
		_set_state(State.HURT)


func _die() -> void:
	_dead = true
	remove_from_group("enemy")
	if world != null:
		world.shake(12.0, 1.4)
	Sfx.play("roar", 2.0, 0.55)
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(self, "modulate:a", 0.0, 1.1)
	tw.parallel().tween_property(sprite, "scale", Vector2(0.1, 0.1), 1.1)
	tw.tween_callback(func():
		defeated.emit())


func _update_sprite() -> void:
	if sprite == null:
		return
	var f := 0
	match _state:
		State.INTRO, State.WINDUP, State.SPIT, State.SUMMON:
			f = 1
		State.SLAM:
			f = 2
	var row := 0
	if _state == State.SLAM:
		row = 1
	elif _state == State.INTRO or _state == State.WINDUP:
		row = 0
	elif _state == State.CHASE or _state == State.HURT:
		row = int(_t * 4.0) % 2
	sprite.frame = row * 3 + f
	if _flash > 0.0:
		sprite.modulate = Color(2.0, 1.2, 1.2)
	elif _state == State.WINDUP:
		sprite.modulate = Color(1.0, 0.6 + 0.4 * sin(_t * 30.0), 0.5)
	else:
		sprite.modulate = Color(1, 1, 1)
