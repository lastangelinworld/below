class_name TerrainLayer
extends TileMapLayer


signal block_drops_created(drops: Array, global_position: Vector2)


@export_group("Blocks")

## Все типы блоков, используемые этим слоем.
@export var block_types: Array[BlockType] = []

## Необязательная сцена ItemPickup. Если назначена, дроп появляется в мире автоматически.
@export var item_pickup_scene: PackedScene


@export_group("Falling Blocks")

## Включает клеточную физику падающих блоков.
@export var falling_blocks_enabled: bool = true

## Время одного шага падения на одну клетку.
@export_range(0.02, 1.0, 0.01)
var fall_step_interval: float = 0.08

## Нижняя техническая граница падения.
@export var maximum_fall_cell_y: int = 512


## Соответствие тайла и BlockType.
var _block_types_by_tile: Dictionary = {}

## Оставшееся здоровье повреждённых клеток.
var _remaining_health_by_cell: Dictionary = {}

## Накопленное время физики падающих блоков.
var _fall_accumulator: float = 0.0

var _random_generator := RandomNumberGenerator.new()


func _ready() -> void:
	_random_generator.randomize()
	rebuild_block_index()


func _physics_process(delta: float) -> void:
	if not falling_blocks_enabled:
		return

	_fall_accumulator += delta

	var completed_steps: int = 0
	var maximum_steps_per_frame: int = 4

	while (
		_fall_accumulator >= fall_step_interval
		and completed_steps < maximum_steps_per_frame
	):
		_fall_accumulator -= fall_step_interval
		_step_falling_blocks()
		completed_steps += 1


func _make_tile_key(
	source_id: int,
	atlas_coordinates: Vector2i
) -> Vector3i:
	return Vector3i(
		source_id,
		atlas_coordinates.x,
		atlas_coordinates.y
	)


func rebuild_block_index() -> void:
	_block_types_by_tile.clear()

	for block_type: BlockType in block_types:
		if block_type == null:
			continue

		var tile_key: Vector3i = _make_tile_key(
			block_type.source_id,
			block_type.atlas_coordinates
		)

		if _block_types_by_tile.has(tile_key):
			push_warning(
				(
					"Несколько типов блоков используют "
					+ "один тайл: source %d, atlas %s"
				) % [
					block_type.source_id,
					str(block_type.atlas_coordinates)
				]
			)

		_block_types_by_tile[tile_key] = block_type

	print(
		"TerrainLayer: загружено типов блоков: %d"
		% _block_types_by_tile.size()
	)


func global_position_to_cell(
	global_position_value: Vector2
) -> Vector2i:
	return local_to_map(
		to_local(global_position_value)
	)


func get_cell_global_center(
	cell_coordinates: Vector2i
) -> Vector2:
	return to_global(
		map_to_local(cell_coordinates)
	)


func has_block_at_cell(
	cell_coordinates: Vector2i
) -> bool:
	return get_cell_source_id(cell_coordinates) != -1


func get_block_type_at_cell(
	cell_coordinates: Vector2i
) -> BlockType:
	var source_id: int = get_cell_source_id(
		cell_coordinates
	)

	if source_id == -1:
		return null

	var atlas_coordinates: Vector2i = (
		get_cell_atlas_coords(cell_coordinates)
	)

	var tile_key: Vector3i = _make_tile_key(
		source_id,
		atlas_coordinates
	)

	return _block_types_by_tile.get(tile_key) as BlockType


## Возвращает нормализованный идентификатор блока в клетке.
## Основной источник — block_id; display_name используется только как резерв.
func get_block_identity_at_cell(
	cell_coordinates: Vector2i
) -> String:
	var block_type: BlockType = get_block_type_at_cell(
		cell_coordinates
	)

	if block_type == null:
		return ""

	var identity: String = str(block_type.block_id).strip_edges().to_lower()

	if identity.is_empty():
		identity = block_type.display_name.strip_edges().to_lower()

	return identity.replace(" ", "_").replace("-", "_")


