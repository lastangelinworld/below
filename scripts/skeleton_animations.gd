class_name SkeletonAnimations
extends RefCounted

## Библиотека анимаций скелета, собираемая кодом (Этап C плана
## docs/PLAN_SKELETON_ANIMATION.md). Анимации крутят rotation/position
## пивотов рига в data/world/skeleton.tscn — тот же принцип, что
## LocomotionPlayer/AttackPlayer игрока.
##
## Длительности windup/swing — «номинальные»; skeleton.gd подгоняет
## их через speed_scale под экспорт-таймеры Фазы 7, поэтому тайминги
## боя живут только в skeleton.gd.

## Номинальная длительность лёгкого замаха (совпадает с экспортом).
const LIGHT_WINDUP_LEN: float = 0.4
## Номинальная длительность лёгкого взмаха (= HIT_ACTIVE_SEC).
const LIGHT_SWING_LEN: float = 0.12
## Номинальная длительность тяжёлого замаха.
const HEAVY_WINDUP_LEN: float = 0.6
## Номинальная длительность тяжёлого взмаха (чуть длиннее лёгкого).
const HEAVY_SWING_LEN: float = 0.14
## Номинальное натяжение лука.
const DRAW_LEN: float = 0.45
## Отпускание тетивы.
const RELEASE_LEN: float = 0.15
## Подъём щита (поза-холд).
const BLOCK_LEN: float = 0.25
## Падение в стаггер (поза-холд).
const STAGGER_LEN: float = 0.3
## Падение наземь при смерти.
const DEATH_LEN: float = 0.6

const _RIG: String = "Visuals/Rig"
const _HIPS: String = "Visuals/Rig/Hips"
const _SPINE: String = "Visuals/Rig/Hips/Spine"
const _NECK: String = "Visuals/Rig/Hips/Spine/Neck"
const _SH_F: String = "Visuals/Rig/Hips/Spine/ShoulderFront"
const _EL_F: String = "Visuals/Rig/Hips/Spine/ShoulderFront/ElbowFront"
const _WR_F: String = "Visuals/Rig/Hips/Spine/ShoulderFront/ElbowFront/WristFront"
const _SH_B: String = "Visuals/Rig/Hips/Spine/ShoulderBack"
const _EL_B: String = "Visuals/Rig/Hips/Spine/ShoulderBack/ElbowBack"
const _TH_F: String = "Visuals/Rig/ThighFront"
const _KN_F: String = "Visuals/Rig/ThighFront/KneeFront"
const _AN_F: String = "Visuals/Rig/ThighFront/KneeFront/AnkleFront"
const _TH_B: String = "Visuals/Rig/ThighBack"
const _KN_B: String = "Visuals/Rig/ThighBack/KneeBack"
const _AN_B: String = "Visuals/Rig/ThighBack/KneeBack/AnkleBack"
const _STRING: String = _WR_F + "/Bow/StringSprite"


## Заполняет player всеми анимациями скелета. Повторный вызов безопасен.
## В Godot 4 клипы живут в AnimationLibrary: собираем безымянную
## библиотеку целиком и регистрируем её одной операцией.
static func install(player: AnimationPlayer) -> void:
	if player.has_animation(&"idle"):
		return

	var library := AnimationLibrary.new()
	_add_idle(library)
	_add_walk(library)
	_add_light_attack(library)
	_add_heavy_attack(library)
	_add_block(library)
	_add_bow(library)
	_add_stagger(library)
	_add_death(library)
	_add_reset(library)
	player.add_animation_library(&"", library)


static func _new_anim(library: AnimationLibrary, name: StringName, length: float, looped: bool) -> Animation:
	var anim: Animation = Animation.new()
	anim.length = length
	if looped:
		anim.loop_mode = Animation.LOOP_LINEAR
	library.add_animation(name, anim)
	return anim


## Один keyframe-трек значения по пути "node:property".
static func _track(anim: Animation, path: String, property: String, times: PackedFloat32Array, values: Array) -> void:
	var index: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(index, NodePath(path + ":" + property))
	for key: int in range(times.size()):
		anim.track_insert_key(index, times[key], values[key])


static func _rot(anim: Animation, path: String, times: PackedFloat32Array, values: Array) -> void:
	_track(anim, path, "rotation", times, values)


