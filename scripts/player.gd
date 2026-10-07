extends CharacterBody2D


signal health_changed(current_health: int, maximum_health: int)
signal stamina_changed(current_stamina: float, maximum_stamina: float)
signal died


enum MiningAreaOrientation {
	VERTICAL,
	HORIZONTAL
}


@export_group("Movement")

## Максимальная горизонтальная скорость.
@export var move_speed: float = 220.0

## Ускорение при движении.
@export var acceleration: float = 1600.0

## Замедление после отпускания движения.
@export var deceleration: float = 2000.0

## Скорость прыжка.
@export var jump_velocity: float = -420.0

## Обычная максимальная скорость падения.
@export var maximum_fall_speed: float = 900.0


@export_group("Animation")

## Минимальная скорость, при которой включается walk.
@export_range(0.0, 100.0, 1.0)
var walk_animation_threshold: float = 5.0

## Дополнительная поправка направления руки.
## Если рука смотрит точно на мышь, оставь 0.
@export_range(-180.0, 180.0, 1.0)
var arm_aim_offset_degrees: float = 0.0


@export_group("Cursor Body Lean")

## Включает плавный наклон верхней части тела к курсору.
@export var cursor_body_lean_enabled: bool = true

## Сила наклона торса относительно вертикального направления курсора.
@export_range(0.0, 1.0, 0.01)
var body_lean_strength: float = 0.18

## Максимальный наклон торса вверх.
@export_range(0.0, 30.0, 0.5)
var maximum_body_lean_up_degrees: float = 7.0

## Максимальный наклон торса вниз.
@export_range(0.0, 30.0, 0.5)
var maximum_body_lean_down_degrees: float = 9.0

## Дополнительная доля наклона для головы.
@export_range(0.0, 1.0, 0.05)
var head_lean_multiplier: float = 0.45

## Максимальный дополнительный наклон головы.
@export_range(0.0, 30.0, 0.5)
var maximum_head_lean_degrees: float = 4.0

## Скорость возврата торса и головы в целевой угол.
@export_range(0.1, 30.0, 0.1)
var body_lean_smoothing: float = 10.0

## Мёртвая зона курсора, предотвращающая мелкую дрожь.
@export_range(0.0, 64.0, 1.0)
var body_lean_mouse_dead_zone: float = 12.0


@export_group("Secondary Motion")

## Скорость дыхания в состоянии покоя.
@export_range(0.1, 3.0, 0.05)
var idle_breath_speed: float = 1.0

## Скорость дыхания во время ходьбы.
@export_range(0.1, 3.0, 0.05)
var walk_breath_speed: float = 1.25

## Скорость дыхания в воздухе.
@export_range(0.1, 3.0, 0.05)
var air_breath_speed: float = 0.85

## Скорость изменения текущей скорости дыхания.
@export_range(0.1, 10.0, 0.1)
var breath_speed_change: float = 1.5


@export_group("Block Environment")

## Отступ внутрь физической формы при проверке
## проходимых блоков.
@export_range(0.0, 8.0, 0.5)
var environment_detection_inset: float = 2.0


@export_group("Health")

## Максимальное здоровье персонажа.
@export_range(1, 10000, 1)
var max_health: int = 100

## Если включено, после достижения нуля персонаж
## больше не принимает урон и не управляется.
@export var stop_on_death: bool = true


@export_group("Stamina")

## Максимальный запас выносливости.
@export_range(1.0, 1000.0, 1.0)
var max_stamina: float = 100.0

## Скорость восстановления выносливости в секунду.
@export_range(0.0, 1000.0, 0.5)
var stamina_regeneration_per_second: float = 20.0

## Задержка восстановления после расхода выносливости.
@export_range(0.0, 10.0, 0.05)
var stamina_regeneration_delay: float = 0.8

## Стоимость одного удара киркой.
@export_range(0.0, 100.0, 0.5)
var attack_stamina_cost: float = 8.0

## Стоимость прыжка.
@export_range(0.0, 100.0, 0.5)
var jump_stamina_cost: float = 12.0


@export_group("Hazard Contact")

## Дополнительный отступ наружу при поиске опасных блоков.
@export_range(0.0, 16.0, 0.5)
var hazard_contact_margin: float = 2.0

## Урон по умолчанию, если у BlockType нет contact_damage.
@export_range(0, 1000, 1)
var default_hazard_contact_damage: int = 10

## Интервал урона по умолчанию для опасных блоков.
@export_range(0.05, 10.0, 0.05)
var default_hazard_contact_interval: float = 0.75


@export_group("Mining")

