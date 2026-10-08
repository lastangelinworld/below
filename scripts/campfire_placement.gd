extends Node


const CAMPFIRE_SCENE: PackedScene = preload(
	"res://data/world/campfire.tscn"
)

const PREVIEW_BASE_TEXTURE: Texture2D = preload(
	"res://assets/campfire/0.png"
)


@export_group("Placement")

## Назначь сюда chest_container.tscn через Inspector.
@export var chest_scene: PackedScene

## Максимальная дальность установки от ног персонажа.
@export var maximum_distance: float = 96.0

## Смещение от центра персонажа к его ногам.
@export var player_feet_offset: Vector2 = Vector2(0.0, 14.0)

## Физические слои, которые запрещают размещение.
@export_flags_2d_physics var placement_collision_mask: int = 1

## Цвет допустимой установки.
@export var preview_allowed_color: Color = Color(
	0.35, 1.0, 0.4, 0.55
)

## Цвет запрещённой установки.
@export var preview_blocked_color: Color = Color(
	1.0, 0.3, 0.3, 0.5
)


var _terrain: TerrainLayer
var _preview: Node2D
var _preview_item_id: StringName = &""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_terrain = _find_terrain()

	if _terrain == null:
		push_error(
			"CampfirePlacement: не найден TerrainLayer."
		)


func _exit_tree() -> void:
	_clear_preview()


func _process(_delta: float) -> void:
	if get_tree().paused:
		_hide_preview()
		return

	var player: Node2D = _find_player()

	if player == null:
		_hide_preview()
		return

	var item_id: StringName = _get_selected_placeable_id(player)

	if item_id == &"":
		_hide_preview()
		return

	if _get_scene_for_item(item_id) == null:
		_hide_preview()
		return

	if not _ensure_terrain():
		_hide_preview()
		return

	var cell: Vector2i = _get_mouse_cell()
	var allowed: bool = _is_cell_valid_for_placement(
		cell,
		player
	)

	_show_preview(
		item_id,
		_get_structure_position(cell, item_id),
		preview_allowed_color if allowed else preview_blocked_color
	)


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return

	if not event.is_action_pressed("secondary_action"):
		return

	if event.is_echo():
		return

	var player: Node2D = _find_player()

	if player == null:
		return

	var inventory: Variant = player.get("inventory")

	if inventory == null:
		return

	var slot_index: int = _get_selected_slot_index(player)
	var stack: Variant = inventory.get_slot(slot_index)

	if stack == null:
		return

	if stack.is_empty():
		return

	var item_id: StringName = stack.item_id

	if item_id != &"campfire" and item_id != &"chest":
		return

	# Выбран устанавливаемый предмет.
	# Даже неудачная установка не должна передавать это
	# нажатие другим обработчикам _unhandled_input.
	get_viewport().set_input_as_handled()

	var scene: PackedScene = _get_scene_for_item(item_id)

	if scene == null:
		push_warning(
			"CampfirePlacement: назначь Chest Scene в Inspector."
		)
		return

	if not _ensure_terrain():
		return

	var cell: Vector2i = _get_mouse_cell()

	# Та же проверка используется для цвета проекции.
	if not _is_cell_valid_for_placement(cell, player):
		return

	var world: Node = get_tree().current_scene

	if world == null:
		return

	var instance: Node = scene.instantiate()

	if not instance is Node2D:
		instance.free()
		push_error(
			"CampfirePlacement: корень сцены должен быть Node2D."
		)
		return

	var structure: Node2D = instance as Node2D
	var world_position: Vector2 = _get_structure_position(
		cell,
		item_id
	)

	# Сохраняем занятую клетку отдельно от позиции корня.
	# У сундука корень находится на нижней границе клетки.
	structure.set_meta("placement_cell", cell)
	structure.set_meta("placement_item_id", item_id)
	structure.add_to_group("placeable_structure")

	if item_id == &"chest":
		structure.add_to_group("chest")
	else:
		structure.add_to_group("campfire")

	# Задаём позицию до _ready() создаваемого объекта.
	if world is Node2D:
		structure.position = (
			(world as Node2D).to_local(world_position)
		)
	else:
		structure.position = world_position

	world.add_child(structure)

	# Расходуем предмет только после создания объекта.
	inventory.remove_from_slot(slot_index, 1)

	_hide_preview()


func _get_selected_slot_index(player: Node2D) -> int:
	var hotbar_index: int = clampi(
		int(player.get_meta("selected_hotbar_index", 0)),
		0,
		8
	)

	# Слоты панели быстрого доступа: 27–35.
	return 27 + hotbar_index


