class_name PlayerAnimations
extends RefCounted

## Кодовая генерация всей анимации игрока в стиле Salt & Sanctuary
## («Рыцарь»): тяжёлое размеренное дыхание, весомый шаг с провалом
## корпуса, явные фазы замаха windup → удар → восстановление.
##
## Риг игрока живёт в entities/player/player.tscn, крутят его три
## AnimationPlayer. Чтобы плееры не дрались за один узел, каждый
## узел закреплён ровно за одним из них:
##
##   LocomotionPlayer  — шаги, стойка, падение:
##     Visuals/{Front,Back}Hip → …/Knee → …/Ankle :rotation
##     Visuals/BodyBreath :position
##     Visuals/BodyBreath/BackShoulder :rotation, …/BackElbow :rotation
##     Visuals/BodyBreath/FrontArmAim/FrontArmAttack :rotation, …/FrontElbow :rotation
##     Visuals :rotation (только stagger/death — возврат из завала)
##   AttackPlayer      — бой: FrontArmAttack / FrontElbow /
##     BackShoulder / BackElbow / BackWrist.
##   Обе руки локомоция тоже покачивает, но как только начинается удар
##   или поднимается щит, player.gd отключает эти треки в локомоции
##   (_set_locomotion_arm_tracks_enabled) — иначе два плеера тянули бы
##   одну руку в разные стороны.
##   SecondaryMotionPlayer — «вторичное движение» (дыхание), пути
##     ОТНОСИТЕЛЬНО Visuals, потому что плеер лежит внутри Visuals
##     и его root_node = «..»:
##     BodyBreath :scale, BodyBreath/NeckPivot/HeadBreath :position,
##     {Front,Back}HipBreath :rotation, …/KneeBreath :rotation
##
## Узлы, которые player.gd пишет каждый кадр, анимациями НЕ трекаются
## вообще: BodyBreath:rotation и HeadBreath:rotation (_update_cursor_body_lean),
## FrontArmAim:rotation (_update_arm_aim), Visuals:scale.x (_update_facing).
## Иначе движок и скрипт тянули бы один угол в разные стороны.


## Тайминги начала активного окна удара. Обязаны совпадать с
## _get_attack_hit_delay() в player.gd — там источник правды для боя,
## здесь те же числа расставляют пик замаха по кадрам.
const HIT_DELAY_1: float = 0.22
const HIT_DELAY_2: float = 0.18
const HIT_DELAY_3: float = 0.31

## Штатное положение корпуса в риге (из player.tscn): BodyBreath:position.
const _BODY_HOME := Vector2(-10.0, 110.0)

const _FRONT_HIP: String = "Visuals/FrontHip"
const _FRONT_KNEE: String = "Visuals/FrontHip/FrontHipBreath/FrontThigh/FrontKnee"
const _FRONT_ANKLE: String = (
	"Visuals/FrontHip/FrontHipBreath/FrontThigh/FrontKnee/FrontKneeBreath/FrontShin/FrontAnkle"
)
const _BACK_HIP: String = "Visuals/BackHip"
const _BACK_KNEE: String = "Visuals/BackHip/BackHipBreath/BackThigh/BackKnee"
const _BACK_ANKLE: String = (
	"Visuals/BackHip/BackHipBreath/BackThigh/BackKnee/BackKneeBreath/BackAnkle"
)
const _BODY: String = "Visuals/BodyBreath"
# Роли рук (после обмена): щит — на передней руке (она же прицельная,
# следует за курсором), оружие — на задней, за корпусом.
const _SHIELD_SHOULDER: String = "Visuals/BodyBreath/FrontArmAim/FrontArmAttack"
const _SHIELD_ELBOW: String = "Visuals/BodyBreath/FrontArmAim/FrontArmAttack/FrontElbow"
const _SHIELD_WRIST: String = (
	"Visuals/BodyBreath/FrontArmAim/FrontArmAttack/FrontElbow/FrontWrist"
)
const _SWORD_ARM: String = "Visuals/BodyBreath/BackShoulder"
const _SWORD_ELBOW: String = "Visuals/BodyBreath/BackShoulder/BackElbow"
## Домашняя позиция BackShoulder: position-треки клипов абсолютны,
## поэтому сдвиги "руки" прибавляются к этому дому, а не к нулю.
const _SWORD_ARM_HOME := Vector2(70.0, -183.0)
const _VISUALS: String = "Visuals"

## Пути SecondaryMotionPlayer — от Visuals, без префикса.
const _SEC_BODY: String = "BodyBreath"
const _SEC_HEAD: String = "BodyBreath/NeckPivot/HeadBreath"
const _SEC_FRONT_HIP: String = "FrontHip/FrontHipBreath"
const _SEC_FRONT_KNEE: String = "FrontHip/FrontHipBreath/FrontThigh/FrontKnee/FrontKneeBreath"
const _SEC_BACK_HIP: String = "BackHip/BackHipBreath"
const _SEC_BACK_KNEE: String = "BackHip/BackHipBreath/BackThigh/BackKnee/BackKneeBreath"


# ══════════════════════════════════════════════════════════════════
#  LocomotionPlayer: стойка, локомоция, оглушение, смерть
# ══════════════════════════════════════════════════════════════════

