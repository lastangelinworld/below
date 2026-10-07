extends Node


const CAMPFIRE_SCENE := preload(
	"res://data/world/campfire.tscn"
)

const INVALID_CELL: Vector2i = Vector2i(
	2147483647,
	2147483647
)

## Текстура-основание костра для полупрозрачного превью.
const PREVIEW_BASE_TEXTURE := preload(
	"res://assets/campfire/0.png"
)


@export_group("Placement")

## Максимальная дальность установки от ног персонажа.
@export var maximum_distance: float = 96.0

## Смещение от центра персонажа к его ногам.
@export var player_feet_offset: Vector2 = Vector2(
	0.0,
	14.0
)

## Слой физических коллизий занятых объектов.
@export_flags_2d_physics var placement_collision_mask: int = 1

## Цвет проекции, когда костёр можно поставить.
@export var preview_allowed_color: Color = Color(0.35, 1.0, 0.4, 0.55)

## Цвет проекции, когда поставить нельзя.
@export var preview_blocked_color: Color = Color(1.0, 0.3, 0.3, 0.5)


var _terrain: TerrainLayer

## Полупрозрачный призрак будущего костра.
var _preview: Sprite2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_terrain = _find_terrain()

	if _terrain == null:
		push_error(
			"CampfirePlacement: не найден TerrainLayer."
		)


func _process(_delta: float) -> void:
	# Проекция видна, пока костёр в руке: зелёная — можно, красная — нельзя.
	if get_tree().paused:
		_hide_preview()
		return

	if not _selected_is_campfire():
		_hide_preview()
		return

	if _terrain == null or not is_instance_valid(_terrain):
		_terrain = _find_terrain()

	if _terrain == null:
		_hide_preview()
		return

	var player: Node2D = _find_player()

	if player == null:
		_hide_preview()
		return

	var viewport: Viewport = get_viewport()

	var mouse_world_position: Vector2 = (
		viewport.get_canvas_transform().affine_inverse()
		* viewport.get_mouse_position()
	)

	var placement_cell: Vector2i = (
		_terrain.global_position_to_cell(
			mouse_world_position
		)
	)

	var placement_position: Vector2 = (
		_terrain.get_cell_global_center(
			placement_cell
		)
	)

	var is_allowed: bool = _is_cell_valid_for_placement(
		placement_cell,
		player
	)

	_show_preview(
		placement_position,
		preview_allowed_color if is_allowed else preview_blocked_color
	)


## Возвращает true, если в выбранном слоте панели лежит костёр.
func _selected_is_campfire() -> bool:
	var player: Node2D = _find_player()

	if player == null:
		return false

	var inventory = player.get("inventory")

	if inventory == null:
		return false

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

	var selected_stack = inventory.get_slot(
		27 + selected_hotbar_index
	)

	if selected_stack == null:
		return false

	if selected_stack.is_empty():
		return false

	return selected_stack.item_id == &"campfire"


func _ensure_preview() -> void:
	if _preview != null and is_instance_valid(_preview):
		return

	_preview = Sprite2D.new()
	_preview.texture = PREVIEW_BASE_TEXTURE
	_preview.scale = Vector2(0.5, 0.5)
	_preview.z_index = 100
	_preview.visible = false

	var world: Node = get_tree().current_scene

	if world != null:
		world.add_child(_preview)


func _show_preview(
	world_position: Vector2,
	preview_color: Color
) -> void:
	_ensure_preview()

	if _preview == null or not is_instance_valid(_preview):
		return

	if _preview.get_parent() == null:
		var world: Node = get_tree().current_scene

		if world != null:
			world.add_child(_preview)

	_preview.global_position = world_position
	_preview.modulate = preview_color
	_preview.visible = true


func _hide_preview() -> void:
	if _preview != null and is_instance_valid(_preview):
		_preview.visible = false


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
		_terrain.global_position_to_cell(
			mouse_world_position
		)
	)

	# Ставим только туда, где проекция зелёная.
	if not _is_cell_valid_for_placement(
		placement_cell,
		player
	):
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


## Проверяет, можно ли поставить костёр в конкретную клетку.
func _is_cell_valid_for_placement(
	cell_coordinates: Vector2i,
	player: Node2D
) -> bool:
	if _terrain == null or player == null:
		return false

	# Под костром обязан быть блок-основание.
	# Ось Y направлена вниз, поэтому клетка снизу — это Y + 1.
	if not _terrain.has_block_at_cell(
		cell_coordinates + Vector2i(0, 1)
	):
		return false

	var player_cell: Vector2i = (
		_terrain.global_position_to_cell(
			player.global_position
		)
	)

	# Нельзя ставить костёр в клетку персонажа.
	if cell_coordinates == player_cell:
		return false

	# Сама клетка должна быть свободной.
	if not _can_place_at_cell(
		cell_coordinates,
		player
	):
		return false

	var player_feet_position: Vector2 = (
		player.global_position + player_feet_offset
	)

	var placement_position: Vector2 = (
		_terrain.get_cell_global_center(
			cell_coordinates
		)
	)

	# Защита от установки слишком далеко.
	if (
		placement_position.distance_to(
			player_feet_position
		)
		> maximum_distance
	):
		return false

	return true


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