static func _pos(anim: Animation, path: String, times: PackedFloat32Array, values: Array) -> void:
	_track(anim, path, "position", times, values)


## Покой: дыхание — корпус, голова и руки едва заметно ходят ходуном,
## пустые глазницы чуть клевать носом: скелет «стоит на посту».
static func _add_idle(library: AnimationLibrary) -> void:
	var anim: Animation = _new_anim(library, &"idle", 2.4, true)
	var t: PackedFloat32Array = PackedFloat32Array([0.0, 0.6, 1.2, 1.8, 2.4])
	_pos(anim, _RIG, t, [
		Vector2(0.0, 0.0), Vector2(0.0, -0.35), Vector2(0.0, 0.0),
		Vector2(0.0, -0.35), Vector2(0.0, 0.0),
	])
	_rot(anim, _SPINE, t, [0.0, -0.035, 0.0, -0.035, 0.0])
	_rot(anim, _NECK, t, [0.03, -0.04, 0.03, -0.04, 0.03])
	_rot(anim, _SH_F, t, [0.08, 0.02, 0.08, 0.02, 0.08])
	_rot(anim, _SH_B, t, [-0.06, 0.0, -0.06, 0.0, -0.06])
	_rot(anim, _EL_F, t, [-0.25, -0.18, -0.25, -0.18, -0.25])


## Ходьба: шаркающий противофазный шаг, колени подгибаются сзади,
## руки раскачиваются в противоход ногам (как у игрока в walk).
static func _add_walk(library: AnimationLibrary) -> void:
	var anim: Animation = _new_anim(library, &"walk", 0.72, true)
	var t: PackedFloat32Array = PackedFloat32Array([0.0, 0.18, 0.36, 0.54, 0.72])
	# Передняя нога: вперёд-назад; задняя — в противофазе.
	_rot(anim, _TH_F, t, [0.52, 0.0, -0.5, 0.0, 0.52])
	_rot(anim, _KN_F, t, [0.12, 0.55, 0.18, 0.85, 0.12])
	_rot(anim, _AN_F, t, [-0.15, 0.1, 0.2, 0.0, -0.15])
	_rot(anim, _TH_B, t, [-0.5, 0.0, 0.52, 0.0, -0.5])
	_rot(anim, _KN_B, t, [0.18, 0.85, 0.12, 0.55, 0.18])
	_rot(anim, _AN_B, t, [0.2, 0.0, -0.15, 0.1, 0.2])
	# Корпус: покачивание и лёгкий разворот плеч.
	_pos(anim, _RIG, t, [
		Vector2(0.0, -0.3), Vector2(0.0, 0.15), Vector2(0.0, -0.3),
		Vector2(0.0, 0.15), Vector2(0.0, -0.3),
	])
	_rot(anim, _SPINE, t, [0.06, 0.02, 0.06, 0.02, 0.06])
	_rot(anim, _SH_F, t, [-0.34, 0.0, 0.3, 0.0, -0.34])
	_rot(anim, _SH_B, t, [0.3, 0.0, -0.34, 0.0, 0.3])
	_rot(anim, _EL_F, t, [-0.3, -0.2, -0.3, -0.2, -0.3])
	_rot(anim, _EL_B, t, [-0.3, -0.2, -0.3, -0.2, -0.3])


## Лёгкий удар: короткий занос клинка назад-вверх (парируемое окно),
## затем резкий горизонтальный рубок с проносом корпуса вперёд.
static func _add_light_attack(library: AnimationLibrary) -> void:
	var windup: Animation = _new_anim(library, &"light_windup", LIGHT_WINDUP_LEN, false)
	var t: PackedFloat32Array = PackedFloat32Array([0.0, 0.28, LIGHT_WINDUP_LEN])
	_rot(windup, _SH_F, t, [0.0, -1.7, -2.3])
	_rot(windup, _EL_F, t, [-0.25, -0.8, -1.05])
	_rot(windup, _SPINE, t, [0.0, -0.1, -0.16])
	_rot(windup, _NECK, t, [0.0, -0.08, -0.12])
	_rot(windup, _SH_B, t, [0.0, 0.25, 0.4])

	var swing: Animation = _new_anim(library, &"light_swing", LIGHT_SWING_LEN, false)
	t = PackedFloat32Array([0.0, 0.05, LIGHT_SWING_LEN])
	_rot(swing, _SH_F, t, [-2.3, -0.4, 0.75])
	_rot(swing, _EL_F, t, [-1.05, -0.35, -0.05])
	_rot(swing, _SPINE, t, [-0.16, 0.05, 0.22])
	_rot(swing, _NECK, t, [-0.12, 0.0, 0.1])
	_rot(swing, _SH_B, t, [0.4, 0.1, -0.3])


