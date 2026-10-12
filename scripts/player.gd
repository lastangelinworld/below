extends CharacterBody2D


signal health_changed(current_health: int, maximum_health: int)
signal stamina_changed(current_stamina: float, maximum_stamina: float)
signal died
signal item_picked_up(item_id: StringName, amount: int)


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


@export_group("Stance")

## Во сколько раз спринт быстрее обычной скорости.
@export_range(1.0, 3.0, 0.05)
var sprint_multiplier: float = 1.45

## Во сколько раз бег быстрее обычной ходьбы.
@export_range(1.0, 3.0, 0.05)
var run_multiplier: float = 1.2

## Сколько секунд нужно идти в одном направлении,
## чтобы шаг перешёл на бег.
@export_range(0.0, 10.0, 0.1)
var run_hold_threshold: float = 1.2

## Во сколько раз медленнее ходьба в приседе.
@export_range(0.1, 1.0, 0.05)
var crouch_speed_multiplier: float = 0.45

## Выносливость, сгорающая в секунду во время спринта.
@export_range(0.0, 100.0, 0.5)
var sprint_stamina_per_second: float = 14.0

## Доля урона, которую персонаж всё получает во время блока.
## 0.3 — щит гасит 70% удара.
@export_range(0.0, 1.0, 0.05)
var blocked_damage_ratio: float = 0.3

## Множитель скорости во время блока.
@export_range(0.1, 1.0, 0.05)
var block_speed_multiplier: float = 0.35

## Расход выносливости за успешное парирование.
@export_range(0.0, 50.0, 0.5)
var parry_stamina_cost: float = 5.0

## Длительность стаггера атакующего при парировании (секунды).
@export_range(0.0, 5.0, 0.1)
var parry_stagger_sec: float = 1.2

## Расход выносливости за единицу блокируемого урона.
@export_range(0.0, 10.0, 0.1)
var block_stamina_per_damage: float = 1.0

## Во сколько раз дороже блокировать тяжёлый удар (Фаза 7),
## помеченный в Hitbox как breaks_block: 3.0 — щит под таким
## ударом держится недолго, и игрок учится уходить роллом.
@export_range(1.0, 8.0, 0.5)
var heavy_block_stamina_multiplier: float = 3.0

## Высота capsule-коллизии в приседе. Чуть меньше клетки (32 px),
## чтобы персонаж пролезал в проходы высотой в один блок.
@export_range(8.0, 128.0, 1.0)
var crouch_collision_height: float = 30.0

## Смещение capsule-коллизии вниз в приседе, чтобы ноги
## остались на полу при уменьшении высоты.
@export_range(-64.0, 64.0, 0.5)
var crouch_collision_offset_y: float = 0.0


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

## Параметры Dodge-roll: импульс, длительность, окно неуязвимости, цена стамины.
@export var dodge_impulse: float = 300.0
@export var dodge_duration: float = 0.5
@export var dodge_iframe_start: float = 0.1
@export var dodge_iframe_end: float = 0.35
@export var dodge_stamina_cost: float = 15.0


@export_group("Poise")

## Запас устойчивости персонажа. Когда иссякает — он замирает
## в стаггере и открыт для казни (×1.5 урона).
@export_range(5, 500, 1) var max_poise: float = 60.0

## Длительность стаггера персонажа в секундах.
@export_range(0.3, 5.0, 0.1) var poise_stagger_duration: float = 0.9

## Скорость восстановления равновесия (единиц в секунду).
@export_range(0.0, 50.0, 0.5) var poise_regen_per_second: float = 24.0

## Задержка покоя перед восстановлением равновесия (секунды).
@export_range(0.0, 5.0, 0.1) var poise_recovery_delay: float = 1.2


@export_group("Encumbrance")

## Грузоподъёмность снаряжения в килограммах: вес надетой брони
## делится на это значение, и получается доля нагрузки. Растёт
## вместе с навыком силы (Фаза 6).
@export_range(1.0, 999.0, 0.5) var equip_load_capacity_kg: float = 12.0

## Насколько полная нагрузка (encumbrance = 1.0) гасит скорость:
## 0.4 — шаг падает до 60%. Значения выше планки не идут.
@export_range(0.0, 1.0, 0.05) var encumbrance_speed_penalty: float = 0.4

## Насколько полная нагрузка гасит восстановление выносливости:
## 0.5 — реген падает до половины.
@export_range(0.0, 1.0, 0.05) var encumbrance_regen_penalty: float = 0.5


@export_group("Skills")

## Опыт за реальное попадание оружием по врагу (в навык этого оружия).
@export_range(0.0, 100.0, 0.5) var hit_skill_xp: float = 4.0

## Опыт за успешное парирование (в «Блок»).
@export_range(0.0, 100.0, 0.5) var parry_skill_xp: float = 6.0

## Опыт за поглощённый блоком удар (в «Блок»).
@export_range(0.0, 100.0, 0.5) var block_skill_xp: float = 2.0

## Опыт за начатый ролл (в «Уклонение»).
@export_range(0.0, 100.0, 0.5) var dodge_skill_xp: float = 3.0

## Опыт за секунду спринта (в «Бег»), выдаётся накоплением.
@export_range(0.0, 10.0, 0.1) var run_skill_xp_per_second: float = 1.0


@export_group("Hazard Contact")

## Дополнительный отступ наружу при поиске опасных блоков.
@export_range(0.0, 16.0, 0.5)
var hazard_contact_margin: float = 0.0

## Какая часть клетки опасна, считая снизу.
## 1.0 — вся клетка, 0.5 — только нижняя половина, где сами шипы.
@export_range(0.1, 1.0, 0.05)
var hazard_cell_fill_ratio: float = 0.5

## Насколько глубоко нужно задеть шипы, чтобы получить урон.
@export_range(0.0, 16.0, 0.5)
var hazard_minimum_overlap: float = 4.0

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