static func install_locomotion(player: AnimationPlayer) -> void:
	# Клипы могут быть «запечены» в player.tscn редактором — тогда сцена
	# является источником правды и её нельзя затирать (иначе правки ключей
	# исчезают при каждом запуске игры).
	if player.has_animation_library(&""):
		return

	var library := AnimationLibrary.new()

	_add_locomotion_reset(library)

	# Стойка рыцаря: колени подгружены, корпус чуть наклонён вперёд,
	# меч опущен и готов, щит прижат. Дыхание здесь НЕ трекается —
	# его ведёт SecondaryMotionPlayer.
	var idle := _new_anim(library, &"idle", 2.6, true)
	var t := _times([0.0, 0.65, 1.3, 1.95, 2.6])
	_rot(idle, _FRONT_HIP, t, [-0.06, -0.04, -0.06, -0.05, -0.06])
	_rot(idle, _FRONT_KNEE, t, [0.16, 0.13, 0.16, 0.14, 0.16])
	_rot(idle, _FRONT_ANKLE, t, [-0.10, -0.08, -0.10, -0.09, -0.10])
	_rot(idle, _BACK_HIP, t, [0.10, 0.08, 0.10, 0.09, 0.10])
	_rot(idle, _BACK_KNEE, t, [0.20, 0.17, 0.20, 0.18, 0.20])
	_rot(idle, _BACK_ANKLE, t, [-0.12, -0.10, -0.12, -0.11, -0.12])
	_pos(idle, _BODY, t, [
		_BODY_HOME, _BODY_HOME + Vector2(0.6, 0.8), _BODY_HOME,
		_BODY_HOME + Vector2(0.4, 0.6), _BODY_HOME,
	])
	_rot(idle, _SHIELD_SHOULDER, t, [0.16, 0.13, 0.16, 0.14, 0.16])
	_rot(idle, _SHIELD_ELBOW, t, [-0.55, -0.50, -0.55, -0.52, -0.55])
	_rot(idle, _SWORD_ARM, t, [0.10, 0.07, 0.10, 0.08, 0.10])
	_rot(idle, _SWORD_ELBOW, t, [0.30, 0.27, 0.30, 0.28, 0.30])

	# Шаг: «притоп» — в момент переноса веса корпус проседает,
	# руки качаются в противоход ногам. Цикл нарочито небыстрый.
	var walk := _new_anim(library, &"walk", 0.62, true)
	t = _times([0.0, 0.08, 0.16, 0.24, 0.31, 0.38, 0.46, 0.54, 0.62])
	_rot(walk, _FRONT_HIP, t, [0.42, 0.22, -0.55, -0.72, -0.60, -0.50, -0.30, 0.20, 0.42])
	_rot(walk, _FRONT_KNEE, t, [0.14, 0.35, 1.05, 1.35, 0.85, 0.25, 0.45, 0.75, 0.14])
	_rot(walk, _FRONT_ANKLE, t, [-0.42, -0.20, -0.10, 0.02, -0.05, -0.15, -0.30, -0.50, -0.42])
	_rot(walk, _BACK_HIP, t, [-0.44, -0.30, 0.05, 0.30, 0.55, 0.40, 0.10, -0.30, -0.44])
	_rot(walk, _BACK_KNEE, t, [0.10, 0.30, 0.15, 0.25, 0.55, 1.05, 1.30, 0.70, 0.10])
	_rot(walk, _BACK_ANKLE, t, [-0.14, -0.05, 0.10, 0.05, -0.10, -0.25, -0.35, -0.20, -0.14])
	_pos(walk, _BODY, t, [
		_BODY_HOME + Vector2(0.0, 2.0), _BODY_HOME, _BODY_HOME + Vector2(0.0, 3.5),
		_BODY_HOME + Vector2(0.0, 1.5), _BODY_HOME, _BODY_HOME + Vector2(0.0, 3.5),
		_BODY_HOME + Vector2(0.0, 1.5), _BODY_HOME, _BODY_HOME + Vector2(0.0, 2.0),
	])
	_rot(walk, _SHIELD_SHOULDER, t, [0.55, 0.35, 0.0, -0.30, -0.45, -0.20, 0.25, 0.50, 0.55])
	_rot(walk, _SHIELD_ELBOW, t, [-0.35, -0.30, -0.25, -0.20, -0.25, -0.30, -0.35, -0.40, -0.35])
	_rot(walk, _SWORD_ARM, t, [-0.12, -0.08, 0.05, 0.12, 0.08, -0.02, -0.10, -0.14, -0.12])
	_rot(walk, _SWORD_ELBOW, t, [0.25, 0.22, 0.18, 0.15, 0.18, 0.22, 0.26, 0.28, 0.25])

	# Бег: та же механика шага, шире амплитуда, корпус наклонён вперёд.
	var run := _new_anim(library, &"run", 0.50, true)
	t = _times([0.0, 0.07, 0.13, 0.19, 0.25, 0.31, 0.38, 0.44, 0.50])
	_rot(run, _FRONT_HIP, t, [0.55, 0.30, -0.70, -0.90, -0.75, -0.60, -0.35, 0.30, 0.55])
	_rot(run, _FRONT_KNEE, t, [0.20, 0.55, 1.35, 1.65, 1.05, 0.35, 0.60, 0.95, 0.20])
	_rot(run, _FRONT_ANKLE, t, [-0.50, -0.25, -0.05, 0.10, -0.05, -0.20, -0.40, -0.60, -0.50])
	_rot(run, _BACK_HIP, t, [-0.58, -0.40, 0.10, 0.42, 0.72, 0.50, 0.15, -0.40, -0.58])
	_rot(run, _BACK_KNEE, t, [0.15, 0.40, 0.20, 0.35, 0.75, 1.35, 1.60, 0.85, 0.15])
	_rot(run, _BACK_ANKLE, t, [-0.18, -0.05, 0.15, 0.08, -0.12, -0.30, -0.42, -0.25, -0.18])
	_pos(run, _BODY, t, [
		_BODY_HOME + Vector2(2.0, 2.5), _BODY_HOME + Vector2(2.0, 0.0),
		_BODY_HOME + Vector2(2.0, 5.0), _BODY_HOME + Vector2(2.0, 2.0),
		_BODY_HOME + Vector2(2.0, 0.0), _BODY_HOME + Vector2(2.0, 5.0),
		_BODY_HOME + Vector2(2.0, 2.0), _BODY_HOME + Vector2(2.0, 0.0),
		_BODY_HOME + Vector2(2.0, 2.5),
	])
	_rot(run, _SHIELD_SHOULDER, t, [0.75, 0.45, 0.0, -0.45, -0.65, -0.30, 0.30, 0.65, 0.75])
	_rot(run, _SHIELD_ELBOW, t, [-0.45, -0.40, -0.30, -0.25, -0.30, -0.35, -0.45, -0.50, -0.45])
	_rot(run, _SWORD_ARM, t, [-0.20, -0.10, 0.15, 0.25, 0.15, -0.05, -0.15, -0.25, -0.20])
	_rot(run, _SWORD_ELBOW, t, [0.35, 0.30, 0.22, 0.18, 0.22, 0.28, 0.34, 0.38, 0.35])

	# Спринт: корпус почти лежачий, ноги работают на полшага короче,
	# руки сведены назад — в SAS разгон выглядит тяжёлым, а не лёгким.
	var sprint := _new_anim(library, &"sprint", 0.40, true)
	t = _times([0.0, 0.05, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35, 0.40])
	_rot(sprint, _FRONT_HIP, t, [0.68, 0.40, -0.80, -1.00, -0.85, -0.70, -0.42, 0.35, 0.68])
	_rot(sprint, _FRONT_KNEE, t, [0.25, 0.70, 1.50, 1.80, 1.15, 0.40, 0.70, 1.05, 0.25])
	_rot(sprint, _FRONT_ANKLE, t, [-0.55, -0.28, -0.05, 0.12, -0.05, -0.22, -0.45, -0.65, -0.55])
	_rot(sprint, _BACK_HIP, t, [-0.70, -0.48, 0.12, 0.50, 0.85, 0.58, 0.18, -0.48, -0.70])
	_rot(sprint, _BACK_KNEE, t, [0.18, 0.48, 0.22, 0.40, 0.85, 1.50, 1.78, 0.95, 0.18])
	_rot(sprint, _BACK_ANKLE, t, [-0.20, -0.05, 0.18, 0.10, -0.14, -0.34, -0.48, -0.28, -0.20])
	_pos(sprint, _BODY, t, [
		_BODY_HOME + Vector2(4.0, 3.0), _BODY_HOME + Vector2(4.0, 0.0),
		_BODY_HOME + Vector2(4.0, 5.5), _BODY_HOME + Vector2(4.0, 2.5),
		_BODY_HOME + Vector2(4.0, 0.0), _BODY_HOME + Vector2(4.0, 5.5),
		_BODY_HOME + Vector2(4.0, 2.5), _BODY_HOME + Vector2(4.0, 0.0),
		_BODY_HOME + Vector2(4.0, 3.0),
	])
	_rot(sprint, _SHIELD_SHOULDER, t, [0.95, 0.60, 0.0, -0.55, -0.80, -0.40, 0.35, 0.80, 0.95])
	_rot(sprint, _SHIELD_ELBOW, t, [-0.55, -0.48, -0.35, -0.30, -0.35, -0.42, -0.52, -0.58, -0.55])
	_rot(sprint, _SWORD_ARM, t, [-0.30, -0.15, 0.20, 0.32, 0.20, -0.05, -0.22, -0.35, -0.30])
	_rot(sprint, _SWORD_ELBOW, t, [0.42, 0.36, 0.26, 0.20, 0.26, 0.32, 0.40, 0.45, 0.42])

	# Шаг назад: развёрнутый корпус, ноги ставят пятку раньше носка,
	# руки держат оборону — в SAS отход выглядит осторожно, а не бегом.
	var walk_back := _new_anim(library, &"walk_back", 0.78, true)
	t = _times([0.0, 0.10, 0.20, 0.30, 0.39, 0.49, 0.59, 0.69, 0.78])
	_rot(walk_back, _FRONT_HIP, t, [-0.40, -0.28, 0.10, 0.38, 0.62, 0.40, 0.05, -0.35, -0.40])
	_rot(walk_back, _FRONT_KNEE, t, [0.25, 0.55, 0.35, 0.30, 0.60, 1.15, 1.35, 0.70, 0.25])
	_rot(walk_back, _FRONT_ANKLE, t, [0.10, 0.0, -0.15, -0.25, -0.10, 0.05, 0.15, 0.20, 0.10])
	_rot(walk_back, _BACK_HIP, t, [0.48, 0.30, -0.30, -0.62, -0.55, -0.42, -0.20, 0.25, 0.48])
	_rot(walk_back, _BACK_KNEE, t, [0.18, 0.42, 1.05, 1.30, 0.85, 0.30, 0.50, 0.80, 0.18])
	_rot(walk_back, _BACK_ANKLE, t, [-0.30, -0.12, 0.05, -0.05, -0.15, -0.28, -0.38, -0.35, -0.30])
	_pos(walk_back, _BODY, t, [
		_BODY_HOME + Vector2(-1.5, 1.5), _BODY_HOME + Vector2(-1.5, 0.0),
		_BODY_HOME + Vector2(-1.5, 2.5), _BODY_HOME + Vector2(-1.5, 1.0),
		_BODY_HOME + Vector2(-1.5, 0.0), _BODY_HOME + Vector2(-1.5, 2.5),
		_BODY_HOME + Vector2(-1.5, 1.0), _BODY_HOME + Vector2(-1.5, 0.0),
		_BODY_HOME + Vector2(-1.5, 1.5),
	])
	_rot(walk_back, _SHIELD_SHOULDER, t, [-0.25, -0.30, -0.35, -0.40, -0.35, -0.30, -0.25, -0.22, -0.25])
	_rot(walk_back, _SHIELD_ELBOW, t, [-0.85, -0.88, -0.90, -0.92, -0.90, -0.88, -0.85, -0.84, -0.85])
	_rot(walk_back, _SWORD_ARM, t, [0.05, 0.07, 0.10, 0.12, 0.10, 0.07, 0.05, 0.03, 0.05])
	_rot(walk_back, _SWORD_ELBOW, t, [0.45, 0.46, 0.48, 0.50, 0.48, 0.46, 0.45, 0.44, 0.45])

	# Присед: корпус просел, колени сложены, руки прижаты.
	var crouch := _new_anim(library, &"crouch", 0.3, false)
	t = _times([0.0])
	_rot(crouch, _FRONT_HIP, t, [-0.35])
	_rot(crouch, _FRONT_KNEE, t, [1.30])
	_rot(crouch, _FRONT_ANKLE, t, [-0.60])
	_rot(crouch, _BACK_HIP, t, [0.40])
	_rot(crouch, _BACK_KNEE, t, [1.35])
	_rot(crouch, _BACK_ANKLE, t, [-0.62])
	_pos(crouch, _BODY, t, [_BODY_HOME + Vector2(0.0, 34.0)])
	_rot(crouch, _SHIELD_SHOULDER, t, [0.25])
	_rot(crouch, _SHIELD_ELBOW, t, [-0.75])
	_rot(crouch, _SWORD_ARM, t, [0.20])
	_rot(crouch, _SWORD_ELBOW, t, [0.55])

	# Шаг в приседе: низкий шаркающий шаг, корпус не подпрыгивает.
	var crouch_walk := _new_anim(library, &"crouch_walk", 0.88, true)
	t = _times([0.0, 0.12, 0.22, 0.34, 0.44, 0.56, 0.66, 0.78, 0.88])
	_rot(crouch_walk, _FRONT_HIP, t, [-0.20, -0.30, -0.62, -0.70, -0.55, -0.40, -0.25, -0.10, -0.20])
	_rot(crouch_walk, _FRONT_KNEE, t, [1.15, 1.35, 1.55, 1.40, 1.20, 1.30, 1.45, 1.30, 1.15])
	_rot(crouch_walk, _FRONT_ANKLE, t, [-0.55, -0.40, -0.25, -0.30, -0.42, -0.55, -0.62, -0.58, -0.55])
	_rot(crouch_walk, _BACK_HIP, t, [0.25, 0.35, 0.50, 0.60, 0.42, 0.20, 0.10, 0.18, 0.25])
	_rot(crouch_walk, _BACK_KNEE, t, [1.20, 1.28, 1.15, 1.25, 1.45, 1.55, 1.38, 1.25, 1.20])
	_rot(crouch_walk, _BACK_ANKLE, t, [-0.55, -0.48, -0.35, -0.30, -0.40, -0.52, -0.60, -0.58, -0.55])
	_pos(crouch_walk, _BODY, t, [
		_BODY_HOME + Vector2(0.0, 35.0), _BODY_HOME + Vector2(0.0, 33.0),
		_BODY_HOME + Vector2(0.0, 36.0), _BODY_HOME + Vector2(0.0, 34.0),
		_BODY_HOME + Vector2(0.0, 33.0), _BODY_HOME + Vector2(0.0, 36.0),
		_BODY_HOME + Vector2(0.0, 34.0), _BODY_HOME + Vector2(0.0, 33.0),
		_BODY_HOME + Vector2(0.0, 35.0),
	])
	_rot(crouch_walk, _SHIELD_SHOULDER, t, [0.10, 0.14, 0.18, 0.14, 0.08, 0.05, 0.08, 0.12, 0.10])
	_rot(crouch_walk, _SHIELD_ELBOW, t, [-0.80, -0.78, -0.75, -0.78, -0.82, -0.85, -0.82, -0.80, -0.80])
	_rot(crouch_walk, _SWORD_ARM, t, [0.12, 0.15, 0.18, 0.15, 0.12, 0.10, 0.12, 0.14, 0.12])
	_rot(crouch_walk, _SWORD_ELBOW, t, [0.50, 0.52, 0.55, 0.52, 0.50, 0.48, 0.50, 0.51, 0.50])

	# Прыжок: отталкивание → поджатые ноги в полёте → подготовка к приземлению.
	var jump := _new_anim(library, &"jump", 0.45, false)
	t = _times([0.0, 0.08, 0.20, 0.32, 0.45])
	_rot(jump, _FRONT_HIP, t, [0.20, -0.35, -0.55, -0.30, -0.10])
	_rot(jump, _FRONT_KNEE, t, [0.45, 1.10, 1.45, 0.90, 0.40])
	_rot(jump, _FRONT_ANKLE, t, [-0.30, 0.15, -0.10, -0.30, -0.20])
	_rot(jump, _BACK_HIP, t, [-0.25, 0.35, 0.55, 0.30, 0.10])
	_rot(jump, _BACK_KNEE, t, [0.50, 1.20, 1.50, 1.00, 0.45])
	_rot(jump, _BACK_ANKLE, t, [-0.25, 0.10, -0.05, -0.28, -0.18])
	_pos(jump, _BODY, t, [
		_BODY_HOME + Vector2(0.0, 4.0), _BODY_HOME + Vector2(0.0, -6.0),
		_BODY_HOME + Vector2(0.0, -10.0), _BODY_HOME + Vector2(0.0, -4.0),
		_BODY_HOME,
	])
	_rot(jump, _SHIELD_SHOULDER, t, [0.15, -0.45, -0.75, -0.35, 0.0])
	_rot(jump, _SHIELD_ELBOW, t, [-0.55, -0.35, -0.20, -0.40, -0.55])
	_rot(jump, _SWORD_ARM, t, [0.10, -0.50, -0.85, -0.40, 0.0])
	_rot(jump, _SWORD_ELBOW, t, [0.30, 0.55, 0.75, 0.45, 0.30])

	_add_stagger(library)
	_add_death(library)

	_replace_library(player, library)