func _get_selected_placeable_id(
	player: Node2D
) -> StringName:
	var inventory: Variant = player.get("inventory")

	if inventory == null:
		return &""

	var stack: Variant = inventory.get_slot(
		_get_selected_slot_index(player)
	)

	if stack == null:
		return &""

	if stack.is_empty():
		return &""

	var item_id: StringName = stack.item_id

	if item_id == &"campfire" or item_id == &"chest":
		return item_id

	return &""


func _get_scene_for_item(
	item_id: StringName
) -> PackedScene:
	match item_id:
		&"campfire":
			return CAMPFIRE_SCENE
		&"chest":
			return chest_scene

	return null


func _ensure_terrain() -> bool:
	if _terrain == null or not is_instance_valid(_terrain):
		_terrain = _find_terrain()

	return _terrain != null


func _get_mouse_cell() -> Vector2i:
	var viewport: Viewport = get_viewport()
	var mouse_world_position: Vector2 = (
		viewport.get_canvas_transform().affine_inverse()
		* viewport.get_mouse_position()
	)

	return _terrain.global_position_to_cell(
		mouse_world_position
	)


func _get_structure_position(
	cell: Vector2i,
	item_id: StringName
) -> Vector2:
	var center: Vector2 = _terrain.get_cell_global_center(cell)

	if item_id == &"chest":
		var below_center: Vector2 = (
			_terrain.get_cell_global_center(
				cell + Vector2i(0, 1)
			)
		)

		# Для текущей сцены сундука корень — нижняя точка.
		# Размещаем его на границе с блоком-основанием.
		return center + (below_center - center) * 0.5

	# Положение костра сохраняем прежним.
	return center


func _is_cell_valid_for_placement(
	cell: Vector2i,
	player: Node2D
) -> bool:
	if _terrain == null or player == null:
		return false

	# Клетка размещения должна быть пустой.
	if _terrain.has_block_at_cell(cell):
		return false

	# Под ней должен находиться блок.
	if not _terrain.has_block_at_cell(
		cell + Vector2i(0, 1)
	):
		return false

	var player_cell: Vector2i = (
		_terrain.global_position_to_cell(
			player.global_position
		)
	)

	if cell == player_cell:
		return false

	var feet_position: Vector2 = (
		player.global_position + player_feet_offset
	)

	var cell_center: Vector2 = (
		_terrain.get_cell_global_center(cell)
	)

	if cell_center.distance_to(feet_position) > maximum_distance:
		return false

	if _has_structure_at_cell(cell):
		return false

	if _has_physics_object_in_cell(cell, player):
		return false

	return true


func _is_structure(node: Node) -> bool:
	return (
		node is ChestContainer
		or node is Campfire
		or node.is_in_group("placeable_structure")
		or node.is_in_group("storage_chest")
		or node.is_in_group("campfire_interactable")
		or node.is_in_group("campfire")
		or node.is_in_group("chest")
		or node.is_in_group("building")
	)


func _has_structure_at_cell(cell: Vector2i) -> bool:
	var world: Node = get_tree().current_scene

	if world == null or _terrain == null:
		return false

	var nodes: Array[Node] = world.find_children(
		"*",
		"",
		true,
		false
	)

	var cell_down: Vector2 = (
		_terrain.get_cell_global_center(
			cell + Vector2i(0, 1)
		)
		- _terrain.get_cell_global_center(cell)
	)

	for node: Node in nodes:
		if not node is Node2D:
			continue

		if not _is_structure(node):
			continue

		var saved_cell: Variant = node.get_meta(
			"placement_cell",
			null
		)

		# Объекты, поставленные этим скриптом.
		if saved_cell is Vector2i:
			if saved_cell == cell:
				return true
			continue

		# Объекты, заранее добавленные в сцену.
		var position_to_check: Vector2 = (
			(node as Node2D).global_position
		)

		if (
			node is ChestContainer
			or node.is_in_group("storage_chest")
			or node.is_in_group("chest")
		):
			# Корень текущей сцены сундука расположен снизу.
			position_to_check -= cell_down * 0.5

		var occupied_cell: Vector2i = (
			_terrain.global_position_to_cell(
				position_to_check
			)
		)

		if occupied_cell == cell:
			return true

	return false


