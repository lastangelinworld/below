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
	"poise_damage": {
		"add": "poise_damage",
		"minimum": 0.0,
	},
	# Интервал между ударами короче, если оружие быстрее:
	# итог = базовый интервал / скорость атаки.
	"mining_interval": {
		"multiply": "attack_interval_multiplier",
		"minimum": 0.05,
	},
	# Нагрузка брони замедляет шаг: итог = базовая скорость × множитель
	# обременения (1.0 без брони, меньше — с тяжёлой).
	"move_speed": {
		"multiply": "encumbrance_speed_multiplier",
		"minimum": 20.0,
	},
}

## Свойства игрока, которые EquipmentSystem заполняет вычисленными
## значениями нагрузки. В отличие от PROPERTY_RULES здесь нет baseline:
## это не «базовое + бонус», а результат расчёта, который игрок читает
## напрямую (спринт, ролл, реген стамины).
const ENCUMBRANCE_PROPERTIES := [
	"encumbrance",
	"encumbrance_speed_multiplier",
	"encumbrance_regen_multiplier",
	"is_overencumbered",
]

## Свойство игрока с грузоподъёмностью и экспорт-штрафы обременения.
## Читаются напрямую: менять их должно снаряжение нельзя.
const CAPACITY_PROPERTY: String = "equip_load_capacity_kg"
const SPEED_PENALTY_PROPERTY: String = "encumbrance_speed_penalty"
const REGEN_PENALTY_PROPERTY: String = "encumbrance_regen_penalty"

## Ниже этих значений штрафы не опускаются: полностью обездвиженный
## или лишённый стамины персонаж ломает игру, а не наказывает.
const MINIMUM_SPEED_MULTIPLIER: float = 0.45
const MINIMUM_REGEN_MULTIPLIER: float = 0.25
## Значение нагрузки, с которого броня считается «неподъёмной»:
## остаются только шаг и удар.
const OVERENCUMBERED_THRESHOLD: float = 1.0

var _slots: Dictionary = {}
var _baselines: Dictionary = {}
var _player: Node = null
var _totals: Dictionary = {}
var _applying: bool = false
## Дополнительные слоты, занятые чужим предметом:
## ключ — слот, значение — основной слот владельца.
var _extra_owners: Dictionary = {}
## Предметы, вытесненные из дополнительных слотов при надевании
## двуручного оружия. Интерфейс забирает их через drain_ejections().
var _ejections: Array = []


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
	if component == null or not component.can_place_in(target_slot):
		return false

	var taken: ItemStack = inventory.take_from_slot(inventory_slot_index, 1)
	if taken.is_empty():
		return false

	var replaced: ItemStack = _put_stack(target_slot, taken)
	_claim_extra_slots(target_slot, component)
	if not replaced.is_empty():
		var returned: int = inventory.add_item(replaced.item_id, replaced.amount)
		if returned < replaced.amount:
			# Инвентарь переполнен — возвращаем снятую вещь в тот же слот,
			# а новую кладём обратно в инвентарь, чтобы ничего не пропало.
			inventory.add_item(taken.item_id, taken.amount)
			_put_stack(target_slot, replaced)
			_release_extra_slots(target_slot)
			_claim_extra_slots(
				target_slot,
				_get_component(replaced.item_id)
			)
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
	_release_extra_slots(target_slot)
	_recalculate()
	equipment_changed.emit(target_slot)
	item_unequipped.emit(target_slot, removed.item_id)
	return true


func get_equipped_stack(slot: EquipmentSlot.Type) -> ItemStack:
	var stack: ItemStack = _slots.get(slot)
	if stack == null:
		return ItemStack.new()
	return stack


## Стек для отображения в ячейке. Ячейка дополнительного слота
## показывает предмет, который её занял (двуручное оружие).
func get_display_stack(slot: EquipmentSlot.Type) -> ItemStack:
	return get_equipped_stack(get_owning_slot(slot))


