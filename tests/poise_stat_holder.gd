extends Node2D
class_name PoiseStatHolder

## Тестовая заглушка игрока для EquipmentSystem: объявляет ровно те
## свойства, которые система читает через PROPERTY_RULES и расчёт
## нагрузки. Нужна, потому что обычный Node не хранит динамические
## свойства, а Player тянет за собой сцену с анимациями.

var mining_damage: int = 1
var attack_stamina_cost: float = 8.0
var max_stamina: float = 100.0
var max_health: int = 100
var mining_interval: float = 0.25
var move_speed: float = 220.0
var poise_damage: float = 0.0
var current_health: int = 100
var current_stamina: float = 100.0

## Параметры и результаты нагрузки (Фаза 5).
var equip_load_capacity_kg: float = 12.0
var encumbrance_speed_penalty: float = 0.4
var encumbrance_regen_penalty: float = 0.5
var encumbrance: float = 0.0
var encumbrance_speed_multiplier: float = 1.0
var encumbrance_regen_multiplier: float = 1.0
var is_overencumbered: bool = false