## Оглушение: равновесие иссякло. Клип короткий и нециклический —
## последний кадр удерживается, пока poise не восстановится, поэтому
## игрок стоит открытым под казнь (×1.5), а не «дёргается» на лупе.
static func _add_stagger(library: AnimationLibrary) -> void:
	var anim := _new_anim(library, &"stagger", 0.34, false)
	var t := _times([0.0, 0.10, 0.20, 0.34])
	# Колени подкашиваются, таз уходит вниз, корпус клюёт вперёд.
	_rot(anim, _FRONT_HIP, t, [-0.06, -0.30, -0.42, -0.45])
	_rot(anim, _FRONT_KNEE, t, [0.16, 0.70, 1.00, 1.05])
	_rot(anim, _FRONT_ANKLE, t, [-0.10, -0.35, -0.50, -0.52])
	_rot(anim, _BACK_HIP, t, [0.10, 0.35, 0.50, 0.52])
	_rot(anim, _BACK_KNEE, t, [0.20, 0.80, 1.15, 1.20])
	_rot(anim, _BACK_ANKLE, t, [-0.12, -0.38, -0.55, -0.56])
	_pos(anim, _BODY, t, [
		_BODY_HOME, _BODY_HOME + Vector2(2.0, 10.0),
		_BODY_HOME + Vector2(3.5, 16.0), _BODY_HOME + Vector2(4.0, 18.0),
	])
	# Руки безвольно повисают: меч опущен, щит не спасает.
	_rot(anim, _SHIELD_SHOULDER, t, [0.16, 0.70, 1.00, 1.05])
	_rot(anim, _SHIELD_ELBOW, t, [-0.55, -0.20, -0.05, -0.02])
	_rot(anim, _SWORD_ARM, t, [0.10, 0.60, 0.90, 0.95])
	_rot(anim, _SWORD_ELBOW, t, [0.30, 0.10, 0.02, 0.0])
	# Весь риг заваливается вперёд — читаемо даже на маленьком масштабе.
	_rot(anim, _VISUALS, t, [0.0, 0.06, 0.10, 0.11])