## Ссылка на Terrain из основной сцены.
@export var terrain: TerrainLayer

## Уровень инструмента.
@export_range(0, 99, 1)
var tool_level: int = 1

## Урон за один удар, если выключено Destroy Blocks In One Hit.
@export_range(1, 100, 1)
var mining_damage: int = 1

## Максимальная дальность от ближайшей точки коллизии игрока
## до ближайшей точки блока, в размерах клетки.
## Этот параметр теперь участвует и в выборе клетки по курсору,
## и в финальной проверке перед нанесением урона.
@export_range(1.0, 20.0, 0.5)
var mining_reach_in_tiles: float = 5.0

## Минимальный интервал между началами атак.
@export_range(0.05, 5.0, 0.05)
var mining_interval: float = 0.25


@export_group("Mining Area")

## Обычная боковая атака работает по одному
## выбранному курсором блоку.
@export_range(1, 2, 1)
var normal_front_mining_height: int = 1

## Действие, удержание которого включает
## расширенный боковой удар.
@export var wide_mining_action: StringName = &"mine_wide"

## Количество блоков в расширенном боковом ударе.
@export_range(1, 2, 1)
var wide_front_mining_height: int = 2

## Количество клеток, обрабатываемых расширенным ударом.
@export_range(1, 10, 1)
var mining_area_height: int = 2

## Расстояние от края коллизии игрока до первой клетки.
@export_range(0.0, 64.0, 1.0)
var mining_area_gap: float = 4.0

## Смещение всей области по вертикали в клетках.
@export_range(-4, 4, 1)
var mining_area_vertical_offset: int = 0

## Vertical создаёт колонку 1 x Mining Area Height.
## Horizontal создаёт ряд в направлении взгляда.
@export_enum("Vertical", "Horizontal")
var mining_area_orientation: int = MiningAreaOrientation.VERTICAL

## Если включено, каждый подходящий блок области
## разрушается одним попаданием независимо от его HP.
@export var destroy_blocks_in_one_hit: bool = true


@export_group("Directional Mining")

## Разрешает разрушать блоки непосредственно над игроком.
@export var allow_mining_above: bool = true

## Разрешает разрушать блоки непосредственно под игроком.
@export var allow_mining_below: bool = true

## Определяет ширину вертикального сектора атаки.
@export_range(0.0, 4.0, 0.05)
var vertical_attack_ratio: float = 0.75

## Разрешает разрушать проходимые блоки, находящиеся непосредственно
## за телом персонажа (например, паутину).
@export var allow_mining_overlapping_cells: bool = true

## Если клетка прямо над персонажем пуста, разрешает добывать
## две верхние боковые клетки слева и справа от неё.
@export var allow_mining_upper_corners: bool = true


@export_group("Inventory")

## Все ItemData-ресурсы проекта. Они автоматически регистрируются при запуске.
@export var item_catalog: Array[ItemData] = []

## Основной инвентарь: 27 ячеек + 9 ячеек панели быстрого доступа.
@export_range(1, 999, 1) var inventory_slot_count: int = 36

## Максимальный переносимый вес в килограммах.
@export_range(0.0, 999999.0, 0.1) var inventory_max_weight_kg: float = 300.0


@onready var visuals: Node2D = $Visuals
@onready var player_collision: CollisionShape2D = $CollisionShape2D
@onready var body_breath: Node2D = $Visuals/BodyBreath
@onready var head_breath: Node2D = get_node_or_null(
	"Visuals/BodyBreath/HeadBreath"
) as Node2D
@onready var front_arm_aim: Node2D = $Visuals/BodyBreath/FrontArmAim
@onready var locomotion_player: AnimationPlayer = $LocomotionPlayer
@onready var attack_player: AnimationPlayer = $AttackPlayer
@onready var secondary_motion_player: AnimationPlayer = (
	$Visuals/SecondaryMotionPlayer
)
@onready var mining_cooldown: Timer = $MiningCooldown


## Стандартная гравитация проекта.
var gravity: float = float(
	ProjectSettings.get_setting(
		"physics/2d/default_gravity",
		980.0
	)
)

var current_health: int = 100
var current_stamina: float = 100.0
var stamina_regeneration_allowed_at: float = 0.0
var is_dead: bool = false
var hazard_damage_allowed_at: Dictionary = {}
var environment_movement_multiplier: float = 1.0
var environment_vertical_multiplier: float = 1.0
var environment_animation_multiplier: float = 1.0
var current_breath_speed: float = 1.0
var facing: int = 1
var visuals_base_scale_x: float = 1.0
var pickaxe_swinging: bool = false
var combo_step: int = 0
var attack_serial: int = 0

