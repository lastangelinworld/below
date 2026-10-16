class_name Skeleton
extends CharacterBody2D

## Враг-скелет. Два типа: мечник (меч + щит) и лучник.
## Мечник преследует игрока и бьёт вблизи, лучник держит дистанцию
## и стреляет костяными снарядами.

signal died

@export_group("Характеристики")
## Скорость преследования игрока.
@export_range(0.0, 400.0, 1.0) var move_speed: float = 55.0

## Здоровье скелета.
@export_range(1, 1000, 1) var maximum_health: int = 30

## Радиус, в котором скелет замечает игрока.
@export_range(32.0, 1000.0, 1.0) var detection_radius: float = 240.0

## Урон удара мечом.
@export_range(0, 100, 1) var melee_damage: int = 5

## Поиз-урон удара мечом: насколько игрок «теряет равновесие».
## Мечник сбивает с ног быстрее, чем наносит урона.
@export_range(0.0, 100.0, 0.5) var melee_poise_damage: float = 9.0

## Урон костяного снаряда.
@export_range(0, 100, 1) var arrow_damage: int = 3

@export_group("Поиз")
## Запас устойчивости скелета: когда иссякает — он замирает в стаггере,
## и игрок может добить его ударом «на казнь» (×1.5).
@export_range(5, 500, 1) var maximum_poise: float = 26.0

## Длительность стаггера скелета в секундах.
@export_range(0.3, 5.0, 0.1) var stagger_duration: float = 1.1

## Скорость восстановления равновесия (единиц в секунду).
@export_range(0.0, 50.0, 0.5) var poise_regen_per_second: float = 9.0

@export_group("Телеграф (Фаза 7)")
## Длительность замаха лёгкого удара: его можно парировать.
@export_range(0.15, 1.5, 0.05) var light_windup_sec: float = 0.4

## Длительность замаха тяжёлого удара: длиннее и краснее —
## игрок успевает прочитать и уйти роллом.
@export_range(0.2, 2.0, 0.05) var heavy_windup_sec: float = 0.6

## Пауза восстановления после лёгкого удара: окно для наказания.
@export_range(0.0, 3.0, 0.05) var light_recover_sec: float = 0.45

## Пауза после тяжёлого: промахнулся тяжёлым — поплатился окном.
@export_range(0.0, 3.0, 0.05) var heavy_recover_sec: float = 1.0

## Доля атак мечника, которые становятся тяжёлыми.
@export_range(0.0, 1.0, 0.05) var heavy_chance: float = 0.35

## Во сколько раз тяжёлый удар больнее обычного.
@export_range(1.0, 5.0, 0.1) var heavy_damage_multiplier: float = 1.8

## Во сколько раз тяжёлый удар сильнее трясёт равновесие.
@export_range(1.0, 5.0, 0.1) var heavy_poise_multiplier: float = 2.2

## Время натяжения лука лучником: игрок видит позу прицела
## и успевает закрыться щитом или уйти с линии выстрела.
@export_range(0.15, 1.5, 0.05) var archer_draw_sec: float = 0.5

@export_group("Снаряжение")
## true — меч и щит (ближний бой), false — лук.
@export var melee_unit: bool = true

## Случайный выбор типа при готовке. Спавнер выключает его
## и задаёт melee_unit явно, чтобы держать по одному скелету каждого вида.
@export var randomize_type: bool = true

## Сцена костяного снаряда для лучника.
@export var arrow_scene: PackedScene

const GRAVITY: float = 900.0
const MELEE_RANGE: float = 50.0
const MELEE_COOLDOWN: float = 1.1
const ARCHER_RANGE: float = 200.0
const ARCHER_KEEP_DISTANCE: float = 90.0
const ARCHER_COOLDOWN: float = 2.2

## Размеры полоски здоровья над головой. Рост скелета ~60 px
## (две клетки, как игрок), поэтому полоска висит над черепом.
const HEALTH_BAR_WIDTH: float = 26.0
const HEALTH_BAR_HEIGHT: float = 3.0
const HEALTH_BAR_TOP: float = -68.0

