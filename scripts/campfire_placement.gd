extends Node


const CAMPFIRE_SCENE := preload(
	"res://data/world/campfire.tscn"
)

const INVALID_CELL: Vector2i = Vector2i(
	2147483647,
	2147483647
)


@export_group("Placement")

## Максимальная дальность установки от ног персонажа.
@export var maximum_distance: float = 96.0

## Смещение от центра персонажа к его ногам.
@export var player_feet_offset: Vector2 = Vector2(
	0.0,
	14.0
)

## Количество клеток по горизонтали,
## в которых разрешён поиск поверхности.
@export var horizontal_cells_from_player: int = 1

## Сколько рядов ниже ног персонажа
## проверять в поисках блока-основания.
@export var support_rows_below_feet: int = 2

## Слой физических коллизий занятых объектов.
@export_flags_2d_physics var placement_collision_mask: int = 1


var _terrain: TerrainLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_terrain = _find_terrain()

	if _terrain == null:
		push_error(
			"CampfirePlacement: не найден TerrainLayer."
		)


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return

	if not event.is_action_pressed("secondary_action"):
		return

	var player: Node2D = _find_player()

	if player == null:
		push_warning(
			"CampfirePlacement: игрок не найден."
		)
		return

	var inventory = player.get("inventory")

	if inventory == null:
		push_warning(
			"CampfirePlacement: у игрока не найден InventoryData."
		)
		return

	var selected_hotbar_index: int = clampi(
		int(
			player.get_meta(
				"selected_hotbar_index",
				0
			)
		),
		0,
		8
	)

	# Слоты панели быстрого доступа: 27–35.
	var inventory_slot_index: int = (
		27 + selected_hotbar_index
	)

	var selected_stack = inventory.get_slot(
		inventory_slot_index
	)

	if selected_stack == null:
		return

	if selected_stack.is_empty():
		return

	if selected_stack.item_id != &"campfire":
		return

	if _terrain == null or not is_instance_valid(_terrain):
		_terrain = _find_terrain()

	if _terrain == null:
		return

	var viewport: Viewport = get_viewport()

	var mouse_world_position: Vector2 = (
		viewport.get_canvas_transform().affine_inverse()
		* viewport.get_mouse_position()
	)

	var placement_cell: Vector2i = (
		_find_best_placement_cell(
			player,
			mouse_world_position
		)
	)

	if placement_cell == INVALID_CELL:
		return

	var placement_position: Vector2 = (
		_terrain.get_cell_global_center(
			placement_cell
		)
	)

	var campfire: Node = CAMPFIRE_SCENE.instantiate()

	if campfire == null:
		push_error(
			"CampfirePlacement: не удалось создать campfire.tscn."
		)
		return

	var world: Node = get_tree().current_scene

	if world == null:
		push_error(
			"CampfirePlacement: отсутствует текущая игровая сцена."
		)
		return

	world.add_child(campfire)

	if campfire is Node2D:
		var campfire_2d: Node2D = campfire as Node2D
		campfire_2d.global_position = placement_position

	inventory.remove_from_slot(
		inventory_slot_index,
		1
	)

	viewport.set_input_as_handled()


func _find_best_placement_cell(
	player: Node2D,
	mouse_world_position: Vector2
) -> Vector2i:
	if _terrain == null:
		return INVALID_CELL

	var player_feet_position: Vector2 = (
		player.global_position + player_feet_offset
	)

	var feet_cell: Vector2i = (
		_terrain.global_position_to_cell(
			player_feet_position
		)
	)

	var player_cell: Vector2i = (
		_terrain.global_position_to_cell(
			player.global_position
		)
	)

	var valid_cells: Array[Vector2i] = []

	# Ищем существующие блоки рядом с ногами.
	# Костёр ставится в клетку непосредственно над блоком.
	for offset_y: int in range(
		0,
		support_rows_below_feet + 1
	):
		for offset_x: int in range(
			-horizontal_cells_from_player,
			horizontal_cells_from_player + 1
		):
			var support_cell: Vector2i = (
				feet_cell
				+ Vector2i(offset_x, offset_y)
			)

			# В клетке-основании должен находиться блок.
			if not _terrain.has_block_at_cell(
				support_cell
			):
				continue

			# В Godot ось Y направлена вниз,
			# поэтому клетка сверху имеет координату Y - 1.
			var placement_cell: Vector2i = (
				support_cell + Vector2i(0, -1)
			)

			# Нельзя ставить костёр в клетку персонажа.
			if placement_cell == player_cell:
				continue

			# Клетка над блоком должна быть свободной.
			if not _can_place_at_cell(
				placement_cell,
				player
			):
				continue

			var placement_position: Vector2 = (
				_terrain.get_cell_global_center(
					placement_cell
				)
			)

			# Защита от установки слишком далеко.
			if (
				placement_position.distance_to(
					player_feet_position
				)
				> maximum_distance
			):
				continue

			if not valid_cells.has(placement_cell):
				valid_cells.append(placement_cell)

	if valid_cells.is_empty():
		return INVALID_CELL

	# Курсор выбирает ближайшую разрешённую клетку.
	# Он не может выбрать произвольную клетку в воздухе.
	var best_cell: Vector2i = valid_cells[0]
	var best_distance: float = INF

	for candidate_cell: Vector2i in valid_cells:
		var candidate_position: Vector2 = (
			_terrain.get_cell_global_center(
				candidate_cell
			)
		)

		var distance_to_mouse: float = (
			candidate_position.distance_squared_to(
				mouse_world_position
			)
		)

		if distance_to_mouse < best_distance:
			best_distance = distance_to_mouse
			best_cell = candidate_cell

	return best_cell