## Тяжёлый удар: длинный замах ОБЕИМИ руками над головой, корпус
## отклоняется назад (читается издалека), затем рубящий сверху вниз
## с сильным наклоном вперёд — «дубина падает на череп».
static func _add_heavy_attack(library: AnimationLibrary) -> void:
	var windup: Animation = _new_anim(library, &"heavy_windup", HEAVY_WINDUP_LEN, false)
	var t: PackedFloat32Array = PackedFloat32Array([0.0, 0.42, HEAVY_WINDUP_LEN])
	_rot(windup, _SH_F, t, [0.0, -2.1, -2.7])
	_rot(windup, _EL_F, t, [-0.25, -0.7, -0.9])
	_rot(windup, _SH_B, t, [0.0, -1.6, -2.15])
	_rot(windup, _EL_B, t, [-0.2, -0.8, -1.1])
	_rot(windup, _SPINE, t, [0.0, 0.14, 0.24])
	_rot(windup, _NECK, t, [0.0, 0.18, 0.3])
	_pos(windup, _RIG, t, [Vector2(0.0, 0.0), Vector2(0.0, 0.6), Vector2(0.0, 1.0)])
	_rot(windup, _KN_F, t, [0.0, 0.12, 0.2])
	_rot(windup, _KN_B, t, [0.0, 0.12, 0.2])

	var swing: Animation = _new_anim(library, &"heavy_swing", HEAVY_SWING_LEN, false)
	t = PackedFloat32Array([0.0, 0.06, HEAVY_SWING_LEN])
	_rot(swing, _SH_F, t, [-2.7, -0.6, 1.35])
	_rot(swing, _EL_F, t, [-0.9, -0.3, 0.0])
	_rot(swing, _SH_B, t, [-2.15, -0.4, 1.1])
	_rot(swing, _EL_B, t, [-1.1, -0.4, -0.1])
	_rot(swing, _SPINE, t, [0.24, -0.18, -0.45])
	_rot(swing, _NECK, t, [0.3, 0.0, -0.25])
	_pos(swing, _RIG, t, [Vector2(0.0, 1.0), Vector2(0.0, 0.2), Vector2(0.0, -0.4)])


## Подъём щита: задняя рука закрывает корпус, передняя отводит меч
## в полуготовность. Поза удерживается (block_loops не нужен:
## скелет недолго стоит под щитом).
static func _add_block(library: AnimationLibrary) -> void:
	var anim: Animation = _new_anim(library, &"block", BLOCK_LEN, false)
	var t: PackedFloat32Array = PackedFloat32Array([0.0, BLOCK_LEN])
	_rot(anim, _SH_B, t, [0.0, -1.25])
	_rot(anim, _EL_B, t, [-0.2, -1.55])
	_rot(anim, _SH_F, t, [0.0, -0.5])
	_rot(anim, _EL_F, t, [-0.25, -0.7])
	_rot(anim, _SPINE, t, [0.0, -0.06])
	_pos(anim, _RIG, t, [Vector2(0.0, 0.0), Vector2(-0.6, 0.4)])


## Лук: натяжение — передняя рука вытягивает лук вперёд, задняя тянет
## тетиву к «лицу»; тетива (StringSprite) уезжает назад.
## Release — резкий отпуск с отдачей.
static func _add_bow(library: AnimationLibrary) -> void:
	var draw: Animation = _new_anim(library, &"bow_draw", DRAW_LEN, false)
	var t: PackedFloat32Array = PackedFloat32Array([0.0, 0.22, DRAW_LEN])
	_rot(draw, _SH_F, t, [0.0, -1.25, -1.5])
	_rot(draw, _EL_F, t, [-0.25, -0.1, -0.02])
	_rot(draw, _SH_B, t, [0.0, -0.85, -1.15])
	_rot(draw, _EL_B, t, [-0.2, -1.2, -1.55])
	_rot(draw, _SPINE, t, [0.0, -0.06, -0.1])
	_rot(draw, _NECK, t, [0.0, -0.1, -0.16])
	_pos(draw, _STRING, t, [
		Vector2(-0.6, 0.0), Vector2(-2.0, 0.0), Vector2(-3.2, 0.0),
	])

	var release: Animation = _new_anim(library, &"bow_release", RELEASE_LEN, false)
	t = PackedFloat32Array([0.0, RELEASE_LEN])
	_rot(release, _SH_B, t, [-1.15, -0.15])
	_rot(release, _EL_B, t, [-1.55, -0.35])
	_rot(release, _SH_F, t, [-1.5, -1.35])
	_pos(release, _STRING, t, [Vector2(-3.2, 0.0), Vector2(-0.6, 0.0)])


