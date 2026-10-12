class_name DamageNumber
extends Label

## Всплывающая цифра урона: появляется над целью, всплывает вверх
## и растворяется. Показывается в одном месте — take_damage() цели —
## чтобы любой источник урона (кирка, стрела) давал одинаковый фидбек.

const RISE_DISTANCE: float = 22.0
const LIFETIME: float = 0.7


static func show_at(
	world: Node,
	spawn_position: Vector2,
	amount: int,
	tint: Color = Color(1.0, 0.92, 0.55),
	font_size: int = 10
) -> void:
	if world == null or amount <= 0:
		return

	var number: DamageNumber = DamageNumber.new()
	number.text = str(amount)
	number.modulate = tint
	number.z_index = 200
	number.position = spawn_position
	number._font_size = font_size
	world.add_child(number)
	number._start_animation()


var _font_size: int = 10


func _ready() -> void:
	add_theme_font_size_override("font_size", _font_size)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Поле шире для крупного крита, чтобы цифры не обрезались.
	var half_width: float = 14.0 * float(_font_size) / 10.0
	offset_left = -half_width
	offset_right = half_width


func _start_animation() -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(
		self,
		"position:y",
		position.y - RISE_DISTANCE,
		LIFETIME
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(
		self,
		"modulate:a",
		0.0,
		LIFETIME
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.chain().tween_callback(queue_free)