## Надёжная проверка типа блока без обращения к Custom Data Layers TileSet.
func block_at_cell_matches_any_id(
	cell_coordinates: Vector2i,
	expected_ids: Array[StringName]
) -> bool:
	var block_type: BlockType = get_block_type_at_cell(
		cell_coordinates
	)

	if block_type == null:
		return false

	var actual_id: String = str(block_type.block_id).strip_edges().to_lower()
	var display_name: String = block_type.display_name.strip_edges().to_lower()

	for expected_id: StringName in expected_ids:
		var expected: String = str(expected_id).strip_edges().to_lower()
		if expected.is_empty():
			continue

		if actual_id == expected:
			return true

		# Резервная совместимость со старыми ресурсами, где block_id
		# мог быть пустым либо содержать префикс/суффикс.
		if actual_id.contains(expected) or display_name.contains(expected):
			return true

	return false


## Используется курсором/системой взаимодействия для определения сундука.
## Не требует пользовательского слоя с именем interactable/chest в TileSet.
func is_chest_at_cell(
	cell_coordinates: Vector2i
) -> bool:
	return block_at_cell_matches_any_id(
		cell_coordinates,
		[&"chest", &"сундук"]
	)


func get_block_health_at_cell(
	cell_coordinates: Vector2i
) -> int:
	var block_type: BlockType = get_block_type_at_cell(
		cell_coordinates
	)

	if block_type == null:
		return 0

	if _remaining_health_by_cell.has(
		cell_coordinates
	):
		return int(
			_remaining_health_by_cell[
				cell_coordinates
			]
		)

	return block_type.max_health


## Возвращает модификаторы проходимых блоков среды.
func get_environment_modifiers_in_global_rect(
	global_rect: Rect2
) -> Vector3:
	var movement_multiplier: float = 1.0
	var vertical_multiplier: float = 1.0
	var animation_multiplier: float = 1.0

	var global_corners: PackedVector2Array = [
		global_rect.position,
		Vector2(
			global_rect.end.x,
			global_rect.position.y
		),
		global_rect.end,
		Vector2(
			global_rect.position.x,
			global_rect.end.y
		)
	]

	var first_local_point: Vector2 = to_local(
		global_corners[0]
	)

	var local_minimum: Vector2 = first_local_point
	var local_maximum: Vector2 = first_local_point

	for global_corner: Vector2 in global_corners:
		var local_corner: Vector2 = to_local(
			global_corner
		)

		local_minimum.x = minf(
			local_minimum.x,
			local_corner.x
		)
		local_minimum.y = minf(
			local_minimum.y,
			local_corner.y
		)
		local_maximum.x = maxf(
			local_maximum.x,
			local_corner.x
		)
		local_maximum.y = maxf(
			local_maximum.y,
			local_corner.y
		)

	var first_cell: Vector2i = local_to_map(
		local_minimum
	)
	var last_cell: Vector2i = local_to_map(
		local_maximum
	)

	var minimum_x: int = mini(first_cell.x, last_cell.x)
	var maximum_x: int = maxi(first_cell.x, last_cell.x)
	var minimum_y: int = mini(first_cell.y, last_cell.y)
	var maximum_y: int = maxi(first_cell.y, last_cell.y)

	for cell_y: int in range(
		minimum_y,
		maximum_y + 1
	):
		for cell_x: int in range(
			minimum_x,
			maximum_x + 1
		):
			var cell := Vector2i(
				cell_x,
				cell_y
			)

			var block_type: BlockType = (
				get_block_type_at_cell(cell)
			)

			if block_type == null or block_type.solid:
				continue

			movement_multiplier = minf(
				movement_multiplier,
				block_type.movement_speed_multiplier
			)
			vertical_multiplier = minf(
				vertical_multiplier,
				block_type.vertical_speed_multiplier
			)
			animation_multiplier = minf(
				animation_multiplier,
				block_type.animation_speed_multiplier
			)

	return Vector3(
		movement_multiplier,
		vertical_multiplier,
		animation_multiplier
	)


