class_name ChestContainer
extends StaticBody2D


@export_range(1, 999, 1) var slot_count: int = 27
@export_range(0.0, 999999.0, 0.1) var max_weight_kg: float = 1000.0
@export var saved_inventory: InventoryData

var inventory: InventoryData


func _ready() -> void:
	if saved_inventory != null:
		inventory = saved_inventory
		inventory.slot_count = slot_count
		inventory.max_weight_kg = max_weight_kg
		inventory.setup(slot_count, false)
	else:
		inventory = InventoryData.new()
		inventory.slot_count = slot_count
		inventory.max_weight_kg = max_weight_kg
		inventory.setup()


func add_item(item_id: StringName, amount: int) -> int:
	return inventory.add_item(item_id, amount) if inventory != null else 0


func remove_item(item_id: StringName, amount: int) -> int:
	return inventory.remove_item(item_id, amount) if inventory != null else 0


func open_for_player(player: Node) -> void:
	if player != null and player.has_method("open_chest"):
		player.call("open_chest", self)