## Стаггер: колени подкашиваются, корпус клюёт вперёд, руки безвольно
## свешиваются — открытая позиция под казнь (×1.5).
static func _add_stagger(library: AnimationLibrary) -> void:
	var anim: Animation = _new_anim(library, &"stagger", STAGGER_LEN, false)
	var t: PackedFloat32Array = PackedFloat32Array([0.0, 0.12, STAGGER_LEN])
	_rot(anim, _SPINE, t, [0.0, 0.45, 0.55])
	_rot(anim, _NECK, t, [0.0, 0.4, 0.5])
	_rot(anim, _SH_F, t, [0.0, 0.45, 0.6])
	_rot(anim, _EL_F, t, [-0.25, -0.1, -0.05])
	_rot(anim, _SH_B, t, [0.0, 0.5, 0.65])
	_rot(anim, _EL_B, t, [-0.2, -0.1, -0.05])
	_rot(anim, _KN_F, t, [0.0, 0.3, 0.4])
	_rot(anim, _KN_B, t, [0.0, 0.3, 0.4])
	_rot(anim, _TH_F, t, [0.0, 0.12, 0.18])
	_rot(anim, _TH_B, t, [0.0, -0.1, -0.14])
	_pos(anim, _RIG, t, [
		Vector2(0.0, 0.0), Vector2(0.4, 1.6), Vector2(0.5, 2.2),
	])


## Смерть: кости «рассыпаются» — риг падает на бок, конечности
## раскидывает; в конце skeleton.gd удаляет узел.
static func _add_death(library: AnimationLibrary) -> void:
	var anim: Animation = _new_anim(library, &"death", DEATH_LEN, false)
	var t: PackedFloat32Array = PackedFloat32Array([0.0, 0.18, 0.38, DEATH_LEN])
	_rot(anim, _RIG, t, [0.0, -0.5, -1.2, -1.45])
	_pos(anim, _RIG, t, [
		Vector2(0.0, 0.0), Vector2(-1.0, 2.0), Vector2(-3.0, 6.0),
		Vector2(-4.0, 8.5),
	])
	_rot(anim, _SPINE, t, [0.0, 0.3, 0.5, 0.6])
	_rot(anim, _NECK, t, [0.0, 0.4, 0.6, 0.7])
	_rot(anim, _SH_F, t, [0.0, 0.9, 1.5, 1.9])
	_rot(anim, _SH_B, t, [0.0, -0.7, -1.3, -1.7])
	_rot(anim, _TH_F, t, [0.0, 0.6, 1.0, 1.2])
	_rot(anim, _TH_B, t, [0.0, -0.5, -0.9, -1.1])
	_rot(anim, _KN_F, t, [0.0, 0.5, 0.9, 1.1])
	_rot(anim, _KN_B, t, [0.0, 0.4, 0.7, 0.9])


## Возврат всех пивотов в покой: страховка при смене состояний,
## как RESET у игрока.
static func _add_reset(library: AnimationLibrary) -> void:
	var anim: Animation = _new_anim(library, &"RESET", 0.1, false)
	var t: PackedFloat32Array = PackedFloat32Array([0.0])
	for path: String in [
		_RIG, _HIPS, _SPINE, _NECK, _SH_F, _EL_F, _WR_F, _SH_B, _EL_B,
		_TH_F, _KN_F, _AN_F, _TH_B, _KN_B, _AN_B,
	]:
		_rot(anim, path, t, [0.0])
	_pos(anim, _RIG, t, [Vector2(0.0, 0.0)])
	_pos(anim, _STRING, t, [Vector2(-0.6, 0.0)])