## Смерть: тело сгибается и падает на бок, конечности раскидывает.
static func _add_death(library: AnimationLibrary) -> void:
	var anim := _new_anim(library, &"death", 0.9, false)
	var t := _times([0.0, 0.15, 0.40, 0.65, 0.9])
	_rot(anim, _FRONT_HIP, t, [-0.06, -0.30, -0.48, -0.40, -0.38])
	_rot(anim, _FRONT_KNEE, t, [0.16, 0.75, 1.20, 1.05, 1.00])
	_rot(anim, _FRONT_ANKLE, t, [-0.10, -0.40, -0.55, -0.45, -0.42])
	_rot(anim, _BACK_HIP, t, [0.10, 0.40, 0.65, 0.55, 0.52])
	_rot(anim, _BACK_KNEE, t, [0.20, 0.85, 1.40, 1.25, 1.20])
	_rot(anim, _BACK_ANKLE, t, [-0.12, -0.40, -0.50, -0.35, -0.30])
	_pos(anim, _BODY, t, [
		_BODY_HOME, _BODY_HOME + Vector2(2.0, 8.0), _BODY_HOME + Vector2(5.0, 20.0),
		_BODY_HOME + Vector2(7.0, 28.0), _BODY_HOME + Vector2(7.5, 30.0),
	])
	_rot(anim, _SHIELD_SHOULDER, t, [0.16, 0.60, 1.10, 1.35, 1.40])
	_rot(anim, _SHIELD_ELBOW, t, [-0.55, -0.25, 0.05, 0.20, 0.22])
	_rot(anim, _SWORD_ARM, t, [0.10, 0.55, 1.05, 1.30, 1.35])
	_rot(anim, _SWORD_ELBOW, t, [0.30, 0.10, -0.10, -0.20, -0.22])
	# Падение на бок: поворот всего рига и проседание к земле.
	_rot(anim, _VISUALS, t, [0.0, 0.25, 0.95, 1.35, 1.45])
	_pos(anim, _VISUALS, t, [
		Vector2.ZERO, Vector2(0.0, 4.0), Vector2(-2.0, 12.0),
		Vector2(-4.0, 16.0), Vector2(-4.5, 17.0),
	])


