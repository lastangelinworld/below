class_name BackstabRules
extends RefCounted

## Правила бонусного урона Salt and Sanctuary: удар «в спину» и казнь
## цели, стоящей в стаггере после парирования.
## Единая точка расчёта — вызывается из Hurtbox.receive_hit(),
## поэтому любой источник урона через Hitbox (меч, кирка) подчиняется
## одним и тем же правилам.

## Во сколько раз больнее удар, нанесённый со спины цели.
const BACKSTAB_MULTIPLIER: float = 2.5

## Во сколько раз больнее удар по цели в стаггере (казнь).
const EXECUTION_MULTIPLIER: float = 1.5

## Мёртвая зона по X: если атака идёт почти в упор (разница < 15 px),
## это не спина, а фронтальный удар — даже если хитбокс чуть смещён.
const BACKSTAB_DEAD_ZONE_X: float = 15.0


## true, если вектор от атакующего к цели совпадает с направлением
## взгляда цели: атакующий находится за спиной цели.
## У цели читается свойство facing (int: 1 вправо, -1 влево);
## у существ без направления взгляда бонуса нет.
static func is_backstab(attack_from: Vector2, target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return false

	# get() возвращает null у узлов без свойства facing (постройки,
	# блоки) — у таких существ бонуса за спину нет.
	var dir_value: Variant = target.get("facing")
	if not (dir_value is int):
		return false
	var dir: int = dir_value
	if dir == 0:
		return false

	var to_target_x: float = target.global_position.x - attack_from.x
	if is_zero_approx(to_target_x):
		return false

	# Мёртвая зона по X: если атака идёт почти в упор (разница < 15 px),
	# это не спина, а фронтальный удар — даже если хитбокс чуть смещён.
	if absf(to_target_x) < BACKSTAB_DEAD_ZONE_X:
		return false

	return signf(to_target_x) == float(dir)


## true, если цель сейчас в стаггере и открыта для казни.
static func is_staggered(target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if not target.has_method("is_staggered"):
		return false
	return bool(target.is_staggered())


## Итоговый множитель урона: берётся лучший из подходящих бонусов,
## они не складываются (как в оригинале — срабатывает один признак).
static func multiplier(attack_from: Vector2, target: Node) -> float:
	var result: float = 1.0
	if is_staggered(target):
		result = maxf(result, EXECUTION_MULTIPLIER)
	if is_backstab(attack_from, target):
		result = maxf(result, BACKSTAB_MULTIPLIER)
	return result