## Поиз-урон удара текущим оружием. Базовое значение 0: реальную
## величину даёт экипированное оружие через EquipmentSystem.
@export_range(0.0, 100.0, 0.5)
var poise_damage: float = 0.0

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
	"Visuals/BodyBreath/NeckPivot/HeadBreath"
) as Node2D
@onready var front_arm_aim: Node2D = $Visuals/BodyBreath/FrontArmAim
@onready var locomotion_player: AnimationPlayer = $LocomotionPlayer
@onready var attack_player: AnimationPlayer = $AttackPlayer
@onready var secondary_motion_player: AnimationPlayer = (
	$Visuals/SecondaryMotionPlayer
)
@onready var mining_cooldown: Timer = $MiningCooldown
@onready var weapon_hitbox: Hitbox = get_node_or_null(
	"Visuals/BodyBreath/FrontArmAim/FrontArmAttack/FrontElbow/FrontWrist/HandSocket/Pickaxe/Hitbox"
) as Hitbox
@onready var held_weapon_sprite: Sprite2D = get_node_or_null(
	"Visuals/BodyBreath/FrontArmAim/FrontArmAttack/FrontElbow/FrontWrist/HandSocket/Pickaxe/PickaxeSprite"
) as Sprite2D
@onready var shield_sprite: Sprite2D = get_node_or_null(
	"Visuals/BodyBreath/BackShoulder/BackElbow/BackWrist/ShieldSocket/ShieldSprite"
) as Sprite2D


## Стандартная гравитация проекта.
var gravity: float = float(
	ProjectSettings.get_setting(
		"physics/2d/default_gravity",
		980.0
	)
)

var current_health: int = 100

## Машина состояний игрока: единый источник правды о боевых состояниях.
var _player_state: PlayerStateMachine = PlayerStateMachine.new()

## Выносливость: единственный владелец запаса и математики — StaminaComponent.
var _stamina_component: StaminaComponent = StaminaComponent.new()

## Публичный доступ к запасу: делегирует компоненту, чтобы существующие
## читатели (спринт, revive, внешние системы) продолжали работать как раньше.
var current_stamina: float:
	get:
		return _stamina_component.current
	set(value):
		_stamina_component.current = clampf(
			value, 0.0, _stamina_component.max_stamina
		)
var is_dead: bool = false
## Точка появления, в неё возвращаем персонажа после смерти.
var _spawn_position: Vector2 = Vector2.ZERO
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

## Персонаж идёт в приседе: ниже коллизия, медленнее шаг.
var is_crouching: bool = false

## Персонаж держит блок: урон сильно снижен, шаг почти стоп.
## Блок активен всё время, пока удерживается ПКМ (как в Valheim).
var is_blocking: bool = false

## Момент включения блока: от него отсчитывается окно парирования.
var block_started_at: float = 0.0

## Состояние Dodge-roll: активный ролл, отсчёт времени, направление и i-frames.
var is_rolling: bool = false
var is_invulnerable: bool = false
var _dodge_elapsed: float = 0.0
var roll_direction: float = 1.0
## Скорость «дыхания» спрайтов во время ролла.
var dodge_breath_speed: float = 2.0

## Бег без расхода выносливости (зажатый Shift при обычной скорости).
var is_sprinting: bool = false

## Исходные размеры и положение capsule-коллизии, чтобы
## вернуться в стойку после приседания.
var standing_collision_height: float = 60.0
var standing_collision_position: Vector2 = Vector2.ZERO

## Сколько секунд подряд персонаж идёт в одном направлении.
## После run_hold_threshold ходьба переходит на бег.
var movement_hold_time: float = 0.0

## Пока открыт инвентарь, на AttackPlayer крутится inventory_loop.
var inventory_loop_playing: bool = false

## Кэш узла интерфейса инвентаря (группа "inventory_ui").
var inventory_ui_node: Node = null

## Исходный угол BodyBreath.
var body_breath_base_rotation: float = 0.0

## Исходный угол головы, если узел HeadBreath существует.
var head_breath_base_rotation: float = 0.0

## Текущие сглаженные углы наклона.
var current_body_lean: float = 0.0
var current_head_lean: float = 0.0

## Инвентарь создаётся автоматически в _ready().
var inventory: InventoryData

## Экипировка (Фаза 2) создаётся автоматически в _ready().
var equipment: EquipmentSystem

## Поиз-компонент (Фаза 4).
var poise: PoiseComponent

## Нагрузка надетой брони (Фаза 5): доля от грузоподъёмности.
## 0.0 — броня не давит, 1.0 и выше — «неподъёмная» броня.
## Заполняет EquipmentSystem при каждом пересчёте экипировки.
var encumbrance: float = 0.0

## Множитель скорости шага из нагрузки (1.0 без брони).
var encumbrance_speed_multiplier: float = 1.0

## Множитель скорости восстановления стамины из нагрузки.
var encumbrance_regen_multiplier: float = 1.0

## Броня весит столько, что остаются только шаг и удар:
## спринт, бег и ролл запрещены.
var is_overencumbered: bool = false

## Навыки оружия и боя (Фаза 6).
var skills: SkillsComponent


func _ready() -> void:
	add_to_group("player")
	_spawn_position = global_position
	_initialize_inventory()
	_initialize_equipment()
	visuals_base_scale_x = absf(visuals.scale.x)
	body_breath_base_rotation = body_breath.rotation

	if player_collision != null and player_collision.shape is CapsuleShape2D:
		standing_collision_height = (player_collision.shape as CapsuleShape2D).height
		standing_collision_position = player_collision.position

	if head_breath != null:
		head_breath_base_rotation = head_breath.rotation

	current_health = maxi(1, max_health)
	_setup_stamina_component()

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

	# Подключение к сигналам экипировки для обновления визуала.
	# Кэш снимаем до первой перерисовки: иначе за эталон возьмётся
	# уже изменённый текстурой спрайт.
	if equipment != null:
		_cache_default_held_visuals()
		if not equipment.equipment_changed.is_connected(_on_equipment_changed):
			equipment.equipment_changed.connect(_on_equipment_changed)
		_update_held_weapon_visuals()


## Настраивает компонент выносливости: источник времени, флаг смерти, параметры.
func _setup_stamina_component() -> void:
	_stamina_component.name = &"StaminaComponent"
	add_child(_stamina_component)
	_stamina_component.time_source = _get_game_time_seconds
	_stamina_component.is_dead_provider = func() -> bool: return is_dead
	_stamina_component.configure(
		max_stamina, stamina_regeneration_per_second, stamina_regeneration_delay
	)
	_stamina_component.restore_full()

	_player_state.name = &"PlayerStateMachine"
	add_child(_player_state)
	_player_state.state_changed.connect(_on_player_state_changed)

	_setup_poise_component()
	_setup_skills_component()
	# Экипировка инициализировалась раньше стамины и уже посчитала
	# нагрузку — переносим её в компонент.
	_apply_encumbrance_to_stamina()


## Нагрузка брони меняет скорость восстановления выносливости.
func _apply_encumbrance_to_stamina() -> void:
	_stamina_component.encumbrance_multiplier = clampf(
		encumbrance_regen_multiplier, 0.0, 1.0
	)