static func _add_locomotion_reset(library: AnimationLibrary) -> void:
	var anim := _new_anim(library, &"RESET", 0.1, false)
	var t := _times([0.0])
	_rot(anim, _FRONT_HIP, t, [0.0])
	_rot(anim, _FRONT_KNEE, t, [0.0])
	_rot(anim, _FRONT_ANKLE, t, [0.0])
	_rot(anim, _BACK_HIP, t, [0.0])
	_rot(anim, _BACK_KNEE, t, [0.0])
	_rot(anim, _BACK_ANKLE, t, [0.0])
	_pos(anim, _BODY, t, [_BODY_HOME])
	_rot(anim, _SHIELD_SHOULDER, t, [0.0])
	_rot(anim, _SHIELD_ELBOW, t, [0.0])
	_rot(anim, _SWORD_ARM, t, [0.0])
	_rot(anim, _SWORD_ELBOW, t, [0.0])
	_pos(anim, _VISUALS, t, [Vector2.ZERO])
	_rot(anim, _VISUALS, t, [0.0])


# ══════════════════════════════════════════════════════════════════
#  AttackPlayer: комбо, двуручные, щит, жесты
# ══════════════════════════════════════════════════════════════════

static func install_attack(player: AnimationPlayer) -> void:
	# См. install_locomotion: запечённые в сцене клипы не затираем.
	if player.has_animation_library(&""):
		return

	var library := AnimationLibrary.new()

	_add_attack_reset(library)

	# Одноручные удары. Пик замаха (момент, когда клинок идёт через
	# цель) ставится ровно на HIT_DELAY_* — в этот момент player.gd
	# включает хитбокс, поэтому взмах и урон не расходятся.
	_add_swing(library, &"attack_1", HIT_DELAY_1, 0.46, _swing_one_handed())
	_add_swing(library, &"attack_2", HIT_DELAY_2, 0.40, _swing_slash())
	_add_swing(library, &"attack_3", HIT_DELAY_3, 0.62, _swing_heavy())

	# Двуручные: те же окна урона, но занос обеими руками и шире пронос.
	_add_swing(library, &"two_handed_1", HIT_DELAY_1, 0.54, _swing_two_handed_1())
	_add_swing(library, &"two_handed_2", HIT_DELAY_2, 0.48, _swing_two_handed_2())
	_add_swing(library, &"two_handed_3", HIT_DELAY_3, 0.68, _swing_two_handed_3())

	_add_block(library)
	_add_fist_combat(library)
	_add_interact(library)
	_add_inventory_loop(library)

	_replace_library(player, library)


## Дозаполняет уже запечённую в сцене библиотеку кулачными клипами.
## Нужен для сцен, собранных до появления кулачного боя: пока хотя бы
## один клип отсутствует, генератор добавляет недостающие. Как только
## все три оказываются в .tscn, метод ничего не трогает — правки
## ключей в редакторе сохраняются.
static func ensure_fist_combat(player: AnimationPlayer) -> void:
	if player == null or not player.has_animation_library(&""):
		return

	var library: AnimationLibrary = player.get_animation_library(&"")
	var missing: Array[StringName] = []
	for name: StringName in [&"fist_right", &"fist_left", &"fist_block"]:
		if not library.has_animation(name):
			missing.append(name)
	if missing.is_empty():
		return

	var generated := AnimationLibrary.new()
	_add_fist_combat(generated)
	for name: StringName in missing:
		if generated.has_animation(name):
			library.add_animation(name, generated.get_animation(name))


