extends Node


## Добавь сюда созданные ItemData (.tres), если используешь этот узел в сцене.
@export var items: Array[ItemData] = []

var _items_by_id: Dictionary = {}


func _ready() -> void:
	register_items(items)


func register_items(new_items: Array[ItemData]) -> void:
	for item: ItemData in new_items:
		register_item(item)


func register_item(item: ItemData) -> void:
	if item == null:
		return
	if item.item_id == &"":
		push_warning("ItemData без Item Id пропущен.")
		return
	if _items_by_id.has(item.item_id) and _items_by_id[item.item_id] != item:
		push_warning("Повторная регистрация Item Id: %s" % item.item_id)
	_items_by_id[item.item_id] = item


func get_item(item_id: StringName) -> ItemData:
	return _items_by_id.get(item_id) as ItemData


func has_item(item_id: StringName) -> bool:
	return _items_by_id.has(item_id)


func clear_registry() -> void:
	_items_by_id.clear()