## Настраивает компонент поиза: источник времени, флаг смерти, параметры.
func _setup_poise_component() -> void:
	poise = PoiseComponent.new()
	poise.name = &"PoiseComponent"
	add_child(poise)
	poise.is_dead_provider = func() -> bool: return is_dead
	poise.configure(_get_game_time_seconds)
	poise.max_poise = max_poise
	poise.stagger_duration = poise_stagger_duration
	poise.poise_regen_per_second = poise_regen_per_second
	poise.recovery_delay = poise_recovery_delay
	poise.restore_full()
	poise.stagger_started.connect(_on_poise_stagger_started)


## Навыки оружия и боя (Фаза 6).
func _setup_skills_component() -> void:
	skills = SkillsComponent.new()
	skills.name = &"SkillsComponent"
	add_child(skills)
	skills.setup(self)
	skills.level_changed.connect(_on_skill_level_up)

	# Опыт за удар начисляется только за реальное касание врага:
	# махать киркой вхолостую — не тренировка.
	if weapon_hitbox != null and not weapon_hitbox.hit_landed.is_connected(_on_weapon_hit_landed):
		weapon_hitbox.hit_landed.connect(_on_weapon_hit_landed)


## Оружие достало цель: тренируем навык, закреплённый за экипированным
## предметом. Броня и незарегистрированные предметы опыт не дают.
func _on_weapon_hit_landed(_target: Node) -> void:
	var component: EquipmentComponent = _mainhand_component()
	if component == null or not component.trains_skill:
		return
	skills.add_xp(component.weapon_skill, hit_skill_xp)


## EquipmentComponent предмета в основной руке (или null).
func _mainhand_component() -> EquipmentComponent:
	if equipment == null:
		return null
	var stack: ItemStack = equipment.get_equipped_stack(EquipmentSlot.Type.MAINHAND)
	if stack == null or stack.is_empty():
		return null
	var item: ItemData = ItemRegistry.get_item(stack.item_id)
	return item as EquipmentComponent


## Навык поднял уровень: показываем уведомление в HUD.
func _on_skill_level_up(skill: int, new_level: int) -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud == null:
		return
	if hud.has_method("show_skill_level_up"):
		hud.call("show_skill_level_up", skill, new_level)


## Равновесие иссякло: персонаж теряет стойку. Анимационно-боевая
## машина состояний переводит его в STAGGER — переход запрещает
## удар, прыжок и ролл, пока poise.tick() не вернёт его в IDLE.
func _on_poise_stagger_started(_duration: float) -> void:
	_player_state.force_change(PlayerStateMachine.State.STAGGER)


## Состояние сменилось: скорость регена стамины зависит от боя.
func _on_player_state_changed(
	_previous: PlayerStateMachine.State,
	_current: PlayerStateMachine.State
) -> void:
	_stamina_component.regeneration_multiplier = _player_state.regen_modifier()


func _physics_process(delta: float) -> void:
	if is_dead and stop_on_death:
		_update_stamina(delta)
		return

	_update_environment_modifiers()
	_update_stance(delta)
	_apply_gravity(delta)
	_handle_jump()
	_handle_dodge(delta)
	_handle_horizontal_movement(delta)

	move_and_slide()

	_update_stamina(delta)
	_update_poise(delta)
	_update_hazard_damage(delta)
	_update_locomotion_animation()
	_update_secondary_motion(delta)


func _process(delta: float) -> void:
	if is_dead and stop_on_death:
		return

	_update_inventory_animation()
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
	# В стаггере персонаж теряет равновесие и не может прыгать.
	if poise.is_staggered():
		return
	# Прыжок из приседа возможен только в полный рост:
	# если встать некуда — прыжка не будет.
	if not try_stand_up_for_action():
		return
	if not spend_stamina(jump_stamina_cost):
		return
	velocity.y = jump_velocity * environment_vertical_multiplier


## Определяет текущую стойку: блок, присед или бег/спринт,
## и сжигает выносливость во время спринта.
func _update_stance(delta: float) -> void:
	var crouch_input: bool = (
		InputMap.has_action(&"crouch")
		and Input.is_action_pressed(&"crouch")
	)

	# Блок держится ровно столько, сколько удерживается ПКМ:
	# отпустил кнопку — стойка снимается.
	# Присед и блок несовместимы: зажатый C снимает блок,
	# а из «прилипанного» приседа ПКМ сначала пытается поднять
	# персонажа, и только если встать удалось — поднимает щит.
	var blocking_input: bool = (
		InputMap.has_action(&"block")
		and Input.is_action_pressed(&"block")
		and is_on_floor()
		and _has_shield_equipped()
		and not crouch_input
		and not poise.is_staggered()
		and try_stand_up_for_action()
	)

	# Атака прерывает блок: пока зажат ЛКМ или идёт замах,
	# щит опущен, даже если ПКМ всё ещё удерживается.
	# Как только ЛКМ отпустят, блок сразу возобновится.
	if blocking_input and (
		pickaxe_swinging
		or (InputMap.has_action(&"primary_action") and Input.is_action_pressed(&"primary_action"))
	):
		blocking_input = false

	if blocking_input != is_blocking:
		is_blocking = blocking_input
		if is_blocking:
			# Окно парирования стартует в момент включения блока.
			block_started_at = _get_game_time_seconds()
			_player_state.change_to(PlayerStateMachine.State.BLOCK)
		elif not poise.is_staggered():
			# Стаггер перехватывает стойку: возвращать IDLE нельзя,
			# иначе сбивится состояние оглушения и его нулевой реген.
			_player_state.change_to(PlayerStateMachine.State.IDLE)
		_update_block_animation()

	_set_crouching(crouch_input)

	var direction: float = Input.get_axis(&"move_left", &"move_right")
	var moving: bool = not is_crouching and not is_blocking and absf(direction) > 0.01
	if moving:
		movement_hold_time += delta
	else:
		movement_hold_time = 0.0

	var sprint_input: bool = (
		InputMap.has_action(&"sprint")
		and Input.is_action_pressed(&"sprint")
	)
	# Неподъёмная броня отбирает бег: остаётся только шаг.
	is_sprinting = (
		moving and sprint_input and not is_overencumbered and current_stamina > 0.0
	)

	if is_sprinting:
		# Спринт тратит выносливость непрерывно и не даёт ей
		# восстанавливаться, пока кнопка удерживается.
		if _stamina_component.drain(sprint_stamina_per_second * delta) > 0.0:
			stamina_changed.emit(current_stamina, max_stamina)
		# Бег тренируется временем в спринте, а не числом действий.
		if skills != null:
			skills.add_xp(SkillsComponent.Skill.RUN, run_skill_xp_per_second * delta)