## Ячейка занята чужим предметом как дополнительный слот.
func is_secondary_cell(slot: EquipmentSlot.Type) -> bool:
	return _extra_owners.has(slot)


## Основной слот предмета, который видно в этой ячейке.
func get_owning_slot(slot: EquipmentSlot.Type) -> EquipmentSlot.Type:
	if _extra_owners.has(slot):
		return _extra_owners[slot]
	return slot


func is_slot_empty(slot: EquipmentSlot.Type) -> bool:
	return get_display_stack(slot).is_empty()


## Проверка для интерфейса: можно ли надеть предмет в слот
## без учёта места в инвентаре.
## В дополнительный слот двуручного оружия ничего нельзя положить
## отдельно — он освобождается только вместе с самим оружием.
func can_accept_item(slot: EquipmentSlot.Type, item_id: StringName) -> bool:
	if is_secondary_cell(slot):
		return false
	var component: EquipmentComponent = _get_component(item_id)
	if component == null:
		return false
	return component.can_place_in(slot)


## Снимает до amount единиц из слота и возвращает их отдельным стеком
## (используется перетаскиванием в интерфейсе).
## Снятие с дополнительного слота снимает весь предмет из основного.
func take_from_slot(slot: EquipmentSlot.Type, amount: int = -1) -> ItemStack:
	var result := ItemStack.new()
	var owner: EquipmentSlot.Type = get_owning_slot(slot)
	var stack: ItemStack = get_equipped_stack(owner)
	if stack.is_empty():
		return result
	var taken_amount: int = stack.amount if amount < 0 else mini(amount, stack.amount)
	result.item_id = stack.item_id
	result.amount = taken_amount
	stack.amount -= taken_amount
	if stack.amount <= 0:
		stack.item_id = &""
		stack.amount = 0
		_release_extra_slots(owner)
	_recalculate()
	equipment_changed.emit(owner)
	return result


## Полностью помещает incoming в слот (через интерфейс-курсор),
## возвращая вытесненный стек. Проверку совместимости слота
## (can_accept_item) выполняет вызывающая сторона.
func swap_single(slot: EquipmentSlot.Type, incoming: ItemStack) -> ItemStack:
	var outgoing: ItemStack = _put_stack(slot, incoming)
	_claim_extra_slots(slot, _get_component(incoming.item_id))
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
	_extra_owners.clear()
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
	_refresh_extra_owners()
	_recalculate()
	equipment_changed.emit(EquipmentSlot.Type.NONE)


## Предметы, вытесненные из дополнительных слотов (двуручное оружие
## заняло руку со щитом). Интерфейс забирает их после операции обмена
## и раскладывает по инвентарю.
func drain_ejections() -> Array:
	var result: Array = _ejections.duplicate()
	_ejections.clear()
	return result


## Занимает дополнительные слоты предмета, вытесняя то, что в них лежало.
## Вытесненные предметы попадают в _ejections.
func _claim_extra_slots(
		owner_slot: EquipmentSlot.Type,
		component: EquipmentComponent
) -> void:
	_release_extra_slots(owner_slot)
	if component == null:
		return

	for extra: EquipmentSlot.Type in component.extra_slots:
		if extra == owner_slot:
			continue
		var occupant: ItemStack = get_equipped_stack(extra)
		if not occupant.is_empty():
			_ejections.append(_put_stack(extra, ItemStack.new()))
		_extra_owners[extra] = owner_slot


## Освобождает дополнительные слоты, закреплённые за основным слотом.
func _release_extra_slots(owner_slot: EquipmentSlot.Type) -> void:
	var stale: Array = []
	for extra: EquipmentSlot.Type in _extra_owners.keys():
		if _extra_owners[extra] == owner_slot:
			stale.append(extra)
	for extra: Variant in stale:
		_extra_owners.erase(extra)


