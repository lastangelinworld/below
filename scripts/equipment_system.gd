class_name EquipmentSystem
extends Node

## Компонент экипировки игрока (Фаза 2).
## Хранит предметы в именованных слотах и пересчитывает
## сводные характеристики по baseline-модели: базовые значения
## игрока запоминаются один раз, итог = базовые + сумма бонусов.
## Это исключает накопление ошибок при надевании и снятии вещей.

signal equipment_changed(slot: EquipmentSlot.Type)
signal item_equipped(slot: EquipmentSlot.Type, item_id: StringName)
signal item_unequipped(slot: EquipmentSlot.Type, item_id: StringName)

## Свойства игрока, на которые влияют бонусы экипировки.
## Ключ — имя свойства в player.gd.
const PROPERTY_RULES := {
	"mining_damage": {
		"add": "attack_damage",
	},
	"attack_stamina_cost": {
		"add": "attack_stamina_cost_modifier",
		"minimum": 0.0,
	},
	"max_stamina": {
		"add": "stamina_bonus",
		"minimum": 1.0,
	},
	"max_health": {
		"add": "max_health_bonus",
		"minimum": 1,
	},
	# Интервал между ударами короче, если оружие быстрее:
	# итог = базовый интервал / скорость атаки.
	"mining_interval": {
		"multiply": "attack_interval_multiplier",
		"minimum": 0.05,
	},
}

var _slots: Dictionary = {}
var _baselines: Dictionary = {}
var _player: Node = null
var _totals: Dictionary = {}
var _applying: bool = false


func _ready() -> void:
	for slot: EquipmentSlot.Type in EquipmentSlot.ALL_SLOTS:
		_slots[slot] = ItemStack.new()


## Запоминает базовые значения игрока и подключается к нему.
## Вызывается один раз из player.gd после инициализации инвентаря.
func setup(player: Node) -> void:
	if player == null or _player != null:
		return
	_player = player
	for property_name: String in PROPERTY_RULES.keys():
		var current_value: Variant = _player.get(property_name)
		if current_value == null:
			push_warning("EquipmentSystem: у игрока нет свойства %s" % property_name)
			continue
		_baselines[property_name] = current_value
	_recalculate()


## Надевает предмет из ячейки инвентаря. Возвращает true при успехе.
func equip_from_inventory(
	inventory: InventoryData,
	inventory_slot_index: int,
	target_slot: EquipmentSlot.Type
) -> bool:
	if _player == null or inventory == null:
		return false
	var stack: ItemStack = inventory.get_slot(inventory_slot_index)
	if stack == null or stack.is_empty():
		return false
	var component: EquipmentComponent = _get_component(stack.item_id)
	if component == null or not component.can_equip_to(target_slot):
		return false

	var taken: ItemStack = inventory.take_from_slot(inventory_slot_index, 1)
	if taken.is_empty():
		return false

	var replaced: ItemStack = _put_stack(target_slot, taken)
	if not replaced.is_empty():
		var returned: int = inventory.add_item(replaced.item_id, replaced.amount)
		if returned < replaced.amount:
			# Инвентарь переполнен — возвращаем снятую вещь в тот же слот,
			# а новую кладём обратно в инвентарь, чтобы ничего не пропало.
			inventory.add_item(taken.item_id, taken.amount)
			_put_stack(target_slot, replaced)
			_recalculate()
			equipment_changed.emit(target_slot)
			return false

	_recalculate()
	equipment_changed.emit(target_slot)
	item_equipped.emit(target_slot, taken.item_id)
	return true


## Снимает предмет из слота в инвентарь. Возвращает true при успехе.
func unequip_to_inventory(
	inventory: InventoryData,
	target_slot: EquipmentSlot.Type
) -> bool:
	if _player == null or inventory == null:
		return false
	var stack: ItemStack = get_equipped_stack(target_slot)
	if stack.is_empty():
		return false
	var accepted: int = inventory.add_item(stack.item_id, stack.amount)
	if accepted <= 0:
		return false
	var removed: ItemStack = _put_stack(target_slot, ItemStack.new())
	_recalculate()
	equipment_changed.emit(target_slot)
	item_unequipped.emit(target_slot, removed.item_id)
	return true


