class_name Campfire
extends Node2D

const COOK_SECONDS := 15.0
const READY_SECONDS := 15.0
const START_BURN_SECONDS := 600.0
const PLANK_SECONDS := 300.0
const COAL_SECONDS := 900.0

var input_ids: Array[StringName] = [&"", &"", &"", &"", &""]
var output_ids: Array[StringName] = [&"", &"", &"", &"", &""]
var cook_progress: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
var ready_progress: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
var fuel_id: StringName = &""
var fuel_amount: int = 0
var burn_seconds: float = START_BURN_SECONDS

# Активная единица уже списана из ячейки.
# fuel_id и fuel_amount содержат только ожидающее топливо.
var active_fuel_id: StringName = &""
var active_fuel_seconds: float = 0.0
var active_fuel_duration: float = 0.0

func _ready() -> void:
	add_to_group("campfire_interactable")
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	var added_seconds: float = _advance_fuel(delta)
	burn_seconds = maxf(
		0.0,
		burn_seconds + added_seconds - delta
	)
	if burn_seconds <= 0.0:
		return
	for i: int in range(5):
		if input_ids[i] == &"raw_meat" and output_ids[i] == &"":
			cook_progress[i] += delta
			if cook_progress[i] >= COOK_SECONDS:
				input_ids[i] = &""
				output_ids[i] = &"cooked_meat"
				cook_progress[i] = 0.0
				ready_progress[i] = 0.0
		elif output_ids[i] == &"cooked_meat":
			ready_progress[i] += delta
			if ready_progress[i] >= READY_SECONDS:
				output_ids[i] = &"coal"
				ready_progress[i] = 0.0

func add_raw_meat(amount: int) -> int:
	var added := 0
	for i: int in range(5):
		if added >= amount: break
		if input_ids[i] == &"" and output_ids[i] == &"":
			input_ids[i] = &"raw_meat"
			cook_progress[i] = 0.0
			added += 1
	return added


func take_fuel(amount: int) -> Dictionary:
	if amount <= 0 or fuel_amount <= 0:
		return {}
	var taken: int = mini(amount, fuel_amount)
	var result: Dictionary = {"item_id": fuel_id, "amount": taken}
	fuel_amount -= taken
	if fuel_amount <= 0:
		fuel_amount = 0
		fuel_id = &""
	return result

func add_fuel(item_id: StringName, amount: int) -> int:
	if amount <= 0:
		return 0

	if item_id != &"plank_scraps" and item_id != &"coal":
		return 0

	# В ожидающем стаке может находиться только один вид топлива.
	if fuel_amount > 0 and fuel_id != item_id:
		return 0

	var data: ItemData = ItemRegistry.get_item(item_id)
	if data == null:
		return 0

	var capacity: int = maxi(0, data.max_stack - fuel_amount)

	# Если активной единицы нет, первая сразу будет списана,
	# освобождая место в ожидающем стаке.
	if active_fuel_seconds <= 0.0:
		capacity += 1

	var accepted: int = mini(amount, capacity)
	if accepted <= 0:
		return 0

	fuel_id = item_id
	fuel_amount += accepted

	# Повторные ПКМ не запускают новую единицу,
	# пока предыдущая продолжает гореть.
	if active_fuel_seconds <= 0.0:
		burn_seconds += _start_next_fuel()

	return accepted


func _start_next_fuel() -> float:
	if fuel_amount <= 0 or active_fuel_seconds > 0.0:
		return 0.0

	active_fuel_id = fuel_id
	active_fuel_duration = (
		COAL_SECONDS if fuel_id == &"coal"
		else PLANK_SECONDS
	)
	active_fuel_seconds = active_fuel_duration

	fuel_amount -= 1

	if fuel_amount <= 0:
		fuel_amount = 0
		fuel_id = &""

	return active_fuel_duration


func _advance_fuel(delta: float) -> float:
	var remaining: float = maxf(delta, 0.0)
	var added: float = 0.0

	if active_fuel_seconds <= 0.0 and fuel_amount > 0:
		added += _start_next_fuel()

	while active_fuel_seconds > 0.0:
		var step: float = minf(
			remaining,
			active_fuel_seconds
		)

		active_fuel_seconds = maxf(
			0.0,
			active_fuel_seconds - step
		)
		remaining -= step

		if active_fuel_seconds > 0.0:
			break

		active_fuel_id = &""
		active_fuel_duration = 0.0

		if fuel_amount <= 0:
			break

		added += _start_next_fuel()

		if remaining <= 0.0:
			break

	return added


func _consume_one_fuel() -> void:
	# Оставлено для совместимости с существующими вызовами.
	# Пока горит активная единица, ничего не списывается.
	burn_seconds += _start_next_fuel()


func get_fuel_progress() -> float:
	if active_fuel_duration <= 0.0:
		return 0.0

	return clampf(
		active_fuel_seconds / active_fuel_duration,
		0.0,
		1.0
	)

func collect_output(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= 5 or output_ids[slot_index] == &"": return {}
	var result := {"item_id": output_ids[slot_index], "amount": 1}
	output_ids[slot_index] = &""
	ready_progress[slot_index] = 0.0
	return result

func get_timer_text() -> String:
	var seconds := ceili(burn_seconds)
	return "%02d:%02d" % [seconds / 60, seconds % 60]