## Возвращает множитель горизонтальной скорости для текущей стойки.
func _stance_speed_multiplier() -> float:
	if is_blocking:
		return block_speed_multiplier
	if is_crouching:
		return crouch_speed_multiplier
	if is_sprinting:
		# Навык «Бег» поднимает потолок спринта.
		if skills == null:
			return sprint_multiplier
		return sprint_multiplier * skills.sprint_speed_multiplier(
			SkillsComponent.Skill.RUN
		)
	if movement_hold_time >= run_hold_threshold and not is_overencumbered:
		return run_multiplier
	return 1.0


## Меняет capsule-коллизии на приседную или обычную.
func _set_crouching(should_crouch: bool) -> void:
	if should_crouch == is_crouching:
		return

	if player_collision == null or not (player_collision.shape is CapsuleShape2D):
		return

	# «Прилипающий» присед: пока стоячая капсула пересекается
	# с блоками над головой, персонаж остаётся пригнутым.
	# _update_stance вызывает эту проверку каждый физический
	# кадр, поэтому вставание произойдёт само, стоит освобо-
	# дить место (например, сломать блок над головой).
	if not should_crouch and not _can_stand_up():
		return

	is_crouching = should_crouch
	var capsule: CapsuleShape2D = player_collision.shape

	if is_crouching:
		capsule.height = minf(crouch_collision_height, standing_collision_height)
		# Компенсируем половину потерянной высоты, чтобы ноги
		# остались на прежнем уровне.
		var lost_height: float = standing_collision_height - capsule.height
		player_collision.position = (
			standing_collision_position + Vector2(0.0, lost_height * 0.5 - crouch_collision_offset_y)
		)
	else:
		capsule.height = standing_collision_height
		player_collision.position = standing_collision_position


## Проверяет, есть ли достаточно свободного места для стоячей
## capsule-коллизии: строит тестовую капсулу там, где она окажется
## после вставания, и ищет её пересечения с блоками мира.
func _can_stand_up() -> bool:
	if player_collision == null or not player_collision.is_inside_tree():
		return true

	var world: World2D = get_world_2d()
	if world == null:
		return true

	var current_capsule: CapsuleShape2D = player_collision.shape as CapsuleShape2D
	if current_capsule == null:
		return true

	var body: PhysicsBody2D = player_collision.get_parent() as PhysicsBody2D
	if body == null:
		return true

	var standing_capsule := CapsuleShape2D.new()
	standing_capsule.radius = current_capsule.radius
	standing_capsule.height = standing_collision_height

	var shape_query := PhysicsShapeQueryParameters2D.new()
	shape_query.shape = standing_capsule
	# Центр стоячей капсулы в мировых координатах: при вставании
	# коллизия вернётся на standing_collision_position относительно
	# тела, поэтому считаем от тела, а не от самой коллизии — иначе
	# текущий приседный сдвиг сложился бы с компенсацией дважды.
	shape_query.transform = Transform2D(
		0.0,
		body.to_global(standing_collision_position)
	)
	# Слой 1 — тайлмап мира. Из запроса исключаем тело персонажа
	# (exclude принимает Rid физическиx тел, а не узлы коллизии),
	# иначе тестовая капсула задевала бы капсулу приседа и встать
	# было бы нельзя никогда.
	shape_query.collision_mask = body.collision_mask
	shape_query.exclude = [body.get_rid()]
	shape_query.collide_with_bodies = true
	shape_query.collide_with_areas = false

	var overlaps: Array = world.direct_space_state.intersect_shape(shape_query, 4)
	return overlaps.is_empty()


## Шлюз для всех действий (атака, блок, прыжок, взаимодействие):
## в приседе действия запрещены. Персонаж пытается встать и, если
## место позволяет, действие разрешается в этом же кадре. Пока
## зажата кнопка приседа или встать некуда — действие не выходит.
## Возвращает true, если действие можно выполнять стоя.
func try_stand_up_for_action() -> bool:
	if not is_crouching:
		return true
	if (
		InputMap.has_action(&"crouch")
		and Input.is_action_pressed(&"crouch")
	):
		return false
	_set_crouching(false)
	return not is_crouching


func _has_shield_equipped() -> bool:
	if equipment == null:
		return false
	var stack: ItemStack = equipment.get_equipped_stack(EquipmentSlot.Type.OFFHAND)
	return stack != null and not stack.is_empty()


## Возвращает true, если щит «смотрит» в сторону атаки.
## Проверяет, что источник урона лежит в передней полусфере
## относительно направления взгляда (facing).
func _shield_faces(source_position: Vector2) -> bool:
	var to_source: Vector2 = source_position - global_position
	# facing = 1 → смотрит вправо, -1 → влево.
	# Скалярное произведение > 0 означает «попадание в полусферу».
	return signf(to_source.x) == facing


## Включает или снимает позу блока на AttackPlayer.
## Анимация block короткая и нециклическая: её последний кадр
## удерживает поднятый щит, пока кнопка зажата.
func _update_block_animation() -> void:
	if inventory_loop_playing:
		# Инвентарь перекрыл блок: позу не трогаем, но при снятии
		# блока треки рук нужно вернуть, иначе ходьба останется
		# без раскачивания плеча после закрытия окна.
		if not is_blocking:
			_set_locomotion_arm_tracks_enabled(true)
		return

	if is_blocking:
		pickaxe_swinging = false
		_set_locomotion_arm_tracks_enabled(false)
		if attack_player.has_animation(&"block"):
			attack_player.stop()
			attack_player.play(&"block")
	else:
		_set_locomotion_arm_tracks_enabled(true)
		# Сняли блок: принудительно возвращаем руки в базовую позу.
		# Проверять current_animation нельзя — нециклическая block
		# уже могла завершиться, и её имя потерялось после stop().
		# Если сейчас идёт замах атаки — руки уже заняты ударом,
		# прерывать его нельзя (блок возобновится после атаки).
		if pickaxe_swinging:
			return
		attack_player.stop()
		if attack_player.has_animation(&"RESET"):
			attack_player.play(&"RESET")


## Отключает на всех локомоционных анимациях треки рук (BackShoulder),
## чтобы раскачивание плеча при ходьбе не спорило с позой блока:
## пока щит поднят, двигаются только ноги и корпус.
func _set_locomotion_arm_tracks_enabled(should_enable: bool) -> void:
	for animation_name: StringName in locomotion_player.get_animation_list():
		var animation: Animation = locomotion_player.get_animation(animation_name)
		if animation == null:
			continue
		for track_index: int in animation.get_track_count():
			var track_path: NodePath = animation.track_get_path(track_index)
			if not String(track_path).contains("BackShoulder"):
				continue
			animation.track_set_enabled(track_index, should_enable)


