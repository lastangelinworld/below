class_name EquipmentSlot
extends RefCounted

## Типы слотов экипировки второй фазы.
enum Type {
	NONE = 0,
	HEAD = 1,
	CHEST = 2,
	LEGS = 3,
	SHIELD = 4,
	RING_LEFT = 5,
	RING_RIGHT = 6,
	NECKLACE = 7,
	LAMP = 8,
	MAINHAND = 9,
	OFFHAND = 10,
}

## Все слоты в порядке отображения в интерфейсе.
const ALL_SLOTS: Array[Type] = [
	Type.HEAD,
	Type.CHEST,
	Type.LEGS,
	Type.NECKLACE,
	Type.RING_LEFT,
	Type.RING_RIGHT,
	Type.SHIELD,
	Type.LAMP,
	Type.MAINHAND,
	Type.OFFHAND,
]

## Слоты, в которые можно положить два одинаковых кольца.
const RING_SLOTS: Array[Type] = [Type.RING_LEFT, Type.RING_RIGHT]


static func get_display_name(slot: Type) -> String:
	match slot:
		Type.HEAD:
			return "Шлем"
		Type.CHEST:
			return "Нагрудник"
		Type.LEGS:
			return "Штаны"
		Type.SHIELD:
			return "Щит"
		Type.RING_LEFT:
			return "Кольцо (левое)"
		Type.RING_RIGHT:
			return "Кольцо (правое)"
		Type.NECKLACE:
			return "Ожерелье"
		Type.LAMP:
			return "Лампа"
		Type.MAINHAND:
			return "Основное оружие"
		Type.OFFHAND:
			return "Вторичное оружие"
		_:
			return "Пусто"


## В эти слоты предмет обязан влезать в одиночку (стаки из оружия/брони).
static func holds_single_item(slot: Type) -> bool:
	return slot != Type.NONE


## Превращает число из сохранённого файла обратно в корректный слот.
static func sanitize(raw_value: int) -> Type:
	if raw_value >= Type.HEAD and raw_value <= Type.OFFHAND:
		return raw_value as Type
	return Type.NONE