## Исходный угол BodyBreath.
var body_breath_base_rotation: float = 0.0

## Исходный угол головы, если узел HeadBreath существует.
var head_breath_base_rotation: float = 0.0

## Текущие сглаженные углы наклона.
var current_body_lean: float = 0.0
var current_head_lean: float = 0.0

## Инвентарь создаётся автоматически в _ready().
var inventory: InventoryData
var opened_chest: ChestContainer = null


func _ready() -> void:
	add_to_group("player")
	_initialize_inventory()
	visuals_base_scale_x = absf(visuals.scale.x)
	body_breath_base_rotation = body_breath.rotation

	if head_breath != null:
		head_breath_base_rotation = head_breath.rotation

	current_health = maxi(1, max_health)
	current_stamina = clampf(max_stamina, 0.0, max_stamina)

	mining_cooldown.one_shot = true
	mining_cooldown.wait_time = mining_interval

	if not mining_cooldown.timeout.is_connected(_on_mining_cooldown_timeout):
		mining_cooldown.timeout.connect(_on_mining_cooldown_timeout)

	if not attack_player.animation_finished.is_connected(_on_attack_animation_finished):
		attack_player.animation_finished.connect(_on_attack_animation_finished)

	_validate_animations()
	_play_locomotion_animation(&"idle")

	current_breath_speed = idle_breath_speed
	_start_secondary_motion()

	health_changed.emit(current_health, max_health)
	stamina_changed.emit(current_stamina, max_stamina)


func _physics_process(delta: float) -> void:
	if is_dead and stop_on_death:
		_update_stamina(delta)
		return

	_update_environment_modifiers()
	_apply_gravity(delta)
	_handle_jump()
	_handle_horizontal_movement(delta)

	move_and_slide()

	_update_stamina(delta)
	_update_hazard_damage(delta)
	_update_locomotion_animation()
	_update_secondary_motion(delta)


func _process(delta: float) -> void:
	if is_dead and stop_on_death:
		return

	_update_facing()
	_update_cursor_body_lean(delta)
	_update_arm_aim()
	_update_held_attack()


func _validate_animations() -> void:
	var locomotion_animations: Array[StringName] = [&"idle", &"walk"]

	for animation_name: StringName in locomotion_animations:
		if not locomotion_player.has_animation(animation_name):
			push_error("LocomotionPlayer: отсутствует анимация " + String(animation_name))

	var attack_animations: Array[StringName] = [&"attack_1", &"attack_2", &"attack_3"]

	for animation_name: StringName in attack_animations:
		if not attack_player.has_animation(animation_name):
			push_error("AttackPlayer: отсутствует анимация " + String(animation_name))

	if not secondary_motion_player.has_animation(&"life_loop"):
		push_error("SecondaryMotionPlayer: отсутствует анимация life_loop")


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return

	velocity.y += gravity * environment_vertical_multiplier * delta
	var current_maximum_fall_speed: float = maximum_fall_speed * environment_vertical_multiplier
	velocity.y = minf(velocity.y, current_maximum_fall_speed)


func _handle_jump() -> void:
	if not Input.is_action_just_pressed(&"jump"):
		return
	if not is_on_floor():
		return
	if not spend_stamina(jump_stamina_cost):
		return
	velocity.y = jump_velocity * environment_vertical_multiplier


func _handle_horizontal_movement(delta: float) -> void:
	var direction: float = Input.get_axis(&"move_left", &"move_right")
	var effective_move_speed: float = move_speed * environment_movement_multiplier
	var target_velocity_x: float = direction * effective_move_speed
	var change_rate: float

	if absf(target_velocity_x) < absf(velocity.x):
		change_rate = deceleration
	else:
		change_rate = acceleration * maxf(environment_movement_multiplier, 0.2)

	if direction == 0.0:
		change_rate = deceleration

	velocity.x = move_toward(velocity.x, target_velocity_x, change_rate * delta)


func _update_locomotion_animation() -> void:
	var is_walking: bool = is_on_floor() and absf(velocity.x) > walk_animation_threshold

	if is_walking:
		var effective_move_speed: float = move_speed * environment_movement_multiplier
		var speed_ratio: float = absf(velocity.x) / maxf(effective_move_speed, 1.0)
		locomotion_player.speed_scale = clampf(speed_ratio, 0.35, 1.5) * environment_animation_multiplier
		_play_locomotion_animation(&"walk")
	else:
		locomotion_player.speed_scale = 1.0
		_play_locomotion_animation(&"idle")


