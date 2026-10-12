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

## Двуручное оружие — не помещается во вторичный слот отдельно,
## но занимает его вместе с основным (щит или факел тогда вытесняются).
@export var is_dual_hand: bool = false

## Дополнительные слоты, которые предмет занимает вместе с основным.
## Например двуручная дубина: slot = MAINHAND, extra = [OFFHAND].
@export var extra_slots: Array[EquipmentSlot.Type] = []

## Отображаемая текстура на слоте экипировки.
@export var equipment_icon: Texture2D

## Текстура, которую персонаж держит в руке при экипировке.
## Если не задана, используется icon из ItemData.
@export var held_weapon_texture: Texture2D

## Окно парирования в секундах от начала блока. Если входящая атака
## попадает в это окно — урон обнуляется, атакующий входит в стаггер.
@export_range(0.0, 1.0, 0.01)
var parry_window_sec: float = 0.2

## Базовый поиз-урон за удар этим предметом (до применения в бою).
## 0 = не задано. Тяжёлое оружие выставляет больше.
@export_range(0.0, 100.0, 0.5)
var poise_damage: float = 0.0

## Навык, который тренирует удар этим оружием (Фаза 6).
@export var weapon_skill: SkillsComponent.Skill = SkillsComponent.Skill.SWORDS

## Приносит ли предмет опыт в навык. false у брони, украшений и щитов:
## они не «оружие», и махать ими ради прокачки игрок не должен.
@export var trains_skill: bool = false


## Основные слоты предмета без доп. слотов.
func get_primary_slot() -> EquipmentSlot.Type:
	return slot


## Предмет физически occupies этот слот — основным или дополнительным
## (двуручное оружие занимает и вторичную руку).
func can_equip_to(slot_to_check: EquipmentSlot.Type) -> bool:
	if slot_to_check == EquipmentSlot.Type.NONE:
		return false
	if slot == slot_to_check:
		return true
	for extra: EquipmentSlot.Type in extra_slots:
		if extra == slot_to_check:
			return true
	return false


## Можно ли положить предмет в слот самостоятельно.
## В дополнительный слот двуручного предмета предмет кладётся
## только вместе с основным, поэтому здесь разрешён лишь основной слот.
func can_place_in(slot_to_check: EquipmentSlot.Type) -> bool:
	return slot != EquipmentSlot.Type.NONE and slot == slot_to_check



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
		"poise_damage": poise_damage,
		"is_dual_hand": is_dual_hand,
		"slot": slot,
	}