## Дозаполняет недостающий клип оглушения в уже запечённой библиотеке
## LocomotionPlayer. Аналог ensure_fist_combat: существующие клипы не
## затираются, поэтому ручные правки ключей в редакторе сохраняются.
static func ensure_stagger(player: AnimationPlayer) -> void:
	if player == null or not player.has_animation_library(&""):
		return
	var library: AnimationLibrary = player.get_animation_library(&"")
	if library.has_animation(&"stagger"):
		return

	var generated := AnimationLibrary.new()
	_add_stagger(generated)
	if generated.has_animation(&"stagger"):
		library.add_animation(&"stagger", generated.get_animation(&"stagger"))


## Один удар в SAS-ритме: длинный занос → короткий мощный пронос →
## вязкое восстановление. last_key удерживает 0, поэтому по завершении
## клипа руки возвращаются в стойку сами.
static func _add_swing(
	library: AnimationLibrary,
	name: StringName,
	hit_delay: float,
	total: float,
	pose: Dictionary
) -> void:
	var anim := _new_anim(library, name, total, false)

	# Кадры: покой → середина заноса → пик заноса (чуть раньше удара)
	# → момент касания → пронос → возврат.
	var windup_mid := hit_delay * 0.55
	var windup_peak := hit_delay * 0.92
	var follow := minf(hit_delay + total * 0.16, total * 0.72)
	var t := _times([0.0, windup_mid, windup_peak, hit_delay, follow, total])

	var arm: Array = pose["arm"]
	var elbow: Array = pose["elbow"]
	var shield: Array = pose["shield"]
	var shield_elbow: Array = pose["shield_elbow"]
	var shift: Array = pose["shift"]

	_rot(anim, _SWORD_ARM, t, [0.0, arm[1], arm[2], arm[3], arm[4], 0.0])
	_rot(anim, _SWORD_ELBOW, t, [0.0, elbow[1], elbow[2], elbow[3], elbow[4], 0.0])
	_pos_sword(anim, t, [
		Vector2.ZERO, shift[1], shift[2], shift[3], shift[4], Vector2.ZERO,
	])
	_rot(anim, _SHIELD_SHOULDER, t, [0.0, shield[1], shield[2], shield[3], shield[4], 0.0])
	_rot(anim, _SHIELD_ELBOW, t, [0.0, shield_elbow[1], shield_elbow[2], shield_elbow[3], shield_elbow[4], 0.0])


## Заготовки поз: [покой, занос-середина, занос-пик, касание, пронос].
## Значения «на глаз» откалиброваны под геометрию рига: отрицательный
## rotation FrontArmAttack поднимает клинок назад-вверх, положительный
## опускает вперёд-вниз, локоть всегда согнут в заносе и выпрямлен в ударе.
static func _swing_one_handed() -> Dictionary:
	return {
		"arm": [0.0, -0.85, -1.45, -1.35, 0.55],
		"elbow": [0.0, 0.35, 0.80, 0.15, -0.25],
		"shield": [0.0, -0.20, -0.38, 0.15, 0.45],
		"shield_elbow": [0.0, -0.30, -0.45, -0.20, -0.10],
		"shift": [
			Vector2.ZERO, Vector2(-1.0, -2.0), Vector2(-2.5, -3.5),
			Vector2(1.5, 1.0), Vector2(3.0, 2.5),
		],
	}


static func _swing_slash() -> Dictionary:
	return {
		"arm": [0.0, -1.10, -1.70, -1.60, 0.70],
		"elbow": [0.0, 0.15, 0.55, 0.05, -0.30],
		"shield": [0.0, -0.30, -0.55, 0.20, 0.55],
		"shield_elbow": [0.0, -0.25, -0.40, -0.15, -0.05],
		"shift": [
			Vector2.ZERO, Vector2(-1.5, -2.5), Vector2(-2.0, -4.5),
			Vector2(0.5, 2.0), Vector2(1.5, 4.0),
		],
	}


static func _swing_heavy() -> Dictionary:
	return {
		"arm": [0.0, -1.25, -2.35, -2.20, 1.20],
		"elbow": [0.0, 0.55, 1.05, 0.20, -0.45],
		"shield": [0.0, -0.45, -0.85, 0.35, 0.90],
		"shield_elbow": [0.0, -0.20, -0.35, -0.10, 0.0],
		"shift": [
			Vector2.ZERO, Vector2(-2.5, -3.5), Vector2(-4.0, -6.0),
			Vector2(2.0, 3.0), Vector2(5.0, 6.0),
		],
	}


static func _swing_two_handed_1() -> Dictionary:
	return {
		"arm": [0.0, -1.30, -2.15, -2.05, 0.95],
		"elbow": [0.0, 0.45, 0.95, 0.25, -0.30],
		"shield": [0.0, -1.05, -1.75, -1.60, 0.80],
		"shield_elbow": [0.0, 0.35, 0.75, 0.20, -0.20],
		"shift": [
			Vector2.ZERO, Vector2(-2.0, -3.0), Vector2(-3.5, -5.0),
			Vector2(2.0, 2.0), Vector2(4.0, 4.0),
		],
	}


static func _swing_two_handed_2() -> Dictionary:
	return {
		"arm": [0.0, 0.90, 1.55, 1.45, -1.60],
		"elbow": [0.0, -0.35, -0.65, -0.15, 0.45],
		"shield": [0.0, 1.05, 1.70, 1.55, -1.30],
		"shield_elbow": [0.0, -0.55, -1.05, -0.35, 0.30],
		"shift": [
			Vector2.ZERO, Vector2(-1.0, 2.5), Vector2(-1.5, 4.5),
			Vector2(1.5, -2.5), Vector2(3.0, -5.0),
		],
	}


static func _swing_two_handed_3() -> Dictionary:
	return {
		"arm": [0.0, -1.55, -2.55, -2.40, 1.35],
		"elbow": [0.0, 0.60, 1.10, 0.30, -0.50],
		"shield": [0.0, -1.35, -2.25, -2.10, 1.15],
		"shield_elbow": [0.0, 0.50, 0.95, 0.25, -0.35],
		"shift": [
			Vector2.ZERO, Vector2(-3.0, -3.5), Vector2(-5.0, -6.5),
			Vector2(3.0, 3.5), Vector2(6.0, 6.5),
		],
	}