## Фазы атаки (Фаза 7): телеграф → удар → восстановление.
## DRAW — отдельная фаза лучника: видимое натяжение тетивы
## перед выстрелом (тот же принцип «прочитай и отреагируй»).
enum AttackPhase { NONE, WINDUP, HIT, RECOVERY, DRAW }

## Окно поражения удара: совпадает с activation_seconds у Hitbox,
## чтобы фаза HIT жила ровно столько, сколько активна форма клинка.
const HIT_ACTIVE_SEC: float = 0.12

var current_health: int = 30
var _attack_cooldown: float = 0.0
var _attack_phase: AttackPhase = AttackPhase.NONE
var _attack_timer: float = 0.0
var _is_heavy: bool = false
var _terrain: TerrainLayer
var _player: CharacterBody2D
var _health_bar_fill: ColorRect

## Поиз-компонент (Фаза 4): устойчивость к стаггеру.
## Владеет и таймером стаггера от парирования, и восстановлением поиза.
var poise: PoiseComponent

## Направление взгляда: 1 — вправо, -1 — влево. Синхронизировано с
## переворотом спрайта и нужно правилам backstab: атакующий со стороны
## спины получает бонусный урон.
var facing: int = 1

## Базовый масштаб Visuals из сцены (например 1.3). Нужен, потому что
## переворот лицом пишет в scale.x и без опорного значения обнулил бы
## размер, заданный в редакторе.
var _visuals_base_scale: Vector2 = Vector2.ONE

@onready var visuals: Node2D = get_node_or_null("Visuals") as Node2D
@onready var animation_player: AnimationPlayer = get_node_or_null(
	"AnimationPlayer"
) as AnimationPlayer
@onready var sword_node: Node2D = get_node_or_null(
	"Visuals/Rig/Hips/Spine/ShoulderFront/ElbowFront/WristFront/Sword"
) as Node2D
@onready var shield_visual: Sprite2D = get_node_or_null(
	"Visuals/Rig/Hips/Spine/ShoulderBack/ElbowBack/WristBack/ShieldSprite"
) as Sprite2D
@onready var bow_node: Node2D = get_node_or_null(
	"Visuals/Rig/Hips/Spine/ShoulderFront/ElbowFront/WristFront/Bow"
) as Node2D
@onready var weapon_hitbox: Hitbox = get_node_or_null(
	"Visuals/Rig/Hips/Spine/ShoulderFront/ElbowFront/WristFront/Sword/Hitbox"
) as Hitbox
@onready var sword_visual: Sprite2D = get_node_or_null(
	"Visuals/Rig/Hips/Spine/ShoulderFront/ElbowFront/WristFront/Sword/Blade"
) as Sprite2D

## Базовый цвет клинка: телеграф замаха меняет его,
## а завершение атаки возвращает сюда.
var _sword_base_color: Color = Color(1, 1, 1, 1)


func _ready() -> void:
	# Отдельный физический слой: скелет встаёт на блоки (слой 1),
	# но не мешает проверкам размещения построек (маска 1).
	collision_layer = 8
	collision_mask = 1
	add_to_group("enemy")
	if randomize_type:
		melee_unit = randf() < 0.5
	add_to_group("melee_enemy" if melee_unit else "ranged_enemy")
	current_health = maximum_health
	if visuals != null:
		_visuals_base_scale = visuals.scale
	_setup_poise_component()
	_setup_animations()
	_terrain = _find_terrain()
	_create_health_bar()
	_show_type_visual()