func _is_dual_hand_equipped() -> bool:
	if equipment == null:
		return false
	return bool(equipment.get_totals().get("dual_hand_equipped", false))


## Пока окно инвентаря открыто, на AttackPlayer крутится
## inventory_loop; после закрытия возвращаем обычную стойку.
func _update_inventory_animation() -> void:
	if inventory_ui_node == null or not is_instance_valid(inventory_ui_node):
		inventory_ui_node = get_tree().get_first_node_in_group("inventory_ui")
		if inventory_ui_node == null:
			if inventory_loop_playing:
				inventory_loop_playing = false
				attack_player.stop()
				secondary_motion_player.play(&"life_loop")
				_finish_pickaxe_swing()
			return

	var open_now: bool = false
	if inventory_ui_node.has_method("is_inventory_open"):
		open_now = bool(inventory_ui_node.call("is_inventory_open"))

	if open_now == inventory_loop_playing:
		return

	inventory_loop_playing = open_now
	if inventory_loop_playing:
		pickaxe_swinging = false
		if attack_player.has_animation(&"inventory_loop"):
			attack_player.stop()
			attack_player.play(&"inventory_loop")
	else:
		# inventory_loop — луп, его последний кадр не возвращает
		# в базовую позу, поэтому принудительно сбрасываем треки.
		# Инвентарь перекрывал блок: возвращаем позу щита,
		# если ПКМ всё ещё зажат.
		if is_blocking:
			_update_block_animation()
			_finish_pickaxe_swing()
			return
		attack_player.stop()
		if attack_player.has_animation(&"RESET"):
			attack_player.play(&"RESET")
		_finish_pickaxe_swing()


## Обрабатывает Dodge-roll: продвигает таймер/i-frames или стартует ролл.
func _handle_dodge(delta: float) -> void:
	if is_rolling:
		_dodge_elapsed += delta
		is_invulnerable = (
			_dodge_elapsed >= dodge_iframe_start
			and _dodge_elapsed <= dodge_iframe_end
		)
		if _dodge_elapsed >= dodge_duration:
			_end_dodge()
		return

	if is_dead or pickaxe_swinging:
		return
	# Неподъёмная броня: свернуться в ролл персонаж не может.
	if is_overencumbered:
		return
	# Из стаггера нельзя уйти в ролл: персонаж ещё не оправился.
	if poise.is_staggered():
		return
	if not Input.is_action_just_pressed(&"dodge"):
		return
	if not _player_state.can_change_to(PlayerStateMachine.State.DODGE):
		return
	if not spend_stamina(_dodge_stamina_cost()):
		return

	_start_dodge()
	if skills != null:
		skills.add_xp(SkillsComponent.Skill.DODGE, dodge_skill_xp)


## Стоимость ролла с учётом навыка «Уклонение».
func _dodge_stamina_cost() -> float:
	if skills == null:
		return dodge_stamina_cost
	return dodge_stamina_cost * skills.dodge_cost_multiplier(SkillsComponent.Skill.DODGE)


## Запускает ролл: импульс, окно i-frames, наклон и затемнение спрайтов.
## Навык «Уклонение» увеличивает дальность и снижает стоимость.
func _start_dodge() -> void:
	is_rolling = true
	_dodge_elapsed = 0.0
	is_invulnerable = false

	var direction: float = Input.get_axis(&"move_left", &"move_right")
	roll_direction = direction if not is_zero_approx(direction) else float(facing)

	var range_mult: float = 1.0
	if skills != null:
		range_mult = skills.dodge_range_multiplier(SkillsComponent.Skill.DODGE)

	velocity.x = roll_direction * dodge_impulse * range_mult

	_player_state.force_change(PlayerStateMachine.State.DODGE)

	# Визуал: наклон и лёгкое затемнение спрайта на время ролла.
	visuals.rotation = -roll_direction * 0.25
	visuals.modulate = Color(0.8, 0.8, 0.85)
	secondary_motion_player.speed_scale = dodge_breath_speed


## Завершает ролл: снимает i-frames и возвращает спрайты в норму.
func _end_dodge() -> void:
	is_rolling = false
	is_invulnerable = false
	visuals.rotation = 0.0
	visuals.modulate = Color(1, 1, 1)
	secondary_motion_player.speed_scale = current_breath_speed
	if _player_state.current == PlayerStateMachine.State.DODGE:
		_player_state.force_change(PlayerStateMachine.State.IDLE)


func _handle_horizontal_movement(delta: float) -> void:
	# Во время ролла горизонталь задаёт импульс, а не ввод игрока.
	if is_rolling:
		velocity.x = move_toward(velocity.x, 0.0, dodge_impulse * 2.0 * delta)
		return

	var direction: float = Input.get_axis(&"move_left", &"move_right")
	var effective_move_speed: float = (
		move_speed
		* _stance_speed_multiplier()
		* environment_movement_multiplier
	)
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
	# В воздухе играется одноразовый jump: последний кадр
	# (поджатые ноги) удерживается до приземления.
	if not is_on_floor():
		locomotion_player.speed_scale = 1.0
		_play_locomotion_animation(&"jump")
		return

	var moving_on_floor: bool = is_on_floor() and absf(velocity.x) > walk_animation_threshold

	if not moving_on_floor:
		locomotion_player.speed_scale = 1.0
		_play_locomotion_animation(&"crouch" if is_crouching else &"idle")
		return

	# Шаг назад: движение против направления взгляда.
	var moving_backwards: bool = signf(velocity.x) * float(facing) < 0.0

	var animation_name: StringName = &"walk"
	if is_crouching:
		animation_name = &"crouch_walk"
	elif moving_backwards:
		animation_name = &"walk_back"
	elif is_sprinting:
		animation_name = &"sprint"
	elif movement_hold_time >= run_hold_threshold and not is_overencumbered:
		animation_name = &"run"

	# Целевая скорость стойки — нормировка speed_scale,
	# чтобы цикл шага совпадал с реальной скоростью персонажа.
	var effective_move_speed: float = (
		move_speed
		* _stance_speed_multiplier()
		* environment_movement_multiplier
	)
	var speed_ratio: float = absf(velocity.x) / maxf(effective_move_speed, 1.0)
	locomotion_player.speed_scale = clampf(speed_ratio, 0.35, 1.5) * environment_animation_multiplier
	_play_locomotion_animation(animation_name)


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
	if inventory_loop_playing:
		return
	# Стаггер глушит атаку: удар можно начать только после
	# восстановления равновесия.
	if poise.is_staggered():
		return

	if Input.is_action_just_pressed(&"primary_action"):
		combo_step = 0
	if not Input.is_action_pressed(&"primary_action"):
		return
	if pickaxe_swinging:
		return
	if not mining_cooldown.is_stopped():
		return
	# В приседе не бьём: персонаж сначала пытается встать.
	# Если кнопка приседа всё ещё зажата или встать некуда
	# (низкий блок над головой) — удар не начнётся.
	if not try_stand_up_for_action():
		return
	# Атака возможна и с зажатым ПКМ: блок отпускается
	# только на время замаха (см. _start_next_combo_attack).
	_start_next_combo_attack()


