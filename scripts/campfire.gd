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

func _ready() -> void:
	add_to_group("campfire_interactable")
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if burn_seconds > 0.0:
		burn_seconds = maxf(0.0, burn_seconds - delta)
	elif fuel_amount > 0:
		_consume_one_fuel()
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

func add_fuel(item_id: StringName, amount: int) -> int:
	if item_id != &"plank_scraps" and item_id != &"coal": return 0
	if fuel_amount > 0 and fuel_id != item_id: return 0
	fuel_id = item_id
	fuel_amount += amount
	return amount

func _consume_one_fuel() -> void:
	if fuel_amount <= 0: return
	burn_seconds += _seconds_for_fuel(fuel_id)
	fuel_amount -= 1
	if fuel_amount <= 0:
		fuel_amount = 0
		fuel_id = &""

func collect_output(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= 5 or output_ids[slot_index] == &"": return {}
	var result := {"item_id": output_ids[slot_index], "amount": 1}
	output_ids[slot_index] = &""
	ready_progress[slot_index] = 0.0
	return result

## Сколько секунд даёт одна единица топлива.
func _seconds_for_fuel(item_id: StringName) -> float:
	return COAL_SECONDS if item_id == &"coal" else PLANK_SECONDS

## Полный запас: текущее горение плюс то, что лежит в ячейке топлива.
func get_total_burn_seconds() -> float:
	return burn_seconds + float(fuel_amount) * _seconds_for_fuel(fuel_id)

## Возвращает топливо из ячейки обратно игроку.
func take_fuel(amount: int) -> Dictionary:
	if fuel_amount <= 0 or fuel_id == &"" or amount <= 0:
		return {}
	var taken: int = mini(amount, fuel_amount)
	var result := {"item_id": fuel_id, "amount": taken}
	fuel_amount -= taken
	if fuel_amount <= 0:
		fuel_amount = 0
		fuel_id = &""
	return result

func get_timer_text() -> String:
	var seconds := ceili(get_total_burn_seconds())
	return "%02d:%02d" % [seconds / 60, seconds % 60]