func _physics_process(delta: float) -> void:
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)

	# Продвигаем таймеры поиза: стаггер от ударов или парирования.
	poise.tick(delta)

	# Если в стаггере — не двигаемся и не атакуем.
	if poise.is_staggered():
		velocity.x = move_toward(velocity.x, 0.0, move_speed * delta)
		if not is_on_floor():
			velocity.y = minf(velocity.y + GRAVITY * delta, 900.0)
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, 900.0)

	# Фаза 7: во время замаха/удара/восстановления скелет стоит —
	# именно неподвижность и подсветка клинка читаются игроком как
	# телеграф: лёгкий удар можно паририровать, тяжёлый — прочитать
	# по длинной красной подготовке и уйти роллом.
	if _attack_phase != AttackPhase.NONE:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 4.0 * delta)
		move_and_slide()
		_advance_attack_phase(delta)
		return

	_refresh_player()

	if _player == null:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * delta)
		move_and_slide()
		_update_locomotion_animation()
		return

	var to_player: Vector2 = _player.global_position - global_position
	var flat_distance: float = absf(to_player.x)

	if flat_distance > detection_radius:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * delta)
		move_and_slide()
		_update_locomotion_animation()
		return

	# Мечник идёт к игроку; лучник подходит, но не вплотную.
	var walking: bool
	if melee_unit:
		walking = flat_distance > MELEE_RANGE * 0.8
	else:
		walking = flat_distance > ARCHER_KEEP_DISTANCE

	if walking:
		velocity.x = signf(to_player.x) * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * delta)

	move_and_slide()

	# Локомоция обновляется ДО выбора атаки: если сейчас начнётся
	# замах, его анимация имеет приоритет над шагом/покоем.
	_update_locomotion_animation()
	_try_attack(flat_distance)
	_flip_towards(to_player.x)


## Выбирает цель: живой игрок или ничего.
func _refresh_player() -> void:
	if _player != null and is_instance_valid(_player):
		if bool(_player.get("is_dead")):
			_player = null
		return

	var candidate: Node = get_tree().get_first_node_in_group("player")
	if candidate is CharacterBody2D and not bool(candidate.get("is_dead")):
		_player = candidate as CharacterBody2D
	else:
		_player = null


func _try_attack(flat_distance: float) -> void:
	if _attack_cooldown > 0.0 or _player == null:
		return
	# Атака уже идёт (замах/удар/восстановление) — не начинаем новую.
	if _attack_phase != AttackPhase.NONE:
		return

	if melee_unit:
		if flat_distance <= MELEE_RANGE:
			_begin_melee_attack()
		return

	if flat_distance <= ARCHER_RANGE:
		_begin_arrow_draw()


## Начало замаха (Фаза 7): выбирает лёгкий или тяжёлый удар и
## запускает телеграф. Кулдаун ставится на весь цикл фаз, а не на
## мгновенный удар, как было раньше.
func _begin_melee_attack() -> void:
	_is_heavy = randf() < heavy_chance
	_attack_phase = AttackPhase.WINDUP
	_attack_timer = light_windup_sec if not _is_heavy else heavy_windup_sec
	_show_windup_tint()
	# Клип подгоняется под экспорт-таймер: speed_scale = длина клипа / нужная.
	if _is_heavy:
		_play_anim(&"heavy_windup", 0.06, SkeletonAnimations.HEAVY_WINDUP_LEN / maxf(_attack_timer, 0.02))
	else:
		_play_anim(&"light_windup", 0.06, SkeletonAnimations.LIGHT_WINDUP_LEN / maxf(_attack_timer, 0.02))


## Лучник не стреляет мгновенно: сначала видимое натяжение (DRAW),
## выстрел — в конце фазы, как удар мечника в конце замаха.
func _begin_arrow_draw() -> void:
	_attack_phase = AttackPhase.DRAW
	_attack_timer = archer_draw_sec
	_play_anim(&"bow_draw", 0.08, SkeletonAnimations.DRAW_LEN / maxf(archer_draw_sec, 0.02))