func _start_next_combo_attack() -> void:
	if pickaxe_swinging or not mining_cooldown.is_stopped():
		return
	if not spend_stamina(attack_stamina_cost):
		return

	combo_step += 1
	if combo_step > 3:
		combo_step = 1

	var base_name: String = &"attack" if not _is_dual_hand_equipped() else &"two_handed"
	var animation_name: StringName = StringName("%s_%d" % [base_name, combo_step])
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
	# Активируем хитбокс оружия на короткое окно удара:
	# форма кирки в этот момент пересекает цель — хитбокс
	# сам находит Hurtbox врага и наносит урон через receive_hit().
	if weapon_hitbox != null:
		weapon_hitbox.source_owner = self
		# Урон растёт с уровнем навыка экипированного оружия:
		# базовое значение × (1 + уровень × 0.04).
		weapon_hitbox.damage = _skill_scaled_weapon_damage()
		# 0 означает «не задано»: Hurtbox тогда возьмёт поиз, равный
		# финальному урону. Экипированное оружие выставляет своё значение.
		weapon_hitbox.poise_damage = poise_damage
		weapon_hitbox.activate(0.12)
	_on_pickaxe_hit()


## Итоговый урон оружия с множителем навыка. Майнинг блоков идёт
## без прокачки: blocks считаются по базовому mining_damage, иначе
## прокачанный меч начал бы ломать камень быстрее кирки.
func _skill_scaled_weapon_damage() -> int:
	var component: EquipmentComponent = _mainhand_component()
	if component == null or not component.trains_skill:
		return mining_damage
	var multiplier: float = skills.damage_multiplier(component.weapon_skill)
	return maxi(1, int(roundf(float(mining_damage) * multiplier)))


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
	if _below_try_damage_chest():
		return
	# Урон по врагам теперь решает касание хитбокса оружия с
	# хартбоксом цели через Area2D — старый маг-поиск удалён.
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
	if animation_name == &"interact":
		# Возвращаем руки в базовую позу после жеста взаимодействия.
		if not inventory_loop_playing and not is_blocking:
			attack_player.stop()
			if attack_player.has_animation(&"RESET"):
				attack_player.play(&"RESET")
		return
	if not String(animation_name).begins_with("attack_") \
			and not String(animation_name).begins_with("two_handed_"):
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
	if not _stamina_component.spend(amount):
		return false

	stamina_changed.emit(current_stamina, max_stamina)
	return true


func _update_stamina(delta: float) -> void:
	if _stamina_component.tick(delta):
		stamina_changed.emit(current_stamina, max_stamina)


## Продвигает таймеры поиза: стаггер и восстановление равновесия.
## Завершение стаггера возвращает персонажа в IDLE — до этого момента
## он не может начать удар, прыжок или ролл (см. is_staggered()).
func _update_poise(delta: float) -> void:
	if poise.tick(delta):
		if _player_state.current == PlayerStateMachine.State.STAGGER:
			_player_state.force_change(PlayerStateMachine.State.IDLE)


## Открыт ли персонаж для казни: используется правилами backstab.
func is_staggered() -> bool:
	return poise.is_staggered()


func take_damage(
	amount: int,
	source_position: Vector2 = Vector2.ZERO,
	attacker: Node = null,
	is_crit: bool = false,
	poise_dmg: float = 0.0,
	breaks_block: bool = false
) -> void:
	if is_dead or amount <= 0:
		return

	# i-frames ролла: входящий урон полностью игнорируется.
	if is_invulnerable:
		return

	# Блок со щитом: в окно парирования — нулевой урон и стаггер
	# атакующего; вне окна — обычный блок с расходом стамины
	# пропорционально урону. Пробитый блок (стамины не хватило)
	# наносит полный урон.
	#
	# Тяжёлый удар (breaks_block) парированию не поддаётся совсем,
	# а держать под ним щит дорого: расход стамины умножен, и
	# равновесие трясётся полностью, будто блока и не было. Такой
	# удар читается по длинному телеграфу и просит ролл, а не щит.
	var final_amount: int = amount
	var blocked: bool = false
	if is_blocking and _has_shield_equipped() and _shield_faces(source_position):
		if not breaks_block and _try_parry(attacker):
			return

		# Навык «Блок» удешевляет поглощение удара.
		var stamina_rate: float = block_stamina_per_damage
		if skills != null:
			stamina_rate *= skills.block_stamina_multiplier(SkillsComponent.Skill.BLOCKING)
		if breaks_block:
			stamina_rate *= heavy_block_stamina_multiplier

		if _stamina_component.spend(float(amount) * stamina_rate):
			final_amount = maxi(1, int(ceilf(float(amount) * blocked_damage_ratio)))
			blocked = true
			if skills != null:
				skills.add_xp(SkillsComponent.Skill.BLOCKING, block_skill_xp)

	# Поиз-урон считается после блока: щит, поглотивший удар, гасит
	# и равновесие пропорционально. Парированный удар до сюда не
	# доходит — он вообще не трясёт персонажа. Тяжёлый удар ломает
	# щит: равновесие трясётся полностью, даже если стамина устояла.
	var poise_shock: float = poise_dmg
	if blocked and not breaks_block:
		poise_shock *= blocked_damage_ratio
	poise.apply_damage(poise_shock)

	# Цифра урона — до брони, по позиции получателя.
	# Бонусный удар (в спину/казнь) — золотая цифра, чтобы он
	# визуально отличался от обычного урона.
	if is_crit:
		DamageNumber.show_at(
			get_tree().get_current_scene(),
			global_position,
			final_amount,
			Color(1.0, 0.82, 0.25),
			14
		)
	else:
		DamageNumber.show_at(
			get_tree().get_current_scene(),
			global_position,
			final_amount,
			Color(1.0, 0.35, 0.35) if not is_blocking else Color(0.6, 0.8, 1.0)
		)

	current_health = clampi(current_health - _below_apply_armor(final_amount), 0, max_health)
	health_changed.emit(current_health, max_health)
	if current_health <= 0:
		_die()


