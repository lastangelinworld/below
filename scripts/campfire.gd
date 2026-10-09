class_name Campfire
extends Node2D

const SLOT_COUNT := 5

const COOK_SECONDS := 15.0
const READY_SECONDS := 15.0

const START_BURN_SECONDS := 600.0
const PLANK_SECONDS := 300.0
const COAL_SECONDS := 900.0

var input_ids: Array[StringName] = [
	&"", &"", &"", &"", &""
]

var output_ids: Array[StringName] = [
	&"", &"", &"", &"", &""
]

var cook_progress: Array[float] = [
	0.0, 0.0, 0.0, 0.0, 0.0
]

var ready_progress: Array[float] = [
	0.0, 0.0, 0.0, 0.0, 0.0
]

# Здесь находится только ожидающее топливо.
var fuel_ids: Array[StringName] = [
	&"", &"", &"", &"", &""
]

var fuel_amounts: Array[int] = [
	0, 0, 0, 0, 0
]

# Активные единицы уже списаны из ожидающих стаков.
var active_fuel_ids: Array[StringName] = [
	&"", &"", &"", &"", &""
]

var active_fuel_seconds: Array[float] = [
	0.0, 0.0, 0.0, 0.0, 0.0
]

var active_fuel_durations: Array[float] = [
	0.0, 0.0, 0.0, 0.0, 0.0
]

var burn_seconds: float = START_BURN_SECONDS

# Совместимость с кодом, который только читает
# старые поля единственной топливной ячейки.
var fuel_id: StringName:
	get:
		for i: int in range(SLOT_COUNT):
			if fuel_amounts[i] > 0:
				return fuel_ids[i]
		return &""

var fuel_amount: int:
	get:
		var total := 0
		for count: int in fuel_amounts:
			total += count
		return total


func _ready() -> void:
	add_to_group("campfire_interactable")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_update_flame()


func _process(delta: float) -> void:
	if delta <= 0.0:
		return

	var lit_seconds: float = _advance_fire(delta)

	for i: int in range(SLOT_COUNT):
		var ready_delta: float = delta

		if input_ids[i] == &"raw_meat" and output_ids[i] == &"":
			var needed: float = maxf(
				0.0,
				COOK_SECONDS - cook_progress[i]
			)

			if lit_seconds < needed:
				cook_progress[i] += lit_seconds
				continue

			input_ids[i] = &""
			output_ids[i] = &"cooked_meat"
			cook_progress[i] = 0.0
			ready_progress[i] = 0.0

			# Учитываем остаток кадра после приготовления.
			ready_delta = maxf(0.0, delta - needed)

		if output_ids[i] == &"cooked_meat":
			ready_progress[i] += ready_delta

			if ready_progress[i] >= READY_SECONDS:
				output_ids[i] = &"coal"
				ready_progress[i] = 0.0

	_update_flame()


func put_raw_meat(slot_index: int) -> int:
	if not _valid_slot(slot_index):
		return 0

	if input_ids[slot_index] != &"":
		return 0

	# Перед новым приготовлением нужно забрать
	# результат из соответствующей нижней ячейки.
	if output_ids[slot_index] != &"":
		return 0

	input_ids[slot_index] = &"raw_meat"
	cook_progress[slot_index] = 0.0
	return 1


func take_raw_meat(slot_index: int) -> Dictionary:
	if not _valid_slot(slot_index):
		return {}

	if input_ids[slot_index] == &"":
		return {}

	input_ids[slot_index] = &""
	cook_progress[slot_index] = 0.0

	return {
		"item_id": &"raw_meat",
		"amount": 1
	}


# Автоматическое распределение — для Shift + ЛКМ.
func add_raw_meat(amount: int) -> int:
	var added := 0

	for i: int in range(SLOT_COUNT):
		if added >= maxi(amount, 0):
			break

		added += put_raw_meat(i)

	return added


func collect_output(slot_index: int) -> Dictionary:
	if not _valid_slot(slot_index):
		return {}

	if output_ids[slot_index] == &"":
		return {}

	var result := {
		"item_id": output_ids[slot_index],
		"amount": 1
	}

	output_ids[slot_index] = &""
	ready_progress[slot_index] = 0.0
	return result


func add_fuel_to_slot(
		slot_index: int,
		item_id: StringName,
		amount: int
) -> int:
	if not _valid_slot(slot_index):
		return 0

	if amount <= 0 or not _is_fuel(item_id):
		return 0

	# В одном ожидающем стаке один вид ресурса.
	if fuel_amounts[slot_index] > 0:
		if fuel_ids[slot_index] != item_id:
			return 0

	# Пока горит активная единица, эта ячейка
	# остаётся закреплена за её видом топлива.
	if active_fuel_seconds[slot_index] > 0.0:
		if active_fuel_ids[slot_index] != item_id:
			return 0

	var item: ItemData = ItemRegistry.get_item(item_id)
	if item == null:
		return 0

	var capacity: int = maxi(
		0,
		item.max_stack - fuel_amounts[slot_index]
	)

	# Первая единица сразу уйдёт в активное горение.
	if active_fuel_seconds[slot_index] <= 0.0:
		capacity += 1

	var accepted: int = mini(amount, capacity)
	if accepted <= 0:
		return 0

	fuel_ids[slot_index] = item_id
	fuel_amounts[slot_index] += accepted

	if active_fuel_seconds[slot_index] <= 0.0:
		_start_next_fuel(slot_index)

	_update_flame()
	return accepted