func _play_locomotion_animation(animation_name: StringName) -> void:
	if not locomotion_player.has_animation(animation_name):
		return

	var animation_changed: bool = locomotion_player.current_animation != animation_name
	if animation_changed or not locomotion_player.is_playing():
		locomotion_player.play(animation_name, 0.12)


func _start_secondary_motion() -> void:
	if not secondary_motion_player.has_animation(&"life_loop"):
		return
	secondary_motion_player.speed_scale = idle_breath_speed
	secondary_motion_player.play(&"life_loop")


func _update_secondary_motion(delta: float) -> void:
	if not secondary_motion_player.has_animation(&"life_loop"):
		return

	var target_breath_speed: float = idle_breath_speed
	if not is_on_floor():
		target_breath_speed = air_breath_speed
	elif absf(velocity.x) > walk_animation_threshold:
		target_breath_speed = walk_breath_speed

	target_breath_speed *= environment_animation_multiplier
	current_breath_speed = move_toward(current_breath_speed, target_breath_speed, breath_speed_change * delta)
	secondary_motion_player.speed_scale = current_breath_speed


func _update_facing() -> void:
	if pickaxe_swinging:
		return

	var mouse_offset_x: float = get_global_mouse_position().x - global_position.x
	if absf(mouse_offset_x) <= 2.0:
		return

	facing = 1 if mouse_offset_x > 0.0 else -1
	visuals.scale.x = visuals_base_scale_x * float(facing)


## Плавно наклоняет верхнюю часть тела к курсору.
## Коллизия и положение CharacterBody2D не изменяются.
func _update_cursor_body_lean(delta: float) -> void:
	if body_breath == null:
		return

	var target_body_lean: float = 0.0
	var target_head_lean: float = 0.0

	if cursor_body_lean_enabled and not is_dead:
		var mouse_visual_position: Vector2 = visuals.to_local(get_global_mouse_position())
		var aim_offset: Vector2 = mouse_visual_position - body_breath.position

		if aim_offset.length() > body_lean_mouse_dead_zone:
			var cursor_angle: float = atan2(aim_offset.y, maxf(absf(aim_offset.x), 0.001))
			var desired_body_lean: float = cursor_angle * body_lean_strength
			var maximum_up_rotation: float = deg_to_rad(maximum_body_lean_up_degrees)
			var maximum_down_rotation: float = deg_to_rad(maximum_body_lean_down_degrees)

			target_body_lean = clampf(desired_body_lean, -maximum_up_rotation, maximum_down_rotation)
			var maximum_head_rotation: float = deg_to_rad(maximum_head_lean_degrees)
			target_head_lean = clampf(target_body_lean * head_lean_multiplier, -maximum_head_rotation, maximum_head_rotation)

	var smoothing_weight: float = 1.0 - exp(-body_lean_smoothing * delta)
	current_body_lean = lerp_angle(current_body_lean, target_body_lean, smoothing_weight)
	current_head_lean = lerp_angle(current_head_lean, target_head_lean, smoothing_weight)

	body_breath.rotation = body_breath_base_rotation + current_body_lean

	if head_breath != null:
		head_breath.rotation = head_breath_base_rotation + current_head_lean


func _update_arm_aim() -> void:
	if pickaxe_swinging:
		return

	var aim_parent: Node2D = front_arm_aim.get_parent() as Node2D
	if aim_parent == null:
		return

	var mouse_in_parent: Vector2 = aim_parent.to_local(get_global_mouse_position())
	var aim_direction: Vector2 = mouse_in_parent - front_arm_aim.position
	if aim_direction.length_squared() < 0.001:
		return

	front_arm_aim.rotation = aim_direction.angle() + deg_to_rad(arm_aim_offset_degrees)


func _update_held_attack() -> void:
	if Input.is_action_just_pressed(&"primary_action"):
		combo_step = 0
	if not Input.is_action_pressed(&"primary_action"):
		return
	if pickaxe_swinging:
		return
	if not mining_cooldown.is_stopped():
		return
	_start_next_combo_attack()


func _start_next_combo_attack() -> void:
	if pickaxe_swinging or not mining_cooldown.is_stopped():
		return
	if not spend_stamina(attack_stamina_cost):
		return

	combo_step += 1
	if combo_step > 3:
		combo_step = 1

	var animation_name: StringName = StringName("attack_%d" % combo_step)
	if not attack_player.has_animation(animation_name):
		push_error("AttackPlayer: не найдена анимация " + String(animation_name))
		combo_step = 0
		return

	_update_facing()
	_update_arm_aim()
	pickaxe_swinging = true
	attack_serial += 1
	mining_cooldown.start(mining_interval)
	attack_player.stop()
	attack_player.play(animation_name)
	_schedule_attack_hit(combo_step, attack_serial)