func _has_physics_object_in_cell(
	cell: Vector2i,
	player: Node2D
) -> bool:
	var world_2d: World2D = player.get_world_2d()

	if world_2d == null:
		return false

	var center: Vector2 = _terrain.get_cell_global_center(cell)
	var cell_right: Vector2 = (
		_terrain.get_cell_global_center(
			cell + Vector2i(1, 0)
		)
		- center
	)
	var cell_down: Vector2 = (
		_terrain.get_cell_global_center(
			cell + Vector2i(0, 1)
		)
		- center
	)

	var shape: RectangleShape2D = RectangleShape2D.new()

	# Проверяем почти всю клетку, а не только её центр.
	# Отступ от границ исключает касание соседних блоков.
	shape.size = Vector2(
		maxf(1.0, cell_right.length() - 2.0),
		maxf(1.0, cell_down.length() - 2.0)
	)

	var query: PhysicsShapeQueryParameters2D = (
		PhysicsShapeQueryParameters2D.new()
	)

	query.shape = shape
	query.transform = Transform2D(cell_right.angle(), center)
	query.collision_mask = placement_collision_mask
	query.collide_with_bodies = true

	# Зона взаимодействия или подбора не является стеной.
	# Строения без физического тела проверяются отдельно.
	query.collide_with_areas = false

	if player is CollisionObject2D:
		query.exclude = [
			(player as CollisionObject2D).get_rid()
		]

	var results: Array[Dictionary] = (
		world_2d.direct_space_state.intersect_shape(
			query,
			32
		)
	)

	for result: Dictionary in results:
		var collider: Object = result.get("collider")

		if collider == null or collider == player:
			continue

		if collider is Node:
			var collider_node: Node = collider as Node

			if player.is_ancestor_of(collider_node):
				continue

			if collider_node.is_in_group("player"):
				continue

		return true

	return false


func _ensure_preview(item_id: StringName) -> bool:
	if (
		is_instance_valid(_preview)
		and _preview_item_id == item_id
	):
		return true

	_clear_preview()

	var world: Node = get_tree().current_scene

	if world == null:
		return false

	_preview = Node2D.new()
	_preview.name = "PlacementPreview"
	_preview.z_index = 100
	_preview.visible = false

	if item_id == &"campfire":
		var base: Sprite2D = Sprite2D.new()
		base.texture = PREVIEW_BASE_TEXTURE
		base.scale = Vector2(0.5, 0.5)
		_preview.add_child(base)

	elif item_id == &"chest":
		if chest_scene == null:
			_clear_preview()
			return false

		# Не добавляем исходный сундук в дерево:
		# его _ready(), хранение и физика не запускаются.
		var source: Node = chest_scene.instantiate()

		if source is Node2D:
			_preview.scale = (source as Node2D).scale

		# Копируем только изображение текущей сцены.
		# duplicate(0) не переносит скрипты и группы.
		var placeholder: Node = source.get_node_or_null(
			"Placeholder"
		)

		if placeholder != null:
			_preview.add_child(placeholder.duplicate(0))

		var sprite: Node = source.get_node_or_null(
			"Sprite2D"
		)

		if sprite != null:
			_preview.add_child(sprite.duplicate(0))

		source.free()

		if _preview.get_child_count() == 0:
			push_warning(
				"CampfirePlacement: у сундука нет узлов изображения."
			)
			_clear_preview()
			return false

	else:
		_clear_preview()
		return false

	world.add_child(_preview)
	_preview_item_id = item_id

	return true


func _show_preview(
	item_id: StringName,
	world_position: Vector2,
	color: Color
) -> void:
	if not _ensure_preview(item_id):
		return

	_preview.global_position = world_position
	_preview.modulate = color
	_preview.visible = true


func _hide_preview() -> void:
	if is_instance_valid(_preview):
		_preview.visible = false


func _clear_preview() -> void:
	if is_instance_valid(_preview):
		_preview.visible = false
		_preview.queue_free()

	_preview = null
	_preview_item_id = &""


func _find_player() -> Node2D:
	var grouped: Node = get_tree().get_first_node_in_group(
		"player"
	)

	if grouped is Node2D:
		return grouped as Node2D

	var world: Node = get_tree().current_scene

	if world == null:
		return null

	return world.get_node_or_null("Player") as Node2D


func _find_terrain() -> TerrainLayer:
	var grouped: Node = get_tree().get_first_node_in_group(
		"terrain"
	)

	if grouped is TerrainLayer:
		return grouped as TerrainLayer

	var world: Node = get_tree().current_scene

	if world == null:
		return null

	var direct: Node = world.get_node_or_null("Terrain")

	if direct is TerrainLayer:
		return direct as TerrainLayer

	var layers: Array[Node] = world.find_children(
		"*",
		"TileMapLayer",
		true,
		false
	)

	for node: Node in layers:
		if node is TerrainLayer:
			return node as TerrainLayer

	return null
