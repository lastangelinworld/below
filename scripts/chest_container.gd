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
	collision_layer = 0
	collision_mask = 0
	add_to_group("placeable_structure")
	add_to_group("chest")
	call_deferred("_below_prepare_integrity")
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


# BELOW_CHEST_INTEGRITY_V1
signal chest_destroyed

@export_group("Прочность и обрушение")
@export_range(1, 10000000, 1) var minimum_chest_health: int = 100
@export_range(2, 100, 1) var block_health_multiplier: int = 20
@export_range(0.1, 120.0, 0.1) var collapse_delay_seconds: float = 16.0
@export var chest_recipe_path: String = "res://data/recipes/chest.tres"

var chest_max_health: int = 100
var chest_health: int = 100
var unsupported_seconds: float = 0.0
var _below_terrain: Node2D
var _below_ready: bool = false
var _below_destroying: bool = false

func _below_prepare_integrity() -> void:
	_below_find_terrain()
	var strongest: int = 1
	if is_instance_valid(_below_terrain):
		var types: Variant = _below_terrain.get("block_types")
		if types is Array:
			for block: Variant in types:
				if block != null and bool(block.get("breakable")):
					strongest = maxi(strongest, int(block.get("max_health")))
	chest_max_health = maxi(minimum_chest_health, strongest * block_health_multiplier)
	chest_health = chest_max_health
	_below_ready = true

func _below_find_terrain() -> void:
	var candidate: Node = get_tree().get_first_node_in_group("terrain")
	if candidate is Node2D and candidate.has_method("get_block_type_at_cell"):
		_below_terrain = candidate as Node2D
		return
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var nodes: Array[Node] = scene.find_children("*", "TileMapLayer", true, false)
	for node: Node in nodes:
		if node is Node2D and node.has_method("get_block_type_at_cell"):
			_below_terrain = node as Node2D
			return

func _process(delta: float) -> void:
	if not _below_ready or _below_destroying:
		return
	if not is_instance_valid(_below_terrain):
		_below_find_terrain()
		return
	var base_cell: Vector2i = _below_terrain.call("global_position_to_cell", global_position)
	var block: Variant = _below_terrain.call("get_block_type_at_cell", base_cell + Vector2i.DOWN)
	if block != null and bool(block.get("solid")):
		unsupported_seconds = 0.0
		return
	unsupported_seconds += delta
	if unsupported_seconds >= collapse_delay_seconds:
		# При ошибке создания дропа не удаляем сундук и не теряем вещи.
		if not destroy_chest():
			unsupported_seconds = maxf(0.0, collapse_delay_seconds - 1.0)

func receive_structure_damage(amount: int) -> bool:
	if _below_destroying or amount <= 0:
		return false
	if not _below_ready:
		_below_prepare_integrity()
	chest_health = maxi(0, chest_health - amount)
	if chest_health == 0:
		if not destroy_chest():
			chest_health = 1
	return true

func _below_get_refund() -> Dictionary:
	var amounts: Dictionary = {}
	if not ResourceLoader.exists(chest_recipe_path):
		push_error("Сундук: не найден рецепт: " + chest_recipe_path)
		return amounts
	var recipe: Resource = load(chest_recipe_path)
	if recipe == null:
		return amounts
	var pattern: Variant = recipe.get("pattern")
	if not pattern is Array:
		push_error("Сундук: рецепт не содержит массива pattern.")
		return amounts
	var output_count: int = 1
	for property: Dictionary in recipe.get_property_list():
		if String(property.get("name", "")) == "output_amount":
			output_count = maxi(1, int(recipe.get("output_amount")))
	for ingredient: Variant in pattern:
		var key: StringName = StringName(str(ingredient))
		if key != &"":
			amounts[key] = int(amounts.get(key, 0)) + 1
	for key: Variant in amounts.keys():
		# Текущий рецепт создаёт один сундук; дробный возврат не допускаем.
		if int(amounts[key]) % output_count != 0:
			push_error("Сундук: дробный возврат материалов, требуется отдельная настройка рецепта.")
			return {}
		amounts[key] = int(amounts[key]) / output_count
	return amounts

func destroy_chest() -> bool:
	if _below_destroying:
		return false
	var refund: Dictionary = _below_get_refund()
	if refund.is_empty():
		push_error("Сундук оставлен на месте: невозможно определить материалы крафта.")
		return false
	var totals: Dictionary = refund.duplicate()
	_ensure_storage()
	for i: int in range(storage_size):
		if storage_ids[i] != &"" and storage_amounts[i] > 0:
			totals[storage_ids[i]] = int(totals.get(storage_ids[i], 0)) + storage_amounts[i]
	var pickup_scene: PackedScene = null
	if is_instance_valid(_below_terrain):
		pickup_scene = _below_terrain.get("item_pickup_scene") as PackedScene
	if pickup_scene == null:
		for path: String in ["res://data/items/item_pickup.tscn", "res://items/item_pickup.tscn"]:
			if ResourceLoader.exists(path):
				pickup_scene = load(path) as PackedScene
				if pickup_scene != null:
					break
	if pickup_scene == null:
		push_error("Сундук: не найдена сцена выпавшего предмета. Сундук не удалён.")
		return false
	var prepared: Array[Node2D] = []
	for key: Variant in totals.keys():
		var item: ItemData = ItemRegistry.get_item(StringName(str(key)))
		if item == null:
			for node: Node2D in prepared:
				node.free()
			push_error("Сундук: предмет не зарегистрирован: " + str(key))
			return false
		var remaining: int = int(totals[key])
		while remaining > 0:
			var count: int = mini(remaining, maxi(1, item.max_stack))
			var instance: Node = pickup_scene.instantiate()
			if not instance is Node2D or not instance.has_method("setup"):
				instance.free()
				for node: Node2D in prepared:
					node.free()
				push_error("Сундук: сцена дропа должна иметь Node2D и функцию setup.")
				return false
			instance.call("setup", StringName(str(key)), count)
			prepared.append(instance as Node2D)
			remaining -= count
	var parent: Node = get_parent()
	if parent == null:
		for node: Node2D in prepared:
			node.free()
		return false
	_below_destroying = true
	for i: int in range(storage_size):
		storage_ids[i] = &""
		storage_amounts[i] = 0
	for i: int in range(prepared.size()):
		var pickup: Node2D = prepared[i]
		parent.add_child(pickup)
		pickup.global_position = global_position + Vector2(float(i % 5 - 2) * 4.0, -12.0 - float(i / 5) * 3.0)
	chest_destroyed.emit()
	queue_free()
	return true