## Пересобирает карту дополнительных слотов после загрузки сохранений.
func _refresh_extra_owners() -> void:
	_extra_owners.clear()
	for slot: EquipmentSlot.Type in EquipmentSlot.ALL_SLOTS:
		var stack: ItemStack = _slots.get(slot)
		if stack == null or stack.is_empty():
			continue
		_claim_extra_slots(slot, _get_component(stack.item_id))


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
		"poise_damage": 0.0,
		"dual_hand_equipped": false,
		"armor_weight_kg": 0.0,
		"encumbrance": 0.0,
		"encumbrance_speed_multiplier": 1.0,
		"encumbrance_regen_multiplier": 1.0,
		"is_overencumbered": false,
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
		_totals["poise_damage"] += component.poise_damage
		if component.is_dual_hand and slot == EquipmentSlot.Type.MAINHAND:
			_totals["dual_hand_equipped"] = true

	# Интервал атаки обратно пропорционален скорости:
	# скорость 1.25 даёт интервал 0.8 от базового.
	var speed_total: float = maxf(float(_totals["attack_speed_multiplier"]), 0.01)
	_totals["attack_interval_multiplier"] = 1.0 / speed_total

	_apply_encumbrance()
	_apply_to_player()
	_applying = false


## Фаза 5: нагрузка физической брони. Суммарный вес предметов
## в броневых слотах делится на грузоподъёмность персонажа —
## получается доля encumbrance, из которой считаются штрафы шага
## и восстановления стамины. При доле ≥ 1.0 включается «неподъёмная»
## броня: персонаж сохраняет только шаг и удар.
func _apply_encumbrance() -> void:
	var armor_weight: float = 0.0
	for slot: EquipmentSlot.Type in EquipmentSlot.ARMOR_SLOTS:
		var stack: ItemStack = _slots.get(slot)
		if stack == null or stack.is_empty():
			continue
		var item: ItemData = ItemRegistry.get_item(stack.item_id)
		if item == null:
			continue
		armor_weight += item.unit_weight_kg * float(stack.amount)

	_totals["armor_weight_kg"] = armor_weight

	# Грузоподъёмность читаем у игрока; если свойства нет (тестовая
	# заглушка) — считаем, что броня не давит, чтобы не обездвижить.
	var capacity: float = 0.0
	if _player != null:
		var capacity_value: Variant = _player.get(CAPACITY_PROPERTY)
		if capacity_value != null:
			capacity = float(capacity_value)

	if capacity <= 0.0:
		_totals["encumbrance"] = 0.0
		_totals["encumbrance_speed_multiplier"] = 1.0
		_totals["encumbrance_regen_multiplier"] = 1.0
		_totals["is_overencumbered"] = false
		return

	var encumbrance: float = armor_weight / capacity
	var speed_penalty: float = _penalty(SPEED_PENALTY_PROPERTY, 0.4)
	var regen_penalty: float = _penalty(REGEN_PENALTY_PROPERTY, 0.5)

	_totals["encumbrance"] = encumbrance
	_totals["encumbrance_speed_multiplier"] = clampf(
		1.0 - encumbrance * speed_penalty, MINIMUM_SPEED_MULTIPLIER, 1.0
	)
	_totals["encumbrance_regen_multiplier"] = clampf(
		1.0 - encumbrance * regen_penalty, MINIMUM_REGEN_MULTIPLIER, 1.0
	)
	_totals["is_overencumbered"] = encumbrance >= OVERENCUMBERED_THRESHOLD


## Экспорт-множитель штрафа игрока с запасным значением.
func _penalty(property_name: String, fallback: float) -> float:
	if _player == null:
		return fallback
	var value: Variant = _player.get(property_name)
	if value == null:
		return fallback
	return clampf(float(value), 0.0, 1.0)


func _apply_to_player() -> void:
	if _player == null:
		return
	# get() возвращает null у узлов без такого свойства — пропускаем их,
	# чтобы тестовые заглушки без нагрузки не получали лишних полей.
	for property_name: String in ENCUMBRANCE_PROPERTIES:
		if _player.get(property_name) == null:
			continue
		_player.set(property_name, _totals.get(property_name))

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
