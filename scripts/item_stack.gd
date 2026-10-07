class_name ItemStack
extends Resource


@export var item_id: StringName = &""
@export_range(0, 999, 1) var amount: int = 0


func is_empty() -> bool:
	return item_id == &"" or amount <= 0


func clear() -> void:
	item_id = &""
	amount = 0
	emit_changed()


func set_item(new_item_id: StringName, new_amount: int) -> void:
	item_id = new_item_id
	amount = maxi(new_amount, 0)
	if amount <= 0:
		item_id = &""
	emit_changed()


func copy_stack() -> ItemStack:
	var result := ItemStack.new()
	result.item_id = item_id
	result.amount = amount
	return result
