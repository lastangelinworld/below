class_name ItemPickup
extends Area2D

@export var item_id: StringName = &""
@export_range(1, 9999, 1) var amount := 1
@export_range(0.05, 2.0, 0.05) var retry_interval := 0.35

@export_group("Падение")
## Ускорение падения выпавшего предмета.
@export_range(0.0, 4000.0, 10.0) var fall_acceleration := 900.0
## Предельная скорость падения.
@export_range(0.0, 2000.0, 10.0) var maximum_fall_speed := 600.0
## Насколько центр предмета приподнят над поверхностью блока.
@export_range(0.0, 32.0, 1.0) var ground_offset := 8.0

@onready var item_sprite: Sprite2D = $ItemSprite
@onready var amount_label: Label = $AmountLabel

var _players_inside: Array[Node] = []
var _retry_left := 0.0
var _auto_pickup_unix := 0.0
var _fall_speed := 0.0
var _terrain: TerrainLayer

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	input_event.connect(_on_input_event)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_refresh_visual()

func setup(new_item_id: StringName, new_amount: int) -> void:
	item_id = new_item_id
	amount = maxi(new_amount, 1)
	if is_node_ready():
		_refresh_visual()

func block_automatic_pickup(seconds: float = 1800.0) -> void:
	_auto_pickup_unix = Time.get_unix_time_from_system() + maxf(seconds, 0.0)

func _physics_process(delta: float) -> void:
	if _terrain == null or not is_instance_valid(_terrain):
		_terrain = _find_terrain()
	if _terrain == null:
		return

	# Клетка прямо под предметом: если там блок, значит лежим на земле.
	var support_cell: Vector2i = _terrain.global_position_to_cell(
		global_position + Vector2(0.0, ground_offset + 1.0)
	)

	if _terrain.has_block_at_cell(support_cell):
		_fall_speed = 0.0
		var cell_center: Vector2 = _terrain.get_cell_global_center(support_cell)
		var cell_height: float = 32.0
		if _terrain.tile_set != null:
			cell_height = float(_terrain.tile_set.tile_size.y)
		global_position.y = cell_center.y - cell_height * 0.5 - ground_offset
		return

	_fall_speed = minf(_fall_speed + fall_acceleration * delta, maximum_fall_speed)
	global_position.y += _fall_speed * delta

func _find_terrain() -> TerrainLayer:
	var from_group := get_tree().get_first_node_in_group("terrain")
	if from_group is TerrainLayer:
		return from_group as TerrainLayer
	var world := get_tree().current_scene
	if world == null:
		return null
	var named := world.get_node_or_null("Terrain")
	if named is TerrainLayer:
		return named as TerrainLayer
	for node: Node in world.find_children("*", "TileMapLayer", true, false):
		if node is TerrainLayer:
			return node as TerrainLayer
	return null

func _process(delta: float) -> void:
	if _players_inside.is_empty() or Time.get_unix_time_from_system() < _auto_pickup_unix:
		return
	_retry_left -= delta
	if _retry_left <= 0.0:
		_retry_left = retry_interval
		_try_pickup(_players_inside[0], false)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player") and body.get("inventory") == null:
		return
	if not _players_inside.has(body):
		_players_inside.append(body)
	_try_pickup(body, false)

func _on_body_exited(body: Node) -> void:
	_players_inside.erase(body)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		var player := get_tree().get_first_node_in_group("player")
		if player != null:
			_try_pickup(player, true)
			get_viewport().set_input_as_handled()

func _try_pickup(player: Node, manual: bool) -> void:
	if amount <= 0:
		queue_free()
		return
	if not manual and Time.get_unix_time_from_system() < _auto_pickup_unix:
		return
	var accepted := 0
	if player.has_method("receive_item"):
		accepted = int(player.call("receive_item", item_id, amount))
	else:
		var inventory := player.get("inventory") as InventoryData
		if inventory != null:
			accepted = inventory.add_item(item_id, amount)
	amount -= accepted
	if amount <= 0:
		queue_free()
	else:
		_refresh_visual()

func _refresh_visual() -> void:
	var item: ItemData = ItemRegistry.get_item(item_id)
	item_sprite.texture = item.icon if item != null else null
	amount_label.text = str(amount) if amount > 1 else ""
 

func _on_mouse_entered() -> void:
	GameCursor.set_context(self, GameCursor.Mode.PICKUP)

func _on_mouse_exited() -> void:
	GameCursor.clear_context(self)