func _schedule_attack_hit(attack_number: int, current_attack_serial: int) -> void:
	var hit_delay: float = _get_attack_hit_delay(attack_number)
	var hit_timer: SceneTreeTimer = get_tree().create_timer(hit_delay)
	hit_timer.timeout.connect(_on_attack_hit_timeout.bind(current_attack_serial))


func _get_attack_hit_delay(attack_number: int) -> float:
	match attack_number:
		1:
			return 0.22
		2:
			return 0.18
		3:
			return 0.31
		_:
			return 0.20


func _on_attack_hit_timeout(expected_attack_serial: int) -> void:
	if expected_attack_serial != attack_serial or not pickaxe_swinging:
		return
	_on_pickaxe_hit()


func get_front_mining_cells() -> Array[Vector2i]:
	return _get_front_mining_cells()


## Возвращает клетку под указателем только тогда, когда она доступна
## по правилам соседства с телом персонажа.
func _get_front_mining_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if terrain == null or terrain.tile_set == null:
		return result

	var mouse_cell: Vector2i = terrain.global_position_to_cell(
		get_global_mouse_position()
	)
	if is_cell_mineable(mouse_cell):
		result.append(mouse_cell)
	return result


func get_attack_mining_cells() -> Array[Vector2i]:
	return _get_attack_mining_cells()


## И курсор, и фактический удар используют клетку непосредственно
## под мышью. Благодаря этому подсветка никогда не расходится с ударом.
func _get_attack_mining_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if terrain == null or terrain.tile_set == null:
		return result

	var mouse_cell: Vector2i = terrain.global_position_to_cell(
		get_global_mouse_position()
	)
	if is_cell_mineable(mouse_cell):
		result.append(mouse_cell)
	return result


## Границы клеток, которые пересекает коллизия персонажа.
## Rect2i.position — верхняя левая клетка, end — правая нижняя граница
## (не включительно).
func _get_player_occupied_cell_bounds() -> Rect2i:
	if terrain == null or terrain.tile_set == null:
		return Rect2i()

	var collision_rect: Rect2 = _get_collision_global_rect(false)
	var inset := Vector2(0.5, 0.5)
	var first_cell: Vector2i = terrain.global_position_to_cell(
		collision_rect.position + inset
	)
	var last_cell: Vector2i = terrain.global_position_to_cell(
		collision_rect.end - inset
	)

	var minimum_cell := Vector2i(
		mini(first_cell.x, last_cell.x),
		mini(first_cell.y, last_cell.y)
	)
	var maximum_cell := Vector2i(
		maxi(first_cell.x, last_cell.x),
		maxi(first_cell.y, last_cell.y)
	)
	return Rect2i(
		minimum_cell,
		maximum_cell - minimum_cell + Vector2i.ONE
	)


## Проверяет именно схему доступных клеток:
## 1. клетки, пересекающие тело персонажа;
## 2. клетки непосредственно слева, справа, сверху и снизу;
## 3. верхние угловые клетки — только после очистки клетки над головой.
func _is_cell_in_allowed_mining_shape(cell_coordinates: Vector2i) -> bool:
	var occupied: Rect2i = _get_player_occupied_cell_bounds()
	if occupied.size.x <= 0 or occupied.size.y <= 0:
		return false

	var left_x: int = occupied.position.x
	var right_x: int = occupied.end.x - 1
	var top_y: int = occupied.position.y
	var bottom_y: int = occupied.end.y - 1

	if allow_mining_overlapping_cells and occupied.has_point(cell_coordinates):
		return true

	# Боковые клетки по всей высоте персонажа.
	if (
		cell_coordinates.y >= top_y
		and cell_coordinates.y <= bottom_y
		and (
			cell_coordinates.x == left_x - 1
			or cell_coordinates.x == right_x + 1
		)
	):
		return true

	# Клетки непосредственно над головой.
	if (
		allow_mining_above
		and cell_coordinates.y == top_y - 1
		and cell_coordinates.x >= left_x
		and cell_coordinates.x <= right_x
	):
		return true

	# Клетки непосредственно под ногами.
	if (
		allow_mining_below
		and cell_coordinates.y == bottom_y + 1
		and cell_coordinates.x >= left_x
		and cell_coordinates.x <= right_x
	):
		return true

	if not allow_mining_above or not allow_mining_upper_corners:
		return false

	# Верхний левый угол становится доступен только тогда, когда
	# соседняя клетка прямо над левой частью персонажа уже пуста.
	var upper_left_corner := Vector2i(left_x - 1, top_y - 1)
	if cell_coordinates == upper_left_corner:
		var left_gateway := Vector2i(left_x, top_y - 1)
		return not terrain.has_block_at_cell(left_gateway)

	# Аналогичное правило для верхнего правого угла.
	var upper_right_corner := Vector2i(right_x + 1, top_y - 1)
	if cell_coordinates == upper_right_corner:
		var right_gateway := Vector2i(right_x, top_y - 1)
		return not terrain.has_block_at_cell(right_gateway)

	return false