## Подъём щита: короткая поза, последний кадр удерживается всё время,
## пока удерживается ПКМ (см. _update_block_animation в player.gd).
static func _add_block(library: AnimationLibrary) -> void:
	var anim := _new_anim(library, &"block", 0.25, false)
	var t := _times([0.0, 0.14, 0.25])
	_rot(anim, _SHIELD_SHOULDER, t, [0.0, -1.50, -1.32])
	_rot(anim, _SHIELD_ELBOW, t, [0.0, 1.72, 1.58])
	_scale(anim, _SHIELD_WRIST, t, [Vector2.ONE, Vector2(1.08, 1.08), Vector2(1.05, 1.05)])
	_rot(anim, _SWORD_ARM, t, [0.0, -0.48, -0.36])
	_rot(anim, _SWORD_ELBOW, t, [0.0, 0.68, 0.58])
	_pos_sword(anim, t, [Vector2.ZERO, Vector2(-1.0, -1.0), Vector2(-1.0, -0.5)])


## Кулачный бой: правый прямой, левый прямой и блок скрещёнными
## руками. Играется, когда оба слота рук пусты (см. _is_unarmed()
## в player.gd). Момент касания у правого — HIT_DELAY_1, у левого —
## HIT_DELAY_2: player.gd включает хитбокс по имени клипа, поэтому
## тайминги обязаны совпадать с _get_attack_hit_delay_for().
## Клипы обычные, как и все остальные, — правятся ключами в редакторе.
static func _add_fist_combat(library: AnimationLibrary) -> void:
	# Правый прямой: задняя рука (FrontArmAttack) доносит кулак до цели.
	var right := _new_anim(library, &"fist_right", 0.42, false)
	var t := _times([0.0, 0.12, 0.20, HIT_DELAY_1, 0.32, 0.42])
	_rot(right, _SWORD_ARM, t, [0.0, -0.55, -0.95, 0.35, 0.15, 0.0])
	_rot(right, _SWORD_ELBOW, t, [0.0, 0.85, 1.15, -0.10, 0.10, 0.0])
	_pos_sword(right, t, [
		Vector2.ZERO, Vector2(-1.5, -1.0), Vector2(-2.5, -1.5),
		Vector2(2.5, 0.5), Vector2(1.0, 0.5), Vector2.ZERO,
	])
	# Левая рука инстинктивно уходит к подбородку — защита лица.
	_rot(right, _SHIELD_SHOULDER, t, [0.0, -0.35, -0.50, -0.55, -0.40, 0.0])
	_rot(right, _SHIELD_ELBOW, t, [0.0, 0.90, 1.25, 1.35, 1.05, 0.0])

	# Левый прямой: зеркальный удар дальней (BackShoulder) рукой,
	# чуть быстрее — в комбо он идёт вторым номером.
	var left := _new_anim(library, &"fist_left", 0.38, false)
	t = _times([0.0, 0.10, 0.16, HIT_DELAY_2, 0.28, 0.38])
	_rot(left, _SHIELD_SHOULDER, t, [0.0, -0.50, -0.90, 0.40, 0.18, 0.0])
	_rot(left, _SHIELD_ELBOW, t, [0.0, 0.80, 1.10, -0.08, 0.12, 0.0])
	# Правая рука держит гард.
	_rot(left, _SWORD_ARM, t, [0.0, -0.30, -0.45, -0.50, -0.35, 0.0])
	_rot(left, _SWORD_ELBOW, t, [0.0, 0.85, 1.20, 1.30, 1.00, 0.0])

	# Блок скрещёнными руками: предплечья вертикально перед лицом,
	# последний кадр удерживается, пока зажата кнопка блока.
	var guard := _new_anim(library, &"fist_block", 0.2, false)
	t = _times([0.0, 0.12, 0.2])
	_rot(guard, _SWORD_ARM, t, [0.0, -1.15, -1.05])
	_rot(guard, _SWORD_ELBOW, t, [0.0, 1.85, 1.72])
	_pos_sword(guard, t, [Vector2.ZERO, Vector2(1.5, -1.0), Vector2(1.0, -0.6)])
	_rot(guard, _SHIELD_SHOULDER, t, [0.0, -1.35, -1.25])
	_rot(guard, _SHIELD_ELBOW, t, [0.0, 1.95, 1.82])
	_scale(guard, _SHIELD_WRIST, t, [Vector2.ONE, Vector2(1.06, 1.06), Vector2(1.04, 1.04)])


## Жест взаимодействия: протянуть руку к сундуку/костру.
static func _add_interact(library: AnimationLibrary) -> void:
	var anim := _new_anim(library, &"interact", 0.55, false)
	var t := _times([0.0, 0.16, 0.32, 0.55])
	_rot(anim, _SWORD_ARM, t, [0.0, -1.30, -1.10, 0.0])
	_rot(anim, _SWORD_ELBOW, t, [0.0, 0.30, 0.18, 0.0])
	_pos_sword(anim, t, [
		Vector2.ZERO, Vector2(4.0, -2.0), Vector2(6.0, -1.0), Vector2.ZERO,
	])
	_rot(anim, _SHIELD_SHOULDER, t, [0.0, 0.28, 0.20, 0.0])
	_rot(anim, _SHIELD_ELBOW, t, [0.0, -0.15, -0.10, 0.0])
	_scale(anim, _SHIELD_WRIST, t, [Vector2.ONE, Vector2.ONE, Vector2.ONE, Vector2.ONE])


## Стойка при открытом инвентаре: руки держат разложенную сумку,
## корпус слегка подан вперёд, лёгкое покачивание вместо дыхания.
static func _add_inventory_loop(library: AnimationLibrary) -> void:
	var anim := _new_anim(library, &"inventory_loop", 2.6, true)
	var t := _times([0.0, 0.65, 1.3, 1.95, 2.6])
	_rot(anim, _SWORD_ARM, t, [-0.95, -0.86, -0.95, -1.04, -0.95])
	_rot(anim, _SWORD_ELBOW, t, [0.98, 0.88, 0.98, 1.08, 0.98])
	_rot(anim, _SHIELD_SHOULDER, t, [-0.72, -0.62, -0.72, -0.82, -0.72])
	_rot(anim, _SHIELD_ELBOW, t, [1.18, 1.08, 1.18, 1.28, 1.18])
	_pos_sword(anim, t, [
		Vector2.ZERO, Vector2(0.5, 0.5), Vector2.ZERO,
		Vector2(-0.5, 1.0), Vector2.ZERO,
	])
	_scale(anim, _SHIELD_WRIST, t, [Vector2.ONE, Vector2.ONE, Vector2.ONE, Vector2.ONE, Vector2.ONE])


