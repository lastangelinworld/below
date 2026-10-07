class_name ItemData
extends Resource


@export_group("Identity")
@export var item_id: StringName = &""
@export var display_name: String = "Предмет"

@export_group("Inventory")
## Вес одной единицы предмета в килограммах.
@export_range(0.0, 1000.0, 0.01) var unit_weight_kg: float = 1.0
## Максимальный размер одного стака.
@export_range(1, 999, 1) var max_stack: int = 64

@export_group("Presentation")
@export var icon: Texture2D

@export_group("Usage")
@export var usable_in_crafting: bool = true
@export var can_be_dropped: bool = true

@export_group("Склонение")
## Форма для 2-4 штук, например «камня».
@export var name_few: String = ""
## Форма для 5 и более штук, например «камней».
@export var name_many: String = ""


## Возвращает название в форме, подходящей к числу:
## 1 камень, 2 камня, 5 камней.
func get_counted_name(amount: int) -> String:
	var form_one: String = display_name.to_lower()
	var form_few: String = name_few if not name_few.is_empty() else form_one
	var form_many: String = name_many if not name_many.is_empty() else form_few

	var absolute_amount: int = absi(amount)
	var last_two_digits: int = absolute_amount % 100

	if last_two_digits >= 11 and last_two_digits <= 14:
		return form_many

	match absolute_amount % 10:
		1:
			return form_one
		2, 3, 4:
			return form_few
		_:
			return form_many