## Публичная проверка геометрической дальности для BlockCursor
## и других систем проекта.
func is_cell_in_mining_reach(cell_coordinates: Vector2i) -> bool:
	return _is_cell_in_mining_reach(cell_coordinates)


## Главная общая проверка доступности клетки. Её используют и курсор,
## и нанесение урона, поэтому зелёная подсветка всегда означает,
## что выбранный блок действительно можно ударить.
func is_cell_mineable(cell_coordinates: Vector2i) -> bool:
	if terrain == null or terrain.tile_set == null:
		return false
	if not _is_cell_in_mining_reach(cell_coordinates):
		return false
	return _is_cell_in_allowed_mining_shape(cell_coordinates)


func _get_mining_reach_pixels() -> float:
	if terrain == null or terrain.tile_set == null:
		return 0.0

	var tile_size: Vector2 = Vector2(terrain.tile_set.tile_size)
	return maxf(0.0, mining_reach_in_tiles) * maxf(tile_size.x, tile_size.y)


## Проверяет расстояние от ближайшей точки коллизии игрока
## до ближайшей точки клетки, а не от центра игрока до центра блока.
## Поэтому значение Mining Reach In Tiles работает одинаково
## для блоков сбоку, сверху и снизу.
func _is_cell_in_mining_reach(cell_coordinates: Vector2i) -> bool:
	if terrain == null or terrain.tile_set == null:
		return false

	var reach_pixels: float = _get_mining_reach_pixels()
	if reach_pixels <= 0.0:
		return false

	var tile_size: Vector2 = Vector2(terrain.tile_set.tile_size)
	var block_center: Vector2 = terrain.get_cell_global_center(cell_coordinates)
	var block_rect := Rect2(block_center - tile_size * 0.5, tile_size)
	var player_rect: Rect2 = _get_collision_global_rect(false)

	var closest_point := Vector2(
		clampf(block_center.x, player_rect.position.x, player_rect.end.x),
		clampf(block_center.y, player_rect.position.y, player_rect.end.y)
	)
	var closest_block_point := Vector2(
		clampf(closest_point.x, block_rect.position.x, block_rect.end.x),
		clampf(closest_point.y, block_rect.position.y, block_rect.end.y)
	)

	return closest_point.distance_to(closest_block_point) <= reach_pixels


func _on_pickaxe_hit() -> void:
	if terrain == null or terrain.tile_set == null:
		return

	var target_cells: Array[Vector2i] = _get_attack_mining_cells()
	var checked_cells: int = target_cells.size()
	var damaged_blocks: int = 0

	for target_cell: Vector2i in target_cells:
		if not is_cell_mineable(target_cell):
			continue

		var target_block: BlockType = terrain.get_block_type_at_cell(target_cell)
		if target_block == null:
			continue

		var applied_damage: int = mining_damage
		if destroy_blocks_in_one_hit:
			applied_damage = maxi(1, terrain.get_block_health_at_cell(target_cell))

		var damage_was_applied: bool = terrain.request_damage_block(
			target_cell,
			global_position,
			tool_level,
			applied_damage
		)

		if damage_was_applied:
			damaged_blocks += 1

	print("Удар по области: проверено %d, повреждено %d, дальность %.1f клеток" % [checked_cells, damaged_blocks, mining_reach_in_tiles])


func _on_attack_animation_finished(animation_name: StringName) -> void:
	if not String(animation_name).begins_with("attack_"):
		return
	if not pickaxe_swinging:
		return
	_finish_pickaxe_swing()


func _finish_pickaxe_swing() -> void:
	pickaxe_swinging = false
	_update_facing()
	_update_arm_aim()


func _on_mining_cooldown_timeout() -> void:
	pass