## Попытка парирования: требует окна от начала блока, отсутствия
## замаха и списания небольшой стамины. Успех: урон 0, атакующий
## входит в стаггер.
func _try_parry(attacker: Node) -> bool:
	# В замахе парировать нельзя: рука занята оружием.
	if pickaxe_swinging:
		return false

	var window: float = _shield_parry_window()
	if window <= 0.0:
		return false
	# Навык «Блок» расширяет окно парирования.
	if skills != null:
		window += skills.parry_window_bonus(SkillsComponent.Skill.BLOCKING)
	if (_get_game_time_seconds() - block_started_at) > window:
		return false
	if not _stamina_component.spend(parry_stamina_cost):
		return false

	_player_state.change_to(PlayerStateMachine.State.PARRY)
	_player_state.change_to(PlayerStateMachine.State.BLOCK)
	if (
		attacker != null
		and is_instance_valid(attacker)
		and attacker.has_method("apply_stagger")
	):
		attacker.apply_stagger(parry_stagger_sec)

	# Парирование — ценнейшее действие: больше опыта, чем блок.
	if skills != null:
		skills.add_xp(SkillsComponent.Skill.BLOCKING, parry_skill_xp)

	DamageNumber.show_at(
		get_tree().get_current_scene(),
		global_position,
		0,
		Color(0.75, 0.9, 1.0)
	)
	stamina_changed.emit(current_stamina, max_stamina)
	return true


## Окно парирования щита из параметров экипированного оффхенд-предмета.
func _shield_parry_window() -> float:
	if equipment == null:
		return 0.0

	var stack: ItemStack = equipment.get_equipped_stack(EquipmentSlot.Type.OFFHAND)
	if stack == null or stack.is_empty():
		return 0.0

	var item: ItemData = ItemRegistry.get_item(stack.item_id)
	var component: EquipmentComponent = item as EquipmentComponent
	if component == null:
		return 0.0

	return component.parry_window_sec


## Снимает входящий урон суммарной защитой экипировки.
## Полностью погасить удар нельзя: сохраняется минимум 15% урона.
func _below_apply_armor(amount: int) -> int:
	if equipment == null:
		return amount
	var armor_total: int = int(equipment.get_totals().get("armor", 0))
	if armor_total <= 0:
		return amount
	var minimal_damage: int = maxi(1, int(ceilf(float(amount) * 0.15)))
	return maxi(minimal_damage, amount - armor_total)


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


## Возрождает персонажа в точке появления.
func respawn() -> void:
	get_tree().paused = false
	global_position = _spawn_position
	velocity = Vector2.ZERO
	revive()


func revive() -> void:
	is_dead = false
	current_health = max_health
	current_stamina = max_stamina
	poise.restore_full()
	_player_state.force_change(PlayerStateMachine.State.IDLE)
	velocity = Vector2.ZERO
	pickaxe_swinging = false
	combo_step = 0
	# Смерть могла застать в блоке: возвращаем стойку и треки рук.
	is_blocking = false
	_set_locomotion_arm_tracks_enabled(true)
	# После анимации смерти плеер играл вне паузы — возвращаем
	# обычный режим и перезапускаем стойку/дыхание.
	if locomotion_player != null:
		locomotion_player.process_mode = Node.PROCESS_MODE_INHERIT
		locomotion_player.stop()
		# RESET обнуляет углы и смещения, выставленные death
		# (в частности Visuals:rotation у заваленного тела).
		if locomotion_player.has_animation(&"RESET"):
			locomotion_player.play(&"RESET")
		_play_locomotion_animation(&"idle")
	_start_secondary_motion()
	hazard_damage_allowed_at.clear()
	health_changed.emit(current_health, max_health)
	stamina_changed.emit(current_stamina, max_stamina)


func _die() -> void:
	if is_dead:
		return

	is_dead = true
	pickaxe_swinging = false
	_player_state.force_change(PlayerStateMachine.State.DEAD)
	combo_step = 0
	velocity = Vector2.ZERO
	# Смерть снимает стаггер: иначе после возрождения персонаж
	# остался бы «оглушённым» на остаток таймера.
	poise.restore_full()
	# Смерть во время ролла: иначе спрайт останется наклонённым и с i-frames.
	if is_rolling:
		is_rolling = false
		is_invulnerable = false
		visuals.rotation = 0.0
		visuals.modulate = Color(1, 1, 1)
		secondary_motion_player.speed_scale = current_breath_speed
	hazard_damage_allowed_at.clear()

	if stop_on_death:
		if mining_cooldown != null:
			mining_cooldown.stop()
		if attack_player != null:
			attack_player.stop()
		if locomotion_player != null:
			locomotion_player.stop()
			# Анимация смерти проигрывается уже после паузы дерева,
			# поэтому плееру нужен режим обработки вне паузы.
			locomotion_player.process_mode = Node.PROCESS_MODE_ALWAYS
			_set_locomotion_arm_tracks_enabled(true)
			if locomotion_player.has_animation(&"death"):
				locomotion_player.speed_scale = 1.0
				locomotion_player.play(&"death")
			secondary_motion_player.stop()

	died.emit()

	# Полностью замораживаем игру: ни копать, ни выделять, ни подбирать.
	# LocomotionPlayer выше переведён в PROCESS_MODE_ALWAYS,
	# поэтому падение дорисовывается поверх паузы.
	get_tree().paused = true


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

			# Опасна только нижняя часть клетки — там, где сами шипы.
			var cell_center: Vector2 = terrain.get_cell_global_center(cell)
			var hazard_height: float = tile_size.y * hazard_cell_fill_ratio
			var hazard_rect := Rect2(
				Vector2(
					cell_center.x - tile_size.x * 0.5,
					cell_center.y + tile_size.y * 0.5 - hazard_height
				),
				Vector2(tile_size.x, hazard_height)
			)

			# Нужно реальное пересечение с шипами, а не просто соседняя клетка.
			var overlap: Rect2 = contact_rect.intersection(hazard_rect)
			if overlap.size.x < hazard_minimum_overlap or overlap.size.y < hazard_minimum_overlap:
				continue

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


