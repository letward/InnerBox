class_name Projectile
extends Node2D
## Gloom Moth spit. Flies straight, dies on the first solid tile.

const SPEED := 96.0
const LIFE := 3.4
const TILE := 16

var world: Node = null
var dir := Vector2.RIGHT
var _life := 0.0
var sprite: Sprite2D


func setup(direction: Vector2) -> void:
	dir = direction.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT


func _ready() -> void:
	add_to_group("projectile")
	z_index = 5
	sprite = Sprite2D.new()
	sprite.centered = true
	sprite.texture = load("res://assets/bullet.png")
	sprite.hframes = 4
	add_child(sprite)


func _process(delta: float) -> void:
	_life += delta
	position += dir * SPEED * delta
	if sprite != null:
		sprite.frame = int(_life * 12.0) % 4
		sprite.rotation += delta * 9.0
	if _life > LIFE:
		queue_free()
		return
	if world != null and world.bullet_blocked(position):
		_burst()
		return
	var player: Node2D = world.get_player() if world != null else null
	if player != null and position.distance_to(player.global_position) < 9.0:
		if player.has_method("take_damage"):
			player.take_damage(1, global_position)
		_burst()


func _burst() -> void:
	Sfx.play("block", -6.0, 1.6)
	queue_free()