func _get_collision_global_rect(apply_environment_inset: bool = true) -> Rect2:
	if player_collision == null or player_collision.shape == null:
		return Rect2(global_position - Vector2(8.0, 8.0), Vector2(16.0, 16.0))

	var local_rect: Rect2 = player_collision.shape.get_rect()
	var local_corners: PackedVector2Array = [
		local_rect.position,
		Vector2(local_rect.end.x, local_rect.position.y),
		local_rect.end,
		Vector2(local_rect.position.x, local_rect.end.y)
	]

	var first_global_point: Vector2 = player_collision.to_global(local_corners[0])
	var minimum_point: Vector2 = first_global_point
	var maximum_point: Vector2 = first_global_point

	for local_corner: Vector2 in local_corners:
		var global_corner: Vector2 = player_collision.to_global(local_corner)
		minimum_point.x = minf(minimum_point.x, global_corner.x)
		minimum_point.y = minf(minimum_point.y, global_corner.y)
		maximum_point.x = maxf(maximum_point.x, global_corner.x)
		maximum_point.y = maxf(maximum_point.y, global_corner.y)

	var result := Rect2(minimum_point, maximum_point - minimum_point)
	if not apply_environment_inset:
		return result

	var maximum_inset: float = minf(result.size.x, result.size.y) * 0.25
	var applied_inset: float = minf(environment_detection_inset, maximum_inset)
	result.position += Vector2.ONE * applied_inset
	result.size -= Vector2.ONE * applied_inset * 2.0
	return result


func _update_environment_modifiers() -> void:
	environment_movement_multiplier = 1.0
	environment_vertical_multiplier = 1.0
	environment_animation_multiplier = 1.0
	if terrain == null:
		return

	var collision_global_rect: Rect2 = _get_collision_global_rect(true)
	var modifiers: Vector3 = terrain.get_environment_modifiers_in_global_rect(collision_global_rect)
	environment_movement_multiplier = modifiers.x
	environment_vertical_multiplier = modifiers.y
	environment_animation_multiplier = modifiers.z