# Автоматическое заполнение — для Shift + ЛКМ.
# Обычные клики используют add_fuel_to_slot().
func add_fuel(
		item_id: StringName,
		amount: int,
		slot_index: int = -1
) -> int:
	if amount <= 0 or not _is_fuel(item_id):
		return 0

	if slot_index >= 0:
		return add_fuel_to_slot(slot_index, item_id, amount)

	var remaining: int = amount

	# Сначала дополняем уже занятые этим ресурсом ячейки.
	for i: int in range(SLOT_COUNT):
		if remaining <= 0:
			break

		var same_waiting: bool = (
			fuel_amounts[i] > 0 and fuel_ids[i] == item_id
		)
		var same_active: bool = (
			active_fuel_seconds[i] > 0.0
			and active_fuel_ids[i] == item_id
		)

		if same_waiting or same_active:
			remaining -= add_fuel_to_slot(
				i, item_id, remaining
			)

	# Затем используем свободные ячейки.
	for i: int in range(SLOT_COUNT):
		if remaining <= 0:
			break

		if fuel_amounts[i] <= 0 and active_fuel_seconds[i] <= 0.0:
			remaining -= add_fuel_to_slot(
				i, item_id, remaining
			)

	return amount - remaining


func _start_next_fuel(slot_index: int) -> void:
	if active_fuel_seconds[slot_index] > 0.0:
		return

	if fuel_amounts[slot_index] <= 0:
		return

	active_fuel_ids[slot_index] = fuel_ids[slot_index]

	var duration: float = (
		COAL_SECONDS
		if fuel_ids[slot_index] == &"coal"
		else PLANK_SECONDS
	)

	active_fuel_durations[slot_index] = duration
	active_fuel_seconds[slot_index] = duration

	fuel_amounts[slot_index] -= 1

	if fuel_amounts[slot_index] <= 0:
		fuel_amounts[slot_index] = 0
		fuel_ids[slot_index] = &""

	# Ожидающие единицы заранее время не добавляют.
	burn_seconds += duration


func _advance_fire(delta: float) -> float:
	var remaining: float = delta
	var lit_seconds := 0.0

	# Обрабатываем границы циклов отдельно, чтобы
	# большой delta не потерял очередные единицы топлива.
	while remaining > 0.0:
		for i: int in range(SLOT_COUNT):
			if active_fuel_seconds[i] <= 0.0:
				_start_next_fuel(i)

		if burn_seconds <= 0.0:
			break

		var step: float = minf(remaining, burn_seconds)

		for i: int in range(SLOT_COUNT):
			if active_fuel_seconds[i] > 0.0:
				step = minf(step, active_fuel_seconds[i])

		burn_seconds = maxf(0.0, burn_seconds - step)
		lit_seconds += step
		remaining = maxf(0.0, remaining - step)

		for i: int in range(SLOT_COUNT):
			if active_fuel_seconds[i] <= 0.0:
				continue

			active_fuel_seconds[i] = maxf(
				0.0,
				active_fuel_seconds[i] - step
			)

			if active_fuel_seconds[i] <= 0.0:
				active_fuel_ids[i] = &""
				active_fuel_durations[i] = 0.0
				_start_next_fuel(i)

	return lit_seconds


func take_fuel(
		slot_index: int,
		amount: int = -1
) -> Dictionary:
	if not _valid_slot(slot_index):
		return {}

	if fuel_amounts[slot_index] <= 0:
		return {}

	var count: int = (
		fuel_amounts[slot_index]
		if amount < 0
		else mini(amount, fuel_amounts[slot_index])
	)

	if count <= 0:
		return {}

	var result := {
		"item_id": fuel_ids[slot_index],
		"amount": count
	}

	fuel_amounts[slot_index] -= count

	if fuel_amounts[slot_index] <= 0:
		fuel_amounts[slot_index] = 0
		fuel_ids[slot_index] = &""

	# Активную единицу забрать нельзя.
	return result


func get_fuel_progress(slot_index: int = 0) -> float:
	if not _valid_slot(slot_index):
		return 0.0

	if active_fuel_durations[slot_index] <= 0.0:
		return 0.0

	return clampf(
		active_fuel_seconds[slot_index]
		/ active_fuel_durations[slot_index],
		0.0,
		1.0
	)


func get_timer_text() -> String:
	return format_seconds(burn_seconds)


static func format_seconds(value: float) -> String:
	var seconds: int = maxi(0, ceili(value))
	var minutes: int = floori(float(seconds) / 60.0)

	return "%02d:%02d" % [
		minutes,
		seconds % 60
	]


func _valid_slot(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < SLOT_COUNT


func _is_fuel(item_id: StringName) -> bool:
	return item_id == &"plank_scraps" or item_id == &"coal"


func _update_flame() -> void:
	var flame := get_node_or_null(
		"CampfireFlame"
	) as AnimatedSprite2D

	if flame != null:
		flame.visible = burn_seconds > 0.0

		if flame.visible:
			if not flame.is_playing():
				flame.play("burn")
		else:
			flame.stop()

	var light := get_node_or_null(
		"PointLight2D"
	) as PointLight2D

	if light != null:
		light.visible = burn_seconds > 0.0