## Продвигает фазы атаки: телеграф → удар → восстановление → покой.
func _advance_attack_phase(delta: float) -> void:
	_attack_timer -= delta
	if _attack_timer > 0.0:
		return

	match _attack_phase:
		AttackPhase.WINDUP:
			_swing_sword()
			_attack_phase = AttackPhase.HIT
			_attack_timer = HIT_ACTIVE_SEC
			# Взмах короче замаха в разы: клип проигрываем «на скорости»,
			# чтобы окно поражения и движение меча совпали покадрово.
			var swing_speed: float = (
				SkeletonAnimations.HEAVY_SWING_LEN / HIT_ACTIVE_SEC
				if _is_heavy else SkeletonAnimations.LIGHT_SWING_LEN / HIT_ACTIVE_SEC
			)
			_play_anim(&"heavy_swing" if _is_heavy else &"light_swing", 0.0, maxf(swing_speed, 1.0))
		AttackPhase.HIT:
			_reset_sword_visual()
			_attack_phase = AttackPhase.RECOVERY
			_attack_timer = light_recover_sec if not _is_heavy else heavy_recover_sec
		AttackPhase.DRAW:
			_shoot_arrow()
			_attack_phase = AttackPhase.RECOVERY
			_attack_timer = 0.4
			_play_anim(&"bow_release", 0.0, SkeletonAnimations.RELEASE_LEN / 0.15)
		AttackPhase.RECOVERY:
			_attack_phase = AttackPhase.NONE
			# Кулдаун отсчитывается от конца восстановления: окно на
			# наказание промаха остаётся, но не бесконечное.
			_attack_cooldown = MELEE_COOLDOWN if melee_unit else ARCHER_COOLDOWN
			_play_anim(&"idle", 0.25)
		_:
			_attack_phase = AttackPhase.NONE


## Замах мечом: урон наносит касание формы клинка, а не прямой вызов,
## поэтому меч и кирка дают одинаковый фидбек — через окно поражения.
## Тяжёлый удар (Фаза 7) умножает урон и поиз и ломает блок: его
## нельзя парировать, и держать под ним щит дорого.
func _swing_sword() -> void:
	if weapon_hitbox == null:
		# Страховка: если формы удара в сцене нет, бьём напрямую,
		# иначе мечник совсем не наносит урона.
		var damage: int = melee_damage
		if _is_heavy:
			damage = maxi(1, int(roundf(float(melee_damage) * heavy_damage_multiplier)))
		_player.take_damage(damage, global_position, self, false, 0.0, _is_heavy)
		return

	if _is_heavy:
		weapon_hitbox.damage = maxi(
			1, int(roundf(float(melee_damage) * heavy_damage_multiplier))
		)
		weapon_hitbox.poise_damage = melee_poise_damage * heavy_poise_multiplier
	else:
		weapon_hitbox.damage = melee_damage
		weapon_hitbox.poise_damage = melee_poise_damage
	weapon_hitbox.breaks_block = _is_heavy
	weapon_hitbox.source_owner = self
	weapon_hitbox.activate()


## Подсветка клинка во время замаха (Фаза 7): лёгкий — короткий
## белый блеск (его можно паририровать), тяжёлый — длинное красное
## свечение (читается как «блокировать нельзя, уходи»).
func _show_windup_tint() -> void:
	if sword_visual == null:
		return
	sword_visual.modulate = (
		Color(1.0, 0.35, 0.25, 1.0) if _is_heavy else Color(1.0, 0.95, 0.7, 1.0)
	)


## Возвращает клинку обычный цвет после удара.
func _reset_sword_visual() -> void:
	if sword_visual != null:
		sword_visual.modulate = _sword_base_color


## Запускает костяной снаряд в сторону игрока.
func _shoot_arrow() -> void:
	if _player == null:
		return

	var scene: PackedScene = arrow_scene
	if scene == null:
		const ARROW_PATH: String = "res://data/world/arrow_projectile.tscn"
		if ResourceLoader.exists(ARROW_PATH):
			scene = load(ARROW_PATH) as PackedScene
	if scene == null:
		push_warning("Скелет-лучник: не найдена сцена снаряда.")
		return

	var projectile: Node = scene.instantiate()
	if not projectile.has_method("setup"):
		projectile.free()
		return

	var world: Node = get_tree().current_scene
	if world == null:
		projectile.free()
		return

	world.add_child(projectile)
	# Выстрел из уровня груди лучника (рост ~60 px, грудь ~ -34).
	var start: Vector2 = global_position + Vector2(0.0, -34.0)
	var aim: Vector2 = (_player.global_position + Vector2(0.0, -8.0) - start).normalized()
	projectile.call("setup", start, aim, arrow_damage)


