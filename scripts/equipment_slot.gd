class_name EquipmentSlot
extends RefCounted

## Типы слотов экипировки.
## Числовые значения зафиксированы: их сохраняют файлы сохранений.
## Удалённые типы Щит (4) и Лампа (8) — исторические: щит и факел
## — это вторичное оружие, они используют слот OFFHAND.
enum Type {
	NONE = 0,
	HEAD = 1,
	CHEST = 2,
	LEGS = 3,
	RING_LEFT = 5,
	RING_RIGHT = 6,
	NECKLACE = 7,
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
	Type.MAINHAND,
	Type.OFFHAND,
]

## Слоты, в которые можно положить два одинаковых кольца.
const RING_SLOTS: Array[Type] = [Type.RING_LEFT, Type.RING_RIGHT]

## Слоты физической брони: только их вес создаёт нагрузку (encumbrance).
## Оружие, щит и украшения (кольца, ожерелье) ношу носят, но по плану
## Фазы 5 персонажа не грузят — иначе двуручная дубина сделала бы
## «тяжёлый класс» недоступным без брони вовсе.
const ARMOR_SLOTS: Array[Type] = [Type.HEAD, Type.CHEST, Type.LEGS]


static func get_display_name(slot: Type) -> String:
	match slot:
		Type.HEAD:
			return "Голова"
		Type.CHEST:
			return "Торс"
		Type.LEGS:
			return "Ноги"
		Type.RING_LEFT:
			return "Кольцо (левое)"
		Type.RING_RIGHT:
			return "Кольцо (правое)"
		Type.NECKLACE:
			return "Ожерелье"
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
## Старые сохранения могли содержать удалённые слоты «Щит» (4)
## и «Лампа» (8): оба превращаются во вторичное оружие.
static func sanitize(raw_value: int) -> Type:
	match raw_value:
		4, 8:
			return Type.OFFHAND
		Type.HEAD, Type.CHEST, Type.LEGS, Type.RING_LEFT, Type.RING_RIGHT, Type.NECKLACE, Type.MAINHAND, Type.OFFHAND:
			return raw_value as Type
		_:
			return Type.NONE