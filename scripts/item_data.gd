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
