class_name FoodRules
extends RefCounted

## Единый источник правил питания.
## Раньше длительность и бонусы были продублированы в Player и в
## HotbarFoodController с разными значениями (1500 и 1800 секунд).

## Номер первой ячейки автопотребления в InventoryData.
const FIRST_SLOT: int = 36

## Количество ячеек автопотребления.
const SLOT_COUNT: int = 3

## Сколько ячеек инвентаря нужно под предметы и еду.
const REQUIRED_INVENTORY_SLOTS: int = FIRST_SLOT + SLOT_COUNT

## Сколько действует одна порция, в секундах.
const DURATION_SECONDS: float = 1500.0

## Предметы, которые вообще можно положить в ячейку еды.
const FOOD_IDS: Array[StringName] = [&"raw_meat", &"cooked_meat"]


static func is_food(item_id: StringName) -> bool:
	return item_id in FOOD_IDS


## Возвращает прибавку блюда: x — максимум здоровья, y — максимум выносливости.
static func get_bonus(item_id: StringName) -> Vector2:
	match item_id:
		&"raw_meat":
			return Vector2(5.0, 0.0)
		&"cooked_meat":
			return Vector2(10.0, 5.0)
	return Vector2.ZERO


## Индекс ячейки автопотребления по номеру ряда 0..2.
static func slot_of_lane(lane: int) -> int:
	return FIRST_SLOT + lane


static func lane_of_slot(slot_index: int) -> int:
	if slot_index < FIRST_SLOT or slot_index >= REQUIRED_INVENTORY_SLOTS:
		return -1
	return slot_index - FIRST_SLOT