static func _add_attack_reset(library: AnimationLibrary) -> void:
	var anim := _new_anim(library, &"RESET", 0.1, false)
	var t := _times([0.0])
	_rot(anim, _SWORD_ARM, t, [0.0])
	_rot(anim, _SWORD_ELBOW, t, [0.0])
	_pos_sword(anim, t, [Vector2.ZERO])
	_rot(anim, _SHIELD_SHOULDER, t, [0.0])
	_rot(anim, _SHIELD_ELBOW, t, [0.0])
	_scale(anim, _SHIELD_WRIST, t, [Vector2.ONE])


# ══════════════════════════════════════════════════════════════════
#  SecondaryMotionPlayer: дыхание и вторичное движение
# ══════════════════════════════════════════════════════════════════

## Единственный владелец BodyBreath:scale и HeadBreath:position.
## player.gd крутит частоту этого клипа через speed_scale
## (idle_breath_speed / walk_breath_speed / air_breath_speed), поэтому
## здесь задаётся только «форма» вдоха, а не темп.
static func install_secondary_motion(player: AnimationPlayer) -> void:
	# См. install_locomotion: запечённые в сцене клипы не затираем.
	if player.has_animation_library(&""):
		return

	var library := AnimationLibrary.new()

	var reset := _new_anim(library, &"RESET", 0.1, false)
	var t := _times([0.0])
	_scale(reset, _SEC_BODY, t, [Vector2.ONE])
	_pos(reset, _SEC_HEAD, t, [Vector2.ZERO])
	_rot(reset, _SEC_FRONT_HIP, t, [0.0])
	_rot(reset, _SEC_FRONT_KNEE, t, [0.0])
	_rot(reset, _SEC_BACK_HIP, t, [0.0])
	_rot(reset, _SEC_BACK_KNEE, t, [0.0])

	# Тяжёлый вдох рыцаря: длинная задержка на набитых лёгких и
	# быстрый спуск — в SAS дыхание ощущается как работа под весом брони.
	var life := _new_anim(library, &"life_loop", 2.4, true)
	t = _times([0.0, 0.85, 1.25, 1.9, 2.4])
	_scale(life, _SEC_BODY, t, [
		Vector2.ONE, Vector2(1.014, 1.028), Vector2(1.014, 1.028),
		Vector2(0.998, 0.996), Vector2.ONE,
	])
	# Голова клюёт вниз на вдохе и чуть подскакивает на выдохе.
	_pos(life, _SEC_HEAD, t, [
		Vector2.ZERO, Vector2(0.0, -1.1), Vector2(0.0, -1.0),
		Vector2(0.0, 0.4), Vector2.ZERO,
	])
	# Таз и колени реагируют на вдох: почти незаметный перенос веса.
	_rot(life, _SEC_BACK_HIP, t, [-0.018, 0.0, 0.006, -0.010, -0.018])
	_rot(life, _SEC_BACK_KNEE, t, [0.044, 0.010, 0.020, 0.050, 0.044])
	_rot(life, _SEC_FRONT_HIP, t, [-0.014, 0.004, 0.0, -0.008, -0.014])
	_rot(life, _SEC_FRONT_KNEE, t, [0.035, 0.008, 0.016, 0.040, 0.035])

	_replace_library(player, library)


# ══════════════════════════════════════════════════════════════════
#  Утилиты
# ══════════════════════════════════════════════════════════════════

## Полностью заменяет безымянную библиотеку плеера. Старые клипы,
## записанные в player.tscn редактором, затираются: иначе в инспекторе
## остались бы мёртвые анимации, которые больше никто не играет.
static func _replace_library(player: AnimationPlayer, library: AnimationLibrary) -> void:
	player.stop()
	if player.has_animation_library(&""):
		player.remove_animation_library(&"")
	player.add_animation_library(&"", library)


static func _new_anim(
	library: AnimationLibrary,
	name: StringName,
	length: float,
	looped: bool
) -> Animation:
	var anim := Animation.new()
	anim.length = length
	anim.step = 0.01
	if looped:
		anim.loop_mode = Animation.LOOP_LINEAR
	library.add_animation(name, anim)
	return anim


static func _times(values: Array) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	for value: Variant in values:
		result.append(float(value))
	return result


static func _track(
	anim: Animation,
	path: String,
	property: String,
	times: PackedFloat32Array,
	values: Array
) -> void:
	var index: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(index, NodePath(path + ":" + property))
	# Сглаживание по умолчанию: cubic. Линейные интервалы делают
	# «деревянные» взмахи, а SAS-анимация держится именно на easing.
	anim.track_set_interpolation_type(index, Animation.INTERPOLATION_CUBIC)
	for key: int in range(times.size()):
		anim.track_insert_key(index, times[key], values[key])


static func _rot(anim: Animation, path: String, times: PackedFloat32Array, values: Array) -> void:
	_track(anim, path, "rotation", times, values)


static func _pos(anim: Animation, path: String, times: PackedFloat32Array, values: Array) -> void:
	_track(anim, path, "position", times, values)


## Position-треки руки с оружием. Позиция BackShoulder абсолютна
## (_SWORD_ARM_HOME), тогда как у прежней FrontArmAttack дом был (0,0).
## Все позы описаны как смещения от стойки, поэтому сюда добавляется дом.
static func _pos_sword(anim: Animation, times: PackedFloat32Array, values: Array) -> void:
	var shifted: Array = []
	for value: Variant in values:
		shifted.append(value as Vector2 + _SWORD_ARM_HOME)
	_track(anim, _SWORD_ARM, "position", times, shifted)


static func _scale(anim: Animation, path: String, times: PackedFloat32Array, values: Array) -> void:
	_track(anim, path, "scale", times, values)