func _step_falling_blocks() -> void:
	var used_cells: Array[Vector2i] = get_used_cells()

	used_cells.sort_custom(
		_sort_cells_bottom_first
	)

	for source_cell: Vector2i in used_cells:
		var block_type: BlockType = (
			get_block_type_at_cell(source_cell)
		)

		if block_type == null:
			continue

		if not block_type.affected_by_gravity:
			continue

		var destination_cell := Vector2i(
			source_cell.x,
			source_cell.y + 1
		)

		if destination_cell.y > maximum_fall_cell_y:
			continue

		if has_block_at_cell(destination_cell):
			continue

		_move_block_cell(
			source_cell,
			destination_cell
		)


func _sort_cells_bottom_first(
	first_cell: Vector2i,
	second_cell: Vector2i
) -> bool:
	if first_cell.y == second_cell.y:
		return first_cell.x < second_cell.x

	return first_cell.y > second_cell.y


func _move_block_cell(
	source_cell: Vector2i,
	destination_cell: Vector2i
) -> void:
	var source_id: int = get_cell_source_id(
		source_cell
	)

	if source_id == -1:
		return

	var atlas_coordinates: Vector2i = (
		get_cell_atlas_coords(source_cell)
	)

	var alternative_tile: int = (
		get_cell_alternative_tile(source_cell)
	)

	var had_custom_health: bool = (
		_remaining_health_by_cell.has(
			source_cell
		)
	)

	var remaining_health: int = 0

	if had_custom_health:
		remaining_health = int(
			_remaining_health_by_cell[
				source_cell
			]
		)

	_remaining_health_by_cell.erase(source_cell)
	erase_cell(source_cell)

	set_cell(
		destination_cell,
		source_id,
		atlas_coordinates,
		alternative_tile
	)

	if had_custom_health:
		_remaining_health_by_cell[
			destination_cell
		] = remaining_health


func request_damage_block(
	cell_coordinates: Vector2i,
	attacker_global_position: Vector2,
	tool_level: int,
	damage: int
) -> bool:
	var block_type: BlockType = get_block_type_at_cell(
		cell_coordinates
	)

	if block_type == null:
		return false

	if not block_type.breakable:
		print(
			"Блок «%s» нельзя разрушить."
			% block_type.display_name
		)
		return false

	if tool_level < block_type.required_tool_level:
		print(
			(
				"Для блока «%s» нужен инструмент уровня %d. "
				+ "Текущий уровень: %d."
			) % [
				block_type.display_name,
				block_type.required_tool_level,
				tool_level
			]
		)
		return false

	if damage <= 0:
		push_warning(
			"Урон по блоку должен быть больше нуля."
		)
		return false

	var block_global_center: Vector2 = (
		get_cell_global_center(
			cell_coordinates
		)
	)

	var attack_direction: Vector2 = (
		block_global_center
		- attacker_global_position
	).normalized()

	if attack_direction == Vector2.ZERO:
		attack_direction = Vector2.RIGHT

	var remaining_health: int = (
		get_block_health_at_cell(
			cell_coordinates
		)
	)

	remaining_health -= damage

	if remaining_health > 0:
		_remaining_health_by_cell[
			cell_coordinates
		] = remaining_health

		print(
			"Удар по «%s»: %d/%d HP, клетка %s"
			% [
				block_type.display_name,
				remaining_health,
				block_type.max_health,
				str(cell_coordinates)
			]
		)

		return true

	_destroy_block(
		cell_coordinates,
		block_type
	)

	return true


## Создаёт визуальные осколки в центре клетки.
func _spawn_block_break_effect(
	cell_coordinates: Vector2i,
	block_type: BlockType
) -> void:
	if tile_set == null:
		return

	var effect := BlockBreakEffect.new()
	add_child(effect)

	effect.position = map_to_local(
		cell_coordinates
	)
	effect.z_index = 10

	effect.setup(
		Vector2(tile_set.tile_size),
		block_type.break_particle_color
	)