## Стаггер от парирования игроком: скелет замирает на duration секунд.
## Тот же механизм, что и стаггер от иссякшего поиза, поэтому казнь
## работает для обоих случаев одинаково.
func apply_stagger(duration: float) -> void:
	poise.apply_stagger(duration)


## Открыт ли скелет для казни: используется правилами backstab
## (BackstabRules.is_staggered).
func is_staggered() -> bool:
	return poise.is_staggered()


func take_damage(
	amount: int,
	_source_position: Vector2 = Vector2.ZERO,
	_attacker: Node = null,
	is_crit: bool = false,
	poise_dmg: float = 0.0,
	_breaks_block: bool = false
) -> void:
	if amount <= 0:
		return

	# Цифра урона — в том же месте, что и у персонажа: в take_damage()
	# цели, поэтому кирка и стрела дают одинаковый фидбек.
	# Бонусный удар (в спину/казнь) — золотая цифра.
	DamageNumber.show_at(
		get_tree().get_current_scene(),
		global_position + Vector2(0.0, HEALTH_BAR_TOP),
		amount,
		Color(1.0, 0.82, 0.25) if is_crit else Color(1.0, 0.55, 0.4),
		14 if is_crit else 10
	)

	# Поиз-урон: если равновесие иссякло, скелет замирает и открыт для казни.
	# Смертельный удар стаггер не нужен — цель всё равно исчезает.
	poise.apply_damage(poise_dmg)

	current_health = maxi(0, current_health - amount)
	_update_health_label()
	if current_health <= 0:
		_die()


## Смерть: клинок гаснет, кости «рассыпаются» (клип death),
## узел удаляется после проигрыша — успевает читаться глазами.
func _die() -> void:
	died.emit()
	set_physics_process(false)
	velocity = Vector2.ZERO
	if weapon_hitbox != null:
		weapon_hitbox.deactivate()
	_reset_sword_visual()
	_play_anim(&"death", 0.05)
	var timer: SceneTreeTimer = get_tree().create_timer(SkeletonAnimations.DEATH_LEN)
	timer.timeout.connect(queue_free)


## Строит полоску здоровья прямо из кода, чтобы она появилась у скелетов
## и в уже собранной сцене, и у тех, что спавнер создаёт на лету.
## Полоска висит на корне, а не в Visuals, поэтому переворот спрайта
## её не зеркалит.
func _create_health_bar() -> void:
	if get_node_or_null("HealthBar") != null:
		return

	var background := ColorRect.new()
	background.name = "HealthBar"
	background.color = Color(0.06, 0.05, 0.05, 0.85)
	background.offset_left = -HEALTH_BAR_WIDTH * 0.5
	background.offset_top = HEALTH_BAR_TOP
	background.offset_right = HEALTH_BAR_WIDTH * 0.5
	background.offset_bottom = HEALTH_BAR_TOP + HEALTH_BAR_HEIGHT
	background.z_index = 90
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.color = Color(0.72, 0.2, 0.2, 1.0)
	fill.offset_right = HEALTH_BAR_WIDTH
	fill.offset_bottom = HEALTH_BAR_HEIGHT
	fill.pivot_offset = Vector2.ZERO
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.add_child(fill)
	_health_bar_fill = fill


## Мечник и лучник делят один риг: различаются только держатели —
## у мечника меч и щит, у лучника лук вместо меча и нет щита.
func _show_type_visual() -> void:
	if sword_node != null:
		sword_node.visible = melee_unit
	if shield_visual != null:
		shield_visual.visible = melee_unit
	if bow_node != null:
		bow_node.visible = not melee_unit
	_update_health_label()


