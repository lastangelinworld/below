class_name BlockBreakEffect
extends Node2D


class Shard:
	var position: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var rotation: float = 0.0
	var rotation_speed: float = 0.0
	var size: Vector2 = Vector2.ONE
	var color: Color = Color.WHITE


## Продолжительность эффекта.
@export_range(0.1, 2.0, 0.05)
var duration: float = 0.55

## Количество крупных пиксельных осколков.
@export_range(1, 32, 1)
var shard_count: int = 8

## Сила падения осколков.
@export var shard_gravity: float = 420.0


var elapsed_time: float = 0.0
var shards: Array[Shard] = []
var random := RandomNumberGenerator.new()


## Настраивает размер и цвет эффекта.
func setup(
	block_size: Vector2,
	base_color: Color
) -> void:
	random.randomize()
	shards.clear()
	elapsed_time = 0.0

	var safe_width: float = maxf(
		block_size.x,
		1.0
	)
	var safe_height: float = maxf(
		block_size.y,
		1.0
	)

	for shard_index: int in range(shard_count):
		var shard := Shard.new()

		shard.position = Vector2(
			random.randf_range(
				-safe_width * 0.28,
				safe_width * 0.28
			),
			random.randf_range(
				-safe_height * 0.28,
				safe_height * 0.28
			)
		)

		shard.velocity = Vector2(
			random.randf_range(-115.0, 115.0),
			random.randf_range(-190.0, -85.0)
		)

		shard.rotation = random.randf_range(
			-PI,
			PI
		)

		shard.rotation_speed = random.randf_range(
			-8.0,
			8.0
		)

		var shard_width: float = (
			safe_width
			* random.randf_range(0.12, 0.20)
		)

		var shard_height: float = (
			safe_height
			* random.randf_range(0.12, 0.20)
		)

		shard.size = Vector2(
			shard_width,
			shard_height
		)

		if shard_index % 2 == 0:
			shard.color = base_color.lightened(0.12)
		else:
			shard.color = base_color.darkened(0.12)

		shards.append(shard)

	queue_redraw()


func _process(delta: float) -> void:
	elapsed_time += delta

	for shard: Shard in shards:
		shard.velocity.y += shard_gravity * delta
		shard.position += shard.velocity * delta
		shard.rotation += shard.rotation_speed * delta

	queue_redraw()

	if elapsed_time >= duration:
		queue_free()


func _draw() -> void:
	var animation_progress: float = clampf(
		elapsed_time / maxf(duration, 0.001),
		0.0,
		1.0
	)

	var current_alpha: float = 1.0 - animation_progress

	var size_multiplier: float = lerpf(
		1.0,
		0.35,
		animation_progress
	)

	for shard: Shard in shards:
		var draw_color: Color = shard.color
		draw_color.a *= current_alpha

		var current_size: Vector2 = (
			shard.size
			* size_multiplier
		)

		draw_set_transform(
			shard.position,
			shard.rotation,
			Vector2.ONE
		)

		draw_rect(
			Rect2(
				-current_size * 0.5,
				current_size
			),
			draw_color,
			true
		)

	# Возвращаем трансформацию рисования.
	draw_set_transform(
		Vector2.ZERO,
		0.0,
		Vector2.ONE
	)
