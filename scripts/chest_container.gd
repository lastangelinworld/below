class_name ChestContainer
extends StaticBody2D

## Sixteen-slot persistent storage. Set these two arrays in an editor-created chest
## to spawn it with loot. Matching indices form one stack.
@export var initial_item_ids: Array[StringName] = []
@export var initial_item_amounts: Array[int] = []
@export_range(1, 64, 1) var storage_size: int = 16

var storage_ids: Array[StringName] = []
var storage_amounts: Array[int] = []

func _ready() -> void:
	add_to_group("storage_chest")
	_ensure_storage()
	if not get_meta("below_initialised", false):
		for i: int in range(mini(initial_item_ids.size(), initial_item_amounts.size())):
			store_items(initial_item_ids[i], initial_item_amounts[i])
		set_meta("below_initialised", true)

func _ensure_storage() -> void:
	while storage_ids.size() < storage_size:
		storage_ids.append(&"")
		storage_amounts.append(0)
	if storage_ids.size() > storage_size:
		storage_ids.resize(storage_size)
		storage_amounts.resize(storage_size)

func store_items(item_id: StringName, amount: int) -> int:
	_ensure_storage()
	if item_id == &"" or amount <= 0:
		return 0
	var item: ItemData = ItemRegistry.get_item(item_id)
	if item == null:
		return 0
	var left: int = amount
	for i: int in range(storage_size):
		if storage_ids[i] == item_id and storage_amounts[i] < item.max_stack:
			var moved: int = mini(left, item.max_stack - storage_amounts[i])
			storage_amounts[i] += moved
			left -= moved
			if left <= 0: return amount
	for i: int in range(storage_size):
		if storage_ids[i] == &"" or storage_amounts[i] <= 0:
			var moved: int = mini(left, item.max_stack)
			storage_ids[i] = item_id
			storage_amounts[i] = moved
			left -= moved
			if left <= 0: break
	return amount - left

func take_items(slot_index: int, amount: int = -1) -> Dictionary:
	_ensure_storage()
	if slot_index < 0 or slot_index >= storage_size or storage_amounts[slot_index] <= 0:
		return {}
	var count: int = storage_amounts[slot_index] if amount < 0 else mini(amount, storage_amounts[slot_index])
	var result := {"item_id": storage_ids[slot_index], "amount": count}
	storage_amounts[slot_index] -= count
	if storage_amounts[slot_index] <= 0:
		storage_ids[slot_index] = &""
		storage_amounts[slot_index] = 0
	return result