## Создаёт узел экипировки и запоминает базовые значения статов.
## ВАЖНО: вызывается до установки current_health/current_stamina,
## поэтому baseline совпадает с экспортными настройками персонажа.
func _initialize_equipment() -> void:
	equipment = EquipmentSystem.new()
	equipment.name = "EquipmentSystem"
	add_child(equipment)
	equipment.setup(self)


## Надевает предмет из ячейки инвентаря в указанный слот.
func equip_from_inventory(inventory_slot_index: int, slot: EquipmentSlot.Type) -> bool:
	if equipment == null:
		return false
	return equipment.equip_from_inventory(inventory, inventory_slot_index, slot)


## Снимает предмет из слота экипировки в инвентарь.
func unequip_to_inventory(slot: EquipmentSlot.Type) -> bool:
	if equipment == null:
		return false
	return equipment.unequip_to_inventory(inventory, slot)


## Вызывается предметом на земле. Возвращает реально принятое количество.
func receive_item(item_id: StringName, amount: int) -> int:
	if inventory == null or amount <= 0:
		return 0
	var accepted: int = inventory.add_item(item_id, amount)
	if accepted > 0:
		item_picked_up.emit(item_id, accepted)
	if accepted < amount:
		print("Не удалось подобрать всё: %s × %d. Нет места или превышен вес." % [item_id, amount - accepted])
	return accepted


# BELOW_CHEST_MINING_V1
## Вызывается перед метой на землю. Возвращает реальное количество урона.
func _below_try_damage_chest() -> bool:
	if terrain == null or terrain.tile_set == null:
		return false
	var cells: Array[Vector2i] = _get_attack_mining_cells()
	# Непроходимая коллизия сундуку не нужна: ищем его по группе.
	for candidate: Node in get_tree().get_nodes_in_group("placeable_structure"):
		if not candidate is Node2D or candidate.is_queued_for_deletion():
			continue
		if not candidate.has_method("receive_structure_damage"):
			continue
		var structure: Node2D = candidate as Node2D
		var structure_cell: Vector2i = terrain.global_position_to_cell(structure.global_position)
		for cell: Vector2i in cells:
			if not is_cell_mineable(cell):
				continue
			var center: Vector2 = terrain.to_global(terrain.map_to_local(cell))
			var local_center: Vector2 = structure.to_local(center)
			if cell == structure_cell or Rect2(-16.0, -28.0, 32.0, 28.0).has_point(local_center):
				# Отладочное уничтожение блоков с одного удара здесь НЕ действует.
				structure.call("receive_structure_damage", maxi(1, mining_damage))
				# Удар в сундук не повреждает одновременно его опору.
				return true
	return false


## Слот держит исходный предмет (кирку), нарисованный в самой сцене.
## При пустом MAINHAND возвращаем именно его, а не скрываем спрайт.
var default_held_weapon_texture: Texture2D = null
var default_shield_texture: Texture2D = null
var held_weapon_base_scale: Vector2 = Vector2.ONE
var shield_base_scale: Vector2 = Vector2.ONE


## Запоминает «родной» вид спрайтов из сцены, чтобы корректно
## восстанавливать его после снятия экипировки.
func _cache_default_held_visuals() -> void:
	if held_weapon_sprite != null:
		default_held_weapon_texture = held_weapon_sprite.texture
		held_weapon_base_scale = held_weapon_sprite.scale
	if shield_sprite != null:
		default_shield_texture = shield_sprite.texture
		shield_base_scale = shield_sprite.scale


## Возвращает текстуру, которую предмет показывает в руке.
## Приоритет у held_weapon_texture, запасной вариант — icon.
func _held_texture_for(item_id: StringName) -> Texture2D:
	var item: ItemData = ItemRegistry.get_item(item_id)
	if item == null:
		return null
	if item is EquipmentComponent:
		var component: EquipmentComponent = item as EquipmentComponent
		if component.held_weapon_texture != null:
			return component.held_weapon_texture
	return item.icon


## Сигнал от EquipmentSystem: экипировка изменилась, обновляем руки.
func _on_equipment_changed(_slot: EquipmentSlot.Type) -> void:
	_update_held_weapon_visuals()
	# Надетая/снятая броня меняет нагрузку, а с ней — шаг и реген.
	_apply_encumbrance_to_stamina()
	_report_equipped_weapon_skill(_slot)


## Подсказка в HUD: какой уровень навыка даёт взятое в руку оружие.
func _report_equipped_weapon_skill(slot: EquipmentSlot.Type) -> void:
	if slot != EquipmentSlot.Type.MAINHAND:
		return
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud == null or not hud.has_method("show_weapon_skill"):
		return

	var component: EquipmentComponent = _mainhand_component()
	if component == null or not component.trains_skill:
		hud.call("show_weapon_skill", &"", 0)
		return

	var skill_name: String = SkillsComponent.SKILL_NAMES.get(component.weapon_skill, "")
	hud.call("show_weapon_skill", StringName(skill_name), skills.get_level(component.weapon_skill))


## Перерисовывает оружие и щит в руках по текущим слотам экипировки.
## Пустой слот возвращает спрайту его исходный вид из сцены, поэтому
## кирка не исчезает, когда персонаж ничего не держит.
func _update_held_weapon_visuals() -> void:
	if equipment == null:
		return

	if held_weapon_sprite != null:
		var main_stack: ItemStack = equipment.get_equipped_stack(EquipmentSlot.Type.MAINHAND)
		if main_stack == null or main_stack.is_empty():
			held_weapon_sprite.texture = default_held_weapon_texture
			held_weapon_sprite.scale = held_weapon_base_scale
		else:
			var texture: Texture2D = _held_texture_for(main_stack.item_id)
			if texture != null:
				held_weapon_sprite.texture = texture
			# Двуручное оружие выглядит крупнее: масштаб считаем от
			# базового значения сцены, а не подменяем его наконечником.
			var dual_hand_scale: float = 1.35 if _is_dual_hand_equipped() else 1.0
			held_weapon_sprite.scale = held_weapon_base_scale * dual_hand_scale

	# Щит появляется только вместе с экипированным предметом:
	# в самой сцене на спрайте лежит превью-текстура, поэтому без
	# явного скрытия он висел бы в руке постоянно.
	if shield_sprite != null:
		var off_stack: ItemStack = equipment.get_equipped_stack(EquipmentSlot.Type.OFFHAND)
		if off_stack == null or off_stack.is_empty():
			shield_sprite.visible = false
		else:
			var texture: Texture2D = _held_texture_for(off_stack.item_id)
			if texture != null:
				shield_sprite.texture = texture
			shield_sprite.scale = shield_base_scale
			shield_sprite.visible = true