## Инициализирует компонент поиза: источник времени, параметры стаггера.
func _setup_poise_component() -> void:
	poise = PoiseComponent.new()
	poise.name = &"PoiseComponent"
	add_child(poise)
	poise.is_dead_provider = func() -> bool: return current_health <= 0
	poise.configure(_get_game_time_seconds)
	poise.max_poise = maximum_poise
	poise.stagger_duration = stagger_duration
	poise.poise_regen_per_second = poise_regen_per_second
	poise.restore_full()


## Строит библиотеку анимаций (Этап C плана) и подключает стаггер:
## поиз-компонент уже знает момент потери равновесия — анимация
## подхватывает его сигналы, не дублируя таймеры.
func _setup_animations() -> void:
	if animation_player == null:
		return
	SkeletonAnimations.install(animation_player)
	poise.stagger_started.connect(_on_poise_stagger_started)
	poise.stagger_ended.connect(_on_poise_stagger_ended)
	_play_anim(&"idle")


## Единый плеер: безопасен при пустой библиотеке, умеет подгонять
## длительность клипа под тайминги боя (speed_scale).
func _play_anim(name: StringName, blend: float = 0.1, speed: float = 1.0) -> void:
	if animation_player == null or not animation_player.has_animation(name):
		return
	animation_player.speed_scale = speed
	if animation_player.current_animation != name or not animation_player.is_playing():
		animation_player.play(name, blend)


## Останавливает текущий клип, возвращая позы пивотов в покой.
func _stop_anim() -> void:
	if animation_player == null:
		return
	if animation_player.has_animation(&"RESET"):
		animation_player.play(&"RESET")
	animation_player.speed_scale = 1.0


## Простой: шаги или покой. Порог маленький — шаркающий шаг скелета
## медленный, но анимироваться должен даже на малой скорости.
func _update_locomotion_animation() -> void:
	var walking: bool = absf(velocity.x) > 2.0
	if walking:
		var speed_ratio: float = absf(velocity.x) / maxf(move_speed, 1.0)
		_play_anim(&"walk", 0.12, clampf(speed_ratio, 0.5, 1.4))
	else:
		_play_anim(&"idle", 0.2)


func _on_poise_stagger_started(_duration: float) -> void:
	# Стаггер прерывает любую атаку: замах не доигрывается.
	_attack_phase = AttackPhase.NONE
	if weapon_hitbox != null:
		weapon_hitbox.deactivate()
	_reset_sword_visual()
	_play_anim(&"stagger", 0.08)


func _on_poise_stagger_ended() -> void:
	_play_anim(&"idle", 0.2)


func _update_health_label() -> void:
	var label: Label = get_node_or_null("HealthLabel") as Label
	if label != null:
		label.text = str(current_health)

	if _health_bar_fill == null or not is_instance_valid(_health_bar_fill):
		return

	var ratio: float = 0.0
	if maximum_health > 0:
		ratio = clampf(float(current_health) / float(maximum_health), 0.0, 1.0)

	_health_bar_fill.scale.x = ratio
	# Полоска краснеет по мере урона: жёлтая на середине, красная в конце.
	_health_bar_fill.color = Color(0.45, 0.78, 0.3, 1.0).lerp(
		Color(0.85, 0.18, 0.14, 1.0),
		1.0 - ratio
	)


func _flip_towards(horizontal_difference: float) -> void:
	if visuals == null or absf(horizontal_difference) < 0.5:
		return
	facing = -1 if horizontal_difference < 0.0 else 1
	visuals.scale.x = _visuals_base_scale.x * float(facing)


func _get_game_time_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0


func _find_terrain() -> TerrainLayer:
	var named: Node = get_tree().current_scene
	if named == null:
		return null

	var direct: Node = named.get_node_or_null("Terrain")
	if direct is TerrainLayer:
		return direct as TerrainLayer

	for node: Node in named.find_children("*", "TileMapLayer", true, false):
		if node is TerrainLayer:
			return node as TerrainLayer

	return null