func get_equipped_stack(slot: EquipmentSlot.Type) -> ItemStack:
	var stack: ItemStack = _slots.get(slot)
	if stack == null:
		return ItemStack.new()
	return stack


func is_slot_empty(slot: EquipmentSlot.Type) -> bool:
	return get_equipped_stack(slot).is_empty()


## Проверка для интерфейса: можно ли надеть предмет в слот
## без учёта места в инвентаре.
func can_accept_item(slot: EquipmentSlot.Type, item_id: StringName) -> bool:
	var component: EquipmentComponent = _get_component(item_id)
	if component == null:
		return false
	if not component.can_equip_to(slot):
		return false
	# Двуручное оружие вытесняет щит, иначе в руках два предмета сразу.
	if component.is_dual_hand and slot == EquipmentSlot.Type.MAINHAND:
		return true
	if component.is_dual_hand and slot == EquipmentSlot.Type.OFFHAND:
		return false
	return true


## Снимает до amount единиц из слота и возвращает их отдельным стеком
## (используется перетаскиванием в интерфейсе).
func take_from_slot(slot: EquipmentSlot.Type, amount: int = -1) -> ItemStack:
	var result := ItemStack.new()
	var stack: ItemStack = get_equipped_stack(slot)
	if stack.is_empty():
		return result
	var taken_amount: int = stack.amount if amount < 0 else mini(amount, stack.amount)
	result.item_id = stack.item_id
	result.amount = taken_amount
	stack.amount -= taken_amount
	if stack.amount <= 0:
		stack.item_id = &""
		stack.amount = 0
	_recalculate()
	equipment_changed.emit(slot)
	return result


## Полностью помещает incoming в слот (через интерфейс-курсор),
## возвращая вытесненный стек. Проверку совместимости слота
## (can_accept_item) выполняет вызывающая сторона.
func swap_single(slot: EquipmentSlot.Type, incoming: ItemStack) -> ItemStack:
	var outgoing: ItemStack = _put_stack(slot, incoming)
	_recalculate()
	equipment_changed.emit(slot)
	if not outgoing.is_empty():
		item_unequipped.emit(slot, outgoing.item_id)
	if incoming != null and not incoming.is_empty():
		item_equipped.emit(slot, incoming.item_id)
	return outgoing


## Сообщает системе, что слоты изменились извне (прямой обмен курсором),
## чтобы свойства игрока пересчитались.
func notify_external_changed() -> void:
	_recalculate()
	equipment_changed.emit(EquipmentSlot.Type.NONE)


## Сводные бонусы всех надетых предметов.
func get_totals() -> Dictionary:
	return _totals.duplicate()


func get_occupied_slots() -> Array:
	var result: Array = []
	for slot: EquipmentSlot.Type in EquipmentSlot.ALL_SLOTS:
		if not is_slot_empty(slot):
			result.append(slot)
	return result


func save_state() -> Dictionary:
	var slots_data: Dictionary = {}
	for slot: EquipmentSlot.Type in _slots.keys():
		var stack: ItemStack = _slots[slot]
		if stack != null and not stack.is_empty():
			slots_data[str(int(slot))] = {
				"item_id": str(stack.item_id),
				"amount": stack.amount,
			}
	return {"slots": slots_data}


func load_state(state: Dictionary) -> void:
	if _player == null:
		return
	for slot: EquipmentSlot.Type in EquipmentSlot.ALL_SLOTS:
		_put_stack(slot, ItemStack.new())
	var slots_data: Variant = state.get("slots", {})
	if typeof(slots_data) != TYPE_DICTIONARY:
		return
	for raw_slot: String in (slots_data as Dictionary).keys():
		var raw_index: Variant = raw_slot.to_int()
		var slot: EquipmentSlot.Type = EquipmentSlot.sanitize(int(raw_index))
		if slot == EquipmentSlot.Type.NONE:
			continue
		var raw_entry: Variant = (slots_data as Dictionary)[raw_slot]
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = raw_entry
		var stack: ItemStack = _slots.get(slot)
		if stack == null:
			continue
		stack.set_item(StringName(str(entry.get("item_id", ""))), int(entry.get("amount", 0)))
	_recalculate()
	equipment_changed.emit(EquipmentSlot.Type.NONE)


