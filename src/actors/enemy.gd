class_name Enemy
extends CharacterBody2D
## Rust Ticks (walk at you, bite) and Gloom Moths (hover, keep distance, spit).

signal killed(enemy: Node)

const TICK_TEX := "res://assets/rust_tick.png"
const MOTH_TEX := "res://assets/gloom_moth.png"
const BULLET := "res://src/actors/projectile.gd"

const TILE := 16

var kind := "tick"
var world: Node = null
var sprite: Sprite2D

var hp := 2
var max_hp := 2
var speed := 34.0
var touch_damage := 1
var detect_range := 118.0
var flying := false

var _t := 0.0
var _touch_cd := 0.0
var _fire_cd := 2.0
var _knock := Vector2.ZERO
var _hurt_flash := 0.0
var _home := Vector2.ZERO
var _dead := false
var _patrol_dir := Vector2.RIGHT


static func spawn(kind_id: String, cell: Vector2i, world_ref: Node) -> Enemy:
	var e := Enemy.new()
	e.kind = kind_id
	e.world = world_ref
	e.name = "enemy_%s_%d_%d" % [kind_id, cell.x, cell.y]
	e.position = Vector2(cell.x * TILE + 8, cell.y * TILE + 8)
	match kind_id:
		"tick":
			e.hp = 2
			e.speed = 36.0
			e.touch_damage = 1
			e.detect_range = 104.0
		"moth":
			e.hp = 3
			e.speed = 40.0
			e.touch_damage = 1
			e.detect_range = 168.0
			e.flying = true
	return e


func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 4
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_home = position
	_patrol_dir = Vector2.RIGHT.rotated(randf() * TAU)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(12, 9) if kind == "tick" else Vector2(14, 10)
	shape.shape = rect
	add_child(shape)

	sprite = Sprite2D.new()
	sprite.centered = true
	sprite.texture = load(MOTH_TEX if kind == "moth" else TICK_TEX)
	sprite.hframes = 4
	sprite.vframes = 2
	sprite.position = Vector2(0, -3) if kind == "tick" else Vector2(0, -6)
	add_child(sprite)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_t += delta
	_touch_cd = maxf(0.0, _touch_cd - delta)
	_fire_cd = maxf(0.0, _fire_cd - delta)
	_hurt_flash = maxf(0.0, _hurt_flash - delta)

	var player: Node2D = world.get_player() if world != null else null
	var to_player := Vector2.ZERO
	var dist := 9999.0
	if player != null:
		to_player = player.global_position - global_position
		dist = to_player.length()

	var alerted := dist < detect_range
	var dir := Vector2.ZERO

	if alerted and dist > 0.001:
		dir = to_player / dist
		if kind == "moth" and dist < 52.0:
			dir = -dir          # moths keep their distance
	elif not flying:
		# lazy patrol near home
		if position.distance_to(_home) > 40.0:
			dir = (_home - position).normalized()
		else:
			dir = _patrol_dir

	var desired := dir * speed
	if flying:
		desired += Vector2(sin(_t * 2.6), cos(_t * 3.1)) * 12.0

	velocity = desired + _knock
	_knock = _knock.move_toward(Vector2.ZERO, 420.0 * delta)
	move_and_slide()

	# face the player (or travel direction)
	if sprite != null:
		var look := to_player if alerted else (velocity if velocity.length() > 4.0 else Vector2.RIGHT)
		if absf(look.x) < 1.0 and absf(look.y) < 1.0:
			look = Vector2.RIGHT
		var row := 0 if look.y >= 0.0 else 1
		var base := 0 if look.x >= 0.0 else 2
		sprite.flip_h = base == 2
		sprite.frame = row * 4 + int(_t * 6.0) % 4
		sprite.modulate = Color(1.6, 0.6, 0.6) if _hurt_flash > 0.0 else Color(1, 1, 1)

	if kind == "moth" and alerted and _fire_cd <= 0.0 and dist < 200.0:
		_fire_cd = 2.1 + randf() * 0.6
		_shoot(player)

	# contact damage
	if player != null and dist < (13.0 if kind == "tick" else 14.0) and _touch_cd <= 0.0:
		_touch_cd = 0.85
		if player.has_method("take_damage"):
			player.take_damage(touch_damage, global_position)


func _shoot(player: Node2D) -> void:
	var b := preload(BULLET).new()
	b.position = position + (player.global_position - global_position).normalized() * 10.0
	var dir := (player.global_position - global_position).normalized()
	b.setup(dir)
	if world != null:
		world.add_fx(b)
	Sfx.play("swing", -6.0, 1.45)


# --------------------------------------------------------------------------
func hurt(amount: int, from: Vector2 = Vector2.ZERO) -> void:
	if _dead:
		return
	hp -= amount
	_hurt_flash = 0.14
	_knock = (global_position - from).normalized() * 90.0
	Sfx.play("enemy_hurt", -4.0, randf_range(0.92, 1.1))
	if hp <= 0:
		die()


func die() -> void:
	if _dead:
		return
	_dead = true
	remove_from_group("enemy")
	Sfx.play("enemy_die", -3.0, randf_range(0.92, 1.08))
	killed.emit(self)
	if randf() < 0.45:
		_drop("cog", 1)
	elif randf() < 0.22:
		_drop("gear", 1)
	# bestiary: the first of each kind writes itself into the codex
	var tally := "tally_tick" if kind == "tick" else "tally_moth"
	if not Game.has_item(tally):
		Game.add_item(tally, 1)
		Game.report("Learned: %s" % ItemData.item_name(tally))
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.parallel().tween_property(sprite, "scale", Vector2(0.2, 0.2), 0.18)
	tw.tween_callback(queue_free)


func _drop(item: String, qty: int) -> void:
	if world == null:
		return
	world.spawn_drop(item, qty, position)
