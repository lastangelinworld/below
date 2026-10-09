class_name InventoryData
extends Resource

@export_range(1, 999, 1) var slot_count: int = 36
@export_range(0.0, 999999.0, 0.1) var max_weight_kg: float = 300.0
@export var slots: Array[ItemStack] = []

func setup(new_slot_count: int = -1, clear_existing: bool = true) -> void:
	if new_slot_count > 0:
		slot_count = new_slot_count
	if clear_existing:
		slots.clear()
	while slots.size() < slot_count:
		slots.append(ItemStack.new())
	while slots.size() > slot_count:
		slots.pop_back()
	for i in range(slots.size()):
		if slots[i] == null:
			slots[i] = ItemStack.new()
	emit_changed()

func notify_changed() -> void:
	emit_changed()

func get_slot(index: int) -> ItemStack:
	if index < 0 or index >= slots.size():
		return null
	if slots[index] == null:
		slots[index] = ItemStack.new()
	return slots[index]

func get_total_weight_kg() -> float:
	var total := 0.0
	for stack in slots:
		if stack == null or stack.is_empty():
			continue
		var item: ItemData = ItemRegistry.get_item(stack.item_id)
		if item != null:
			total += item.unit_weight_kg * float(stack.amount)
	return total

func get_free_weight_kg() -> float:
	return maxf(max_weight_kg - get_total_weight_kg(), 0.0)

func get_item_amount(item_id: StringName) -> int:
	var total := 0
	for stack in slots:
		if stack != null and not stack.is_empty() and stack.item_id == item_id:
			total += stack.amount
	return total

func can_add_item(item_id: StringName, amount: int) -> bool:
	return get_addable_amount(item_id, amount) >= amount

func get_addable_amount(item_id: StringName, requested_amount: int) -> int:
	if requested_amount <= 0:
		return 0
	var item: ItemData = ItemRegistry.get_item(item_id)
	if item == null:
		push_warning("Предмет не зарегистрирован: %s" % item_id)
		return 0
	var capacity := 0
	for stack in slots:
		if stack == null or stack.is_empty():
			capacity += item.max_stack
		elif stack.item_id == item_id:
			capacity += maxi(item.max_stack - stack.amount, 0)
	capacity = mini(capacity, requested_amount)
	if item.unit_weight_kg > 0.0:
		capacity = mini(capacity, floori(get_free_weight_kg() / item.unit_weight_kg))
	return maxi(capacity, 0)

func add_item(item_id: StringName, amount: int) -> int:
	var accepted := get_addable_amount(item_id, amount)
	if accepted <= 0:
		return 0
	var item: ItemData = ItemRegistry.get_item(item_id)
	if item == null:
		return 0
	var remaining := accepted
	for stack in slots:
		if remaining <= 0:
			break
		if stack == null or stack.is_empty() or stack.item_id != item_id:
			continue
		var portion := mini(maxi(item.max_stack - stack.amount, 0), remaining)
		stack.amount += portion
		remaining -= portion
	for i in range(slots.size()):
		if remaining <= 0:
			break
		var stack := get_slot(i)
		if not stack.is_empty():
			continue
		var portion := mini(item.max_stack, remaining)
		stack.item_id = item_id
		stack.amount = portion
		remaining -= portion
	emit_changed()
	return accepted - remaining

func remove_item(item_id: StringName, amount: int) -> int:
	var remaining := maxi(amount, 0)
	var removed := 0
	for stack in slots:
		if remaining <= 0:
			break
		if stack == null or stack.is_empty() or stack.item_id != item_id:
			continue
		var portion := mini(stack.amount, remaining)
		stack.amount -= portion
		remaining -= portion
		removed += portion
		if stack.amount <= 0:
			stack.item_id = &""
			stack.amount = 0
	if removed > 0:
		emit_changed()
	return removed

func remove_from_slot(index: int, amount: int = 1) -> int:
	var stack := get_slot(index)
	if stack == null or stack.is_empty() or amount <= 0:
		return 0
	var removed := mini(amount, stack.amount)
	stack.amount -= removed
	if stack.amount <= 0:
		stack.item_id = &""
		stack.amount = 0
	emit_changed()
	return removed

func take_from_slot(index: int, requested_amount: int = -1) -> ItemStack:
	var result := ItemStack.new()
	var stack := get_slot(index)
	if stack == null or stack.is_empty():
		return result
	var amount := stack.amount if requested_amount < 0 else mini(requested_amount, stack.amount)
	result.item_id = stack.item_id
	result.amount = amount
	stack.amount -= amount
	if stack.amount <= 0:
		stack.item_id = &""
		stack.amount = 0
	emit_changed()
	return result

func set_slot(index: int, item_id: StringName, amount: int) -> void:
	var stack := get_slot(index)
	if stack == null:
		return
	stack.item_id = item_id if amount > 0 else &""
	stack.amount = maxi(amount, 0)
	emit_changed()

func swap_with_stack(index: int, incoming: ItemStack) -> ItemStack:
	var outgoing := ItemStack.new()
	var target := get_slot(index)
	if target == null:
		return incoming
	outgoing.item_id = target.item_id
	outgoing.amount = target.amount
	target.item_id = incoming.item_id
	target.amount = incoming.amount
	emit_changed()
	return outgoing

## Переносит предметы из одной ячейки исходного инвентаря
## в свободные/совместимые ячейки целевого инвентаря.
## Возвращает фактически перенесённое количество.
static func transfer_slot_to(
		source: InventoryData,
		target: InventoryData,
		source_slot_index: int,
		amount: int
) -> int:
	if source == null or target == null:
		return 0
	if source == target:
		return 0
	if amount <= 0:
		return 0

	var source_stack: ItemStack = source.get_slot(source_slot_index)
	if source_stack == null or source_stack.is_empty():
		return 0

	var requested_amount: int = mini(amount, source_stack.amount)
	if requested_amount <= 0:
		return 0

	var item_id: StringName = source_stack.item_id
	var transferred_amount: int = target.add_item(item_id, requested_amount)
	if transferred_amount <= 0:
		return 0

	var removed_amount: int = source.remove_from_slot(
		source_slot_index,
		transferred_amount
	)

	# Защитный откат на случай внешнего изменения исходной ячейки
	# между добавлением и удалением.
	if removed_amount < transferred_amount:
		target.remove_item(item_id, transferred_amount - removed_amount)

	return removed_amount