func _can_place_at_cell(
	cell_coordinates: Vector2i,
	player: Node2D
) -> bool:
	if _terrain == null:
		return false

	# Нельзя ставить костёр поверх блока.
	if _terrain.has_block_at_cell(
		cell_coordinates
	):
		return false

	# Нельзя ставить второй объект в той же клетке.
	if _has_structure_at_cell(
		cell_coordinates
	):
		return false

	var cell_position: Vector2 = (
		_terrain.get_cell_global_center(
			cell_coordinates
		)
	)

	# Проверка физических объектов в клетке.
	if _has_physics_object_at_position(
		cell_position,
		player
	):
		return false

	return true


func _has_structure_at_cell(
	cell_coordinates: Vector2i
) -> bool:
	var world: Node = get_tree().current_scene

	if world == null or _terrain == null:
		return false

	var all_nodes: Array[Node] = world.find_children(
		"*",
		"",
		true,
		false
	)

	for node: Node in all_nodes:
		if not is_instance_valid(node):
			continue

		if node == self:
			continue

		if not node is Node2D:
			continue

		if node.is_in_group("player"):
			continue

		var node_2d: Node2D = node as Node2D

		if node_2d == null:
			continue

		var is_structure: bool = (
			node.is_in_group("placeable_structure")
			or node.is_in_group("campfire")
			or node.is_in_group("chest")
			or node.is_in_group("building")
		)

		var node_name: String = (
			str(node.name).to_lower()
		)

		if (
			"campfire" in node_name
			or "костер" in node_name
			or "костёр" in node_name
			or "chest" in node_name
			or "сундук" in node_name
		):
			is_structure = true

		if not is_structure:
			continue

		var node_cell: Vector2i = (
			_terrain.global_position_to_cell(
				node_2d.global_position
			)
		)

		if node_cell == cell_coordinates:
			return true

	return false


func _has_physics_object_at_position(
	world_position: Vector2,
	player: Node2D
) -> bool:
	if player == null:
		return false

	var world_2d: World2D = player.get_world_2d()

	if world_2d == null:
		return false

	var query := PhysicsPointQueryParameters2D.new()

	query.position = world_position
	query.collision_mask = placement_collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = true

	var results: Array[Dictionary] = (
		world_2d.direct_space_state.intersect_point(
			query,
			32
		)
	)

	for result: Dictionary in results:
		var collider: Object = result.get(
			"collider"
		)

		if collider == null:
			continue

		if collider == player:
			continue

		if collider is Node:
			var collider_node: Node = collider as Node

			if collider_node == null:
				continue

			if collider_node == player:
				continue

			if collider_node.is_in_group(
				"player"
			):
				continue

			if collider_node.is_in_group(
				"terrain"
			):
				return true

			if collider_node.is_in_group(
				"campfire"
			):
				return true

			if collider_node.is_in_group(
				"placeable_structure"
			):
				return true

			if collider_node.is_in_group(
				"building"
			):
				return true

			if collider_node.is_in_group(
				"chest"
			):
				return true

			var collider_name: String = (
				str(collider_node.name).to_lower()
			)

			if (
				"campfire" in collider_name
				or "костер" in collider_name
				or "костёр" in collider_name
				or "chest" in collider_name
				or "сундук" in collider_name
			):
				return true

		# Любой другой физический объект
		# считается занятой клеткой.
		return true

	return false


func _find_player() -> Node2D:
	var player_from_group: Node = (
		get_tree().get_first_node_in_group(
			"player"
		)
	)

	if player_from_group is Node2D:
		return player_from_group as Node2D

	var world: Node = get_tree().current_scene

	if world == null:
		return null

	var player_node: Node = world.get_node_or_null(
		"Player"
	)

	if player_node is Node2D:
		return player_node as Node2D

	return null


func _find_terrain() -> TerrainLayer:
	var terrain_from_group: Node = (
		get_tree().get_first_node_in_group(
			"terrain"
		)
	)

	if terrain_from_group is TerrainLayer:
		return terrain_from_group as TerrainLayer

	var world: Node = get_tree().current_scene

	if world == null:
		return null

	var terrain_node: Node = world.get_node_or_null(
		"Terrain"
	)

	if terrain_node is TerrainLayer:
		return terrain_node as TerrainLayer

	var tile_map_layers: Array[Node] = (
		world.find_children(
			"*",
			"TileMapLayer",
			true,
			false
		)
	)

	for node: Node in tile_map_layers:
		if node is TerrainLayer:
			return node as TerrainLayer

	return null