func _create_block_drops(block_type: BlockType) -> Array[ItemStack]:
	var result: Array[ItemStack] = []
	if block_type == null:
		return result

	var amounts_by_item: Dictionary = {}

	# В первую очередь используем дроп, настроенный в ресурсе блока.
	for drop: DropEntry in block_type.drops:
		if drop == null or drop.item_id == &"":
			continue
		var amount: int = drop.roll(_random_generator)
		if amount > 0:
			amounts_by_item[drop.item_id] = int(
				amounts_by_item.get(drop.item_id, 0)
			) + amount

	# Поддержка старых полей BlockType.
	if amounts_by_item.is_empty() and block_type.drop_item_id != &"" and block_type.drop_amount > 0:
		amounts_by_item[block_type.drop_item_id] = block_type.drop_amount

	# Безопасные значения по умолчанию. Они позволяют проверить систему,
	# даже если массив Drops в старых ресурсах блоков ещё не заполнен.
	if amounts_by_item.is_empty():
		_add_default_drops(block_type, amounts_by_item)

	for item_key: Variant in amounts_by_item.keys():
		var amount: int = int(amounts_by_item[item_key])
		if amount <= 0:
			continue
		var stack := ItemStack.new()
		stack.set_item(StringName(str(item_key)), amount)
		result.append(stack)

	return result


func _add_default_drops(block_type: BlockType, amounts: Dictionary) -> void:
	var identity: String = (
		str(block_type.block_id) + " " + block_type.display_name
	).to_lower()
	identity = identity.replace(" ", "_").replace("-", "_")

	if (
		"rock" in identity
		or "stone" in identity
		or "горн" in identity
		or "пород" in identity
	):
		amounts[&"stone"] = 1
		if _random_generator.randf() < 0.10:
			amounts[&"flint"] = 1
		return

	if "sand" in identity or "пес" in identity:
		amounts[&"sand"] = 1
		return

	if (
		"web" in identity
		or "cobweb" in identity
		or "паутин" in identity
	):
		amounts[&"fiber"] = 1
		return

	if "chest" in identity or "сундук" in identity:
		amounts[&"plank_scraps"] = 1
		return

	if (
		"spike" in identity
		or "шип" in identity
	):
		amounts[&"iron_ore"] = 1


func _spawn_item_pickups(drops: Array[ItemStack], spawn_global_position: Vector2) -> void:
	var pickup_scene: PackedScene = item_pickup_scene

	if pickup_scene == null:
		pickup_scene = load(
			"res://data/items/item_pickup.tscn"
		) as PackedScene

	if pickup_scene == null:
		pickup_scene = load(
			"res://items/item_pickup.tscn"
		) as PackedScene

	if pickup_scene == null:
		push_error(
			"TerrainLayer: не назначена Item Pickup Scene и не найдена "
			+ "сцена item_pickup.tscn."
		)
		return

	var pickup_parent: Node = get_parent() if get_parent() != null else self
	for stack: ItemStack in drops:
		if stack == null or stack.is_empty():
			continue
		var pickup := pickup_scene.instantiate() as ItemPickup
		if pickup == null:
			push_error("Item Pickup Scene должна иметь корневой узел ItemPickup (Area2D).")
			return

		# Сначала передаём данные, затем помещаем объект в дерево.
		pickup.setup(stack.item_id, stack.amount)
		pickup_parent.add_child(pickup)
		pickup.global_position = spawn_global_position + Vector2(
			_random_generator.randf_range(-8.0, 8.0),
			-8.0
		)


func _destroy_block(
	cell_coordinates: Vector2i,
	block_type: BlockType
) -> void:
	_remaining_health_by_cell.erase(cell_coordinates)
	_spawn_block_break_effect(cell_coordinates, block_type)
	var spawn_position: Vector2 = get_cell_global_center(cell_coordinates)
	var created_drops: Array[ItemStack] = _create_block_drops(block_type)
	erase_cell(cell_coordinates)
	print("Разрушен блок «%s» в клетке %s" % [block_type.display_name, str(cell_coordinates)])
	if not created_drops.is_empty():
		block_drops_created.emit(created_drops, spawn_position)
		_spawn_item_pickups(created_drops, spawn_position)
