class_name ItemPickup
extends Area2D

@export var item_id: StringName = &""
@export_range(1, 9999, 1) var amount := 1
@export_range(0.05, 2.0, 0.05) var retry_interval := 0.35
@onready var item_sprite: Sprite2D = $ItemSprite
@onready var amount_label: Label = $AmountLabel

var _players_inside: Array[Node] = []
var _retry_left := 0.0
var _auto_pickup_unix := 0.0

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