func spend_stamina(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if is_dead or current_stamina < amount:
		return false

	current_stamina = clampf(current_stamina - amount, 0.0, max_stamina)
	stamina_regeneration_allowed_at = _get_game_time_seconds() + stamina_regeneration_delay
	stamina_changed.emit(current_stamina, max_stamina)
	return true


func _update_stamina(delta: float) -> void:
	if current_stamina >= max_stamina:
		return
	if _get_game_time_seconds() < stamina_regeneration_allowed_at:
		return
	if stamina_regeneration_per_second <= 0.0:
		return

	var previous_stamina: float = current_stamina
	current_stamina = move_toward(current_stamina, max_stamina, stamina_regeneration_per_second * delta)
	if not is_equal_approx(previous_stamina, current_stamina):
		stamina_changed.emit(current_stamina, max_stamina)


func take_damage(amount: int, source_position: Vector2 = Vector2.ZERO) -> void:
	if is_dead or amount <= 0:
		return

	current_health = clampi(current_health - amount, 0, max_health)
	health_changed.emit(current_health, max_health)
	if current_health <= 0:
		_die()


func set_health(value: int) -> void:
	if is_dead:
		return
	current_health = clampi(value, 0, max_health)
	health_changed.emit(current_health, max_health)
	if current_health <= 0:
		_die()


func heal(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	current_health = clampi(current_health + amount, 0, max_health)
	health_changed.emit(current_health, max_health)


func revive() -> void:
	is_dead = false
	current_health = max_health
	current_stamina = max_stamina
	velocity = Vector2.ZERO
	pickaxe_swinging = false
	combo_step = 0
	hazard_damage_allowed_at.clear()
	health_changed.emit(current_health, max_health)
	stamina_changed.emit(current_stamina, max_stamina)


func _die() -> void:
	if is_dead:
		return

	is_dead = true
	pickaxe_swinging = false
	combo_step = 0
	velocity = Vector2.ZERO
	hazard_damage_allowed_at.clear()

	if stop_on_death:
		if mining_cooldown != null:
			mining_cooldown.stop()
		if attack_player != null:
			attack_player.stop()
		if locomotion_player != null:
			locomotion_player.stop()

	died.emit()


func _update_hazard_damage(_delta: float) -> void:
	if is_dead or terrain == null or terrain.tile_set == null:
		return

	var contact_rect: Rect2 = _get_collision_global_rect(false).grow(hazard_contact_margin)
	var tile_size: Vector2 = Vector2(terrain.tile_set.tile_size)
	if tile_size.x <= 0.0 or tile_size.y <= 0.0:
		return

	var top_left_cell: Vector2i = terrain.global_position_to_cell(contact_rect.position)
	var bottom_right_cell: Vector2i = terrain.global_position_to_cell(contact_rect.end - Vector2.ONE)
	var now: float = _get_game_time_seconds()
	var overlapping_hazards: Dictionary = {}

	for cell_y: int in range(top_left_cell.y, bottom_right_cell.y + 1):
		for cell_x: int in range(top_left_cell.x, bottom_right_cell.x + 1):
			var cell: Vector2i = Vector2i(cell_x, cell_y)
			var block_type: BlockType = terrain.get_block_type_at_cell(cell)
			if block_type == null:
				continue

			var hazard_data: Dictionary = _get_hazard_data(block_type)
			if not bool(hazard_data.get("is_hazard", false)):
				continue

			var damage: int = int(hazard_data.get("contact_damage", default_hazard_contact_damage))
			if damage <= 0:
				continue

			var interval: float = maxf(0.05, float(hazard_data.get("contact_damage_interval", default_hazard_contact_interval)))
			overlapping_hazards[cell] = true
			var next_damage_time: float = float(hazard_damage_allowed_at.get(cell, 0.0))
			if now < next_damage_time:
				continue

			take_damage(damage, terrain.get_cell_global_center(cell))
			hazard_damage_allowed_at[cell] = now + interval
			if is_dead:
				return

	var cells_to_remove: Array[Vector2i] = []
	for stored_cell: Vector2i in hazard_damage_allowed_at.keys():
		if not overlapping_hazards.has(stored_cell):
			cells_to_remove.append(stored_cell)
	for stored_cell: Vector2i in cells_to_remove:
		hazard_damage_allowed_at.erase(stored_cell)


func _get_hazard_data(block_type: BlockType) -> Dictionary:
	var contact_damage_value: Variant = block_type.get("contact_damage")
	var contact_interval_value: Variant = block_type.get("contact_damage_interval")
	var is_hazard_value: Variant = block_type.get("is_hazard")
	var block_id_value: Variant = block_type.get("block_id")
	var configured_damage: int = 0

	if contact_damage_value != null:
		configured_damage = int(contact_damage_value)

	var has_damage: bool = configured_damage > 0
	var normalized_block_id: String = ""
	if block_id_value != null:
		normalized_block_id = String(block_id_value).strip_edges().to_lower()

	var is_spike_block: bool = normalized_block_id == "spike" or normalized_block_id == "spikes" or normalized_block_id.contains("spike")
	var block_is_hazard: bool = is_hazard_value == true or has_damage or is_spike_block
	var resulting_damage: int = configured_damage
	if resulting_damage <= 0 and block_is_hazard:
		resulting_damage = default_hazard_contact_damage

	var resulting_interval: float = default_hazard_contact_interval
	if contact_interval_value != null:
		resulting_interval = maxf(0.05, float(contact_interval_value))

	return {
		"is_hazard": block_is_hazard,
		"contact_damage": resulting_damage,
		"contact_damage_interval": resulting_interval
	}


func _get_game_time_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0


## Создаёт инвентарь и регистрирует ItemData из Item Catalog.
func _initialize_inventory() -> void:
	ItemRegistry.register_items(item_catalog)
	inventory = InventoryData.new()
	inventory.slot_count = inventory_slot_count
	inventory.max_weight_kg = inventory_max_weight_kg
	inventory.setup()


## Вызывается предметом на земле. Возвращает реально принятое количество.
func receive_item(item_id: StringName, amount: int) -> int:
	if inventory == null or amount <= 0:
		return 0
	var accepted: int = inventory.add_item(item_id, amount)
	if accepted < amount:
		print("Не удалось подобрать всё: %s × %d. Нет места или превышен вес." % [item_id, amount - accepted])
	return accepted


func get_inventory_weight_kg() -> float:
	return inventory.get_total_weight_kg() if inventory != null else 0.0


func open_chest(chest: ChestContainer) -> void:
	opened_chest = chest
	print("Открыт сундук.")


func close_chest() -> void:
	opened_chest = null


func transfer_player_slot_to_opened_chest(slot_index: int, amount: int) -> int:
	if inventory == null or opened_chest == null or opened_chest.inventory == null:
		return 0
	return InventoryData.transfer_slot_to(inventory, opened_chest.inventory, slot_index, amount)


func transfer_opened_chest_slot_to_player(slot_index: int, amount: int) -> int:
	if inventory == null or opened_chest == null or opened_chest.inventory == null:
		return 0
	return InventoryData.transfer_slot_to(opened_chest.inventory, inventory, slot_index, amount)