func _put_stack(slot: EquipmentSlot.Type, incoming: ItemStack) -> ItemStack:
	var outgoing := ItemStack.new()
	var target: ItemStack = _slots.get(slot)
	if target == null:
		target = ItemStack.new()
		_slots[slot] = target
	outgoing.item_id = target.item_id
	outgoing.amount = target.amount
	target.item_id = incoming.item_id
	target.amount = incoming.amount
	return outgoing


func _get_component(item_id: StringName) -> EquipmentComponent:
	var item: ItemData = ItemRegistry.get_item(item_id)
	return item as EquipmentComponent


func _recalculate() -> void:
	if _applying:
		return
	_applying = true
	_totals = {
		"armor": 0,
		"attack_damage": 0,
		"attack_speed_multiplier": 1.0,
		"attack_stamina_cost_modifier": 0.0,
		"stamina_bonus": 0.0,
		"max_health_bonus": 0,
		"dual_hand_equipped": false,
	}

	for slot: EquipmentSlot.Type in EquipmentSlot.ALL_SLOTS:
		var stack: ItemStack = _slots.get(slot)
		if stack == null or stack.is_empty():
			continue
		var component: EquipmentComponent = _get_component(stack.item_id)
		if component == null:
			continue
		_totals["armor"] += component.armor
		_totals["attack_damage"] += component.attack_damage
		_totals["attack_speed_multiplier"] *= component.attack_speed_multiplier
		_totals["attack_stamina_cost_modifier"] += component.attack_stamina_cost_modifier
		_totals["stamina_bonus"] += component.stamina_bonus
		_totals["max_health_bonus"] += component.max_health_bonus
		if component.is_dual_hand and slot == EquipmentSlot.Type.MAINHAND:
			_totals["dual_hand_equipped"] = true

	# Интервал атаки обратно пропорционален скорости:
	# скорость 1.25 даёт интервал 0.8 от базового.
	var speed_total: float = maxf(float(_totals["attack_speed_multiplier"]), 0.01)
	_totals["attack_interval_multiplier"] = 1.0 / speed_total

	_apply_to_player()
	_applying = false


func _apply_to_player() -> void:
	if _player == null:
		return
	for property_name: String in PROPERTY_RULES.keys():
		if not _baselines.has(property_name):
			continue
		var rule: Dictionary = PROPERTY_RULES[property_name]
		var result: float = float(_baselines[property_name])
		var add_key: String = str(rule.get("add", ""))
		if not add_key.is_empty():
			result += float(_totals.get(add_key, 0))
		var multiply_key: String = str(rule.get("multiply", ""))
		if not multiply_key.is_empty():
			result *= float(_totals.get(multiply_key, 1.0))
		var minimum: float = float(rule.get("minimum", 0.0))
		result = maxf(result, minimum)

		var baseline_value: Variant = _baselines[property_name]
		if typeof(baseline_value) == TYPE_INT:
			_player.set(property_name, int(round(result)))
		else:
			_player.set(property_name, result)

	# Здоровье не должно превышать новую планку после снятия шлема и т. п.
	if _baselines.has("max_health"):
		var current_health: Variant = _player.get("current_health")
		if current_health != null:
			var new_max: int = int(_player.get("max_health"))
			if int(current_health) > new_max:
				_player.set("current_health", new_max)
		var current_stamina: Variant = _player.get("current_stamina")
		if current_stamina != null:
			var new_stamina_max: float = float(_player.get("max_stamina"))
			if float(current_stamina) > new_stamina_max:
				_player.set("current_stamina", new_stamina_max)
