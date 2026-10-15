class_name ParrySparks extends CPUParticles2D

## Яркие искры при успешном парировании: вспыхивают в точке касания,
## разлетаются веером в сторону атакующего и быстро гаснут.
##
## CPUParticles2D, а не GPU-вариант: эффект короткий и одноразовый,
## CPU-версия настраивается прямо из кода и одинаково работает везде.

const LIFETIME: float = 0.32
const SPARK_AMOUNT: int = 28

## Палитра вспышки: белое ядро остывает через жёлтый к оранжевому
## и полностью растворяется к концу жизни искры (альфа 0 в конце ramp).
const CORE_COLOR: Color = Color(1.0, 1.0, 0.9, 1.0)
const EDGE_COLOR: Color = Color(1.0, 0.42, 0.05, 0.0)


## Создаёт и запускает искры в world на позиции hit_position.
## direction — куда летит сноп: от цели к атакующему, чтобы искры
## читались как «отбитый» удар, а не как попадание по игроку.
static func burst(world: Node, hit_position: Vector2, direction: Vector2) -> void:
	if world == null or not is_instance_valid(world):
		return

	var sparks := ParrySparks.new()
	sparks.name = "ParrySparks"
	sparks.z_index = 210
	world.add_child(sparks)
	sparks.global_position = hit_position

	var aim: Vector2 = direction if direction.length_squared() > 0.0001 else Vector2.RIGHT
	sparks.direction = aim
	sparks.emitting = true


func _ready() -> void:
	# PROCESS_MODE_ALWAYS: парирование возможно и на паузе, а по
	# завершении one_shot узел удаляет себя сам.
	process_mode = Node.PROCESS_MODE_ALWAYS
	one_shot = true
	lifetime = LIFETIME
	amount = SPARK_AMOUNT
	preprocess = 0.0
	explosiveness = 1.0

	# Веер в сторону атакующего: узкая конусность даёт читаемый сноп,
	# а не облако во все стороны.
	spread = 52.0
	gravity = Vector2(0.0, 460.0)

	initial_velocity_min = 170.0
	initial_velocity_max = 360.0
	angular_velocity_min = -200.0
	angular_velocity_max = 200.0
	damping_min = 240.0
	damping_max = 460.0

	# Частицы стартуют крупными белыми и гаснут до оранжевых: у
	# CPUParticles2D нет color_initial/color_final, градиент задаётся
	# через color_ramp — двухточечного Gradient достаточно.
	color = CORE_COLOR
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([CORE_COLOR, EDGE_COLOR])
	ramp.offsets = PackedFloat32Array([0.0, 1.0])
	color_ramp = ramp
	scale_amount_min = 0.9
	scale_amount_max = 1.8

	finished.connect(queue_free)
