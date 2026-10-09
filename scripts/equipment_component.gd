class_name EquipmentComponent
extends ItemData

## Базовый ресурс для предметов экипировки.
## Все числовые бонусы применяются к игроку
## при надевании предмета в соответствующий слот.


@export_group("Экипировка")

## В какой слот надевается предмет.
@export var slot: EquipmentSlot.Type = EquipmentSlot.Type.NONE

## Защита предмета (блокирует часть входящего урона).
@export_range(0, 100, 1) var armor: int = 0

## Бонус к урону по блокам/врагам (добавляется к mining_damage).
@export_range(0, 100, 1) var attack_damage: int = 0

## Скорость атаки (множитель скорости взмаха кирки/меча).
## 1.0 — стандарт, 1.5 — на 50% быстрее, 0.8 — медленнее.
@export_range(0.25, 3.0, 0.05)
var attack_speed_multiplier: float = 1.0

## Стоимость одного удара выносливостью (чем меньше — тем выгоднее).
@export_range(0.0, 100.0, 0.5)
var attack_stamina_cost_modifier: float = 0.0

## Бонус к максимальной выносливости.
@export_range(-100.0, 1000.0, 1.0)
var stamina_bonus: float = 0.0

## Бонус к максимальной защите (абсолютное значение HP).
@export_range(-100, 1000, 1)
var max_health_bonus: int = 0

## Двуручное оружие — не помещается во вторичный слот.
@export var is_dual_hand: bool = false

## Отображаемая текстура на слоте экипировки.
@export var equipment_icon: Texture2D


## Проверяет, что предмет можно надеть в заданный слот.
func can_equip_to(slot_to_check: EquipmentSlot.Type) -> bool:
	if slot == EquipmentSlot.Type.NONE:
		return false
	return slot == slot_to_check


## Возвращает список всех числовых бонусов предмета
## для применения к игроку.
func get_equipment_stats() -> Dictionary:
	return {
		"armor": armor,
		"attack_damage": attack_damage,
		"attack_speed_multiplier": attack_speed_multiplier,
		"attack_stamina_cost_modifier": attack_stamina_cost_modifier,
		"stamina_bonus": stamina_bonus,
		"max_health_bonus": max_health_bonus,
		"is_dual_hand": is_dual_hand,
		"slot": slot,
	}
