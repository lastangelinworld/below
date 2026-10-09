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
	add_to_group("placeable_structure")
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_below_prepare_integrity")
	_update_flame()


func _process(delta: float) -> void:
	if delta <= 0.0:
		return

	_below_integrity_process(delta)
	if _below_destroying:
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


# BELOW_CAMPFIRE_INTEGRITY_V1
signal campfire_destroyed

@export_group("Прочность и обрушение")

## Прочность костра, когда под ним стоит самый мягкий из блоков.
@export_range(1, 10000000, 1) var minimum_campfire_health: int = 60

## Во сколько раз прочность костра выше прочности блока, на котором он стоит.
@export_range(2, 100, 1) var block_health_multiplier: int = 12

## Сколько секунд костёр висит без опоры, прежде чем обрушиться.
@export_range(0.1, 120.0, 0.1) var collapse_delay_seconds: float = 16.0

## Рецепт, материалы которого возвращаются при обрушении.
@export var campfire_recipe_path: String = "res://data/recipes/campfire.tres"

var campfire_max_health: int = 60
var campfire_health: int = 60
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

	campfire_max_health = maxi(
		minimum_campfire_health,
		strongest * block_health_multiplier
	)
	campfire_health = campfire_max_health
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


## Считает опору под костром и копит время свободного висения.
func _below_integrity_process(delta: float) -> void:
	if not _below_ready or _below_destroying:
		return

	if not is_instance_valid(_below_terrain):
		_below_find_terrain()
		return

	var base_cell: Vector2i = _below_terrain.call(
		"global_position_to_cell",
		global_position
	)
	var block: Variant = _below_terrain.call(
		"get_block_type_at_cell",
		base_cell + Vector2i.DOWN
	)

	if block != null and bool(block.get("solid")):
		unsupported_seconds = 0.0
		return

	unsupported_seconds += delta
	if unsupported_seconds >= collapse_delay_seconds:
		if not destroy_campfire():
			unsupported_seconds = maxf(0.0, collapse_delay_seconds - 1.0)


func receive_structure_damage(amount: int) -> bool:
	if _below_destroying or amount <= 0:
		return false

	if not _below_ready:
		_below_prepare_integrity()

	campfire_health = maxi(0, campfire_health - amount)
	if campfire_health == 0:
		if not destroy_campfire():
			campfire_health = 1

	return true


## Собирает всё содержимое костра: сырьё, готовое и незожжённое топливо.
func _below_collect_contents() -> Dictionary:
	var totals: Dictionary = {}

	for i: int in range(SLOT_COUNT):
		_below_add_item(totals, input_ids[i], 1)
		_below_add_item(totals, output_ids[i], 1)
		_below_add_item(totals, fuel_ids[i], fuel_amounts[i])

	return totals


func _below_add_item(totals: Dictionary, item_id: StringName, amount: int) -> void:
	if item_id == &"" or amount <= 0:
		return

	var key := StringName(str(item_id))
	totals[key] = int(totals.get(key, 0)) + amount


## Возвращает материалы, из которых костёр был скрафчен.
func _below_get_refund() -> Dictionary:
	var amounts: Dictionary = {}

	if not ResourceLoader.exists(campfire_recipe_path):
		push_error("Костёр: не найден рецепт: " + campfire_recipe_path)
		return amounts

	var recipe: Resource = load(campfire_recipe_path)
	if recipe == null:
		return amounts

	var pattern: Variant = recipe.get("pattern")
	if not pattern is Array:
		push_error("Костёр: рецепт не содержит массив pattern.")
		return amounts

	var output_count: int = 1
	for property: Dictionary in recipe.get_property_list():
		if String(property.get("name", "")) == "output_amount":
			output_count = maxi(1, int(recipe.get("output_amount")))

	for ingredient: Variant in pattern:
		_below_add_item(amounts, StringName(str(ingredient)), 1)

	for key: Variant in amounts.keys():
		# Текущий рецепт создаёт один костёр; дробный возврат означал бы ошибку в рецепте.
		if int(amounts[key]) % output_count != 0:
			push_error("Костёр: дробный возврат материалов — проверь настройки рецепта.")
			return {}
		amounts[key] = int(amounts[key]) / output_count

	return amounts


## Обрушивает костёр: выкладывает содержимое и материалы крафта в мир.
func destroy_campfire() -> bool:
	if _below_destroying:
		return false

	var refund: Dictionary = _below_get_refund()
	if refund.is_empty():
		push_error("Костёр оставлен на месте: невозможно вернуть материалы крафта.")
		return false

	var totals: Dictionary = refund.duplicate(true)
	var contents: Dictionary = _below_collect_contents()
	for key: Variant in contents.keys():
		_below_add_item(totals, StringName(str(key)), int(contents[key]))

	var pickup_scene: PackedScene = null
	if is_instance_valid(_below_terrain):
		pickup_scene = _below_terrain.get("item_pickup_scene") as PackedScene

	if pickup_scene == null:
		for path: String in [
			"res://data/items/item_pickup.tscn",
			"res://items/item_pickup.tscn",
		]:
			if ResourceLoader.exists(path):
				pickup_scene = load(path) as PackedScene
				if pickup_scene != null:
					break

	if pickup_scene == null:
		push_error("Костёр: не найдена сцена выпадаемого предмета. Костёр не удалён.")
		return false

	var prepared: Array[Node2D] = []
	for key: Variant in totals.keys():
		var item: ItemData = ItemRegistry.get_item(StringName(str(key)))
		if item == null:
			for node: Node2D in prepared:
				node.free()
			push_error("Костёр: предмет не зарегистрирован: " + str(key))
			return false

		var remaining: int = int(totals[key])
		while remaining > 0:
			var count: int = mini(remaining, maxi(1, item.max_stack))
			var instance: Node = pickup_scene.instantiate()
			if not instance is Node2D or not instance.has_method("setup"):
				instance.free()
				for node: Node2D in prepared:
					node.free()
				push_error("Костёр: сцена дропа должна быть Node2D с методом setup.")
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
	_below_clear_contents()

	for i: int in range(prepared.size()):
		var pickup: Node2D = prepared[i]
		parent.add_child(pickup)
		pickup.global_position = global_position + Vector2(
			float(i % 5 - 2) * 4.0,
			-12.0 - float(i / 5) * 3.0
		)

	campfire_destroyed.emit()
	queue_free()
	return true


func _below_clear_contents() -> void:
	for i: int in range(SLOT_COUNT):
		input_ids[i] = &""
		output_ids[i] = &""
		cook_progress[i] = 0.0
		ready_progress[i] = 0.0
		fuel_ids[i] = &""
		fuel_amounts[i] = 0

	burn_seconds = 0.0
	_update_flame()
