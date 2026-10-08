extends Node

enum Mode { NORMAL, ATTACK, PICKUP, INTERACT }
const CURSORS := {
	Mode.NORMAL: preload("res://assets/cursors/cursor_normal.svg"),
	Mode.ATTACK: preload("res://assets/cursors/cursor_attack.svg"),
	Mode.PICKUP: preload("res://assets/cursors/cursor_pickup.svg"),
	Mode.INTERACT: preload("res://assets/cursors/cursor_interact.svg")
}
var _contexts: Dictionary = {}
var _mode := Mode.NORMAL

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply(Mode.NORMAL)

func set_context(source: Object, mode: Mode) -> void:
	if source != null:
		_contexts[source.get_instance_id()] = mode

func clear_context(source: Object) -> void:
	if source != null:
		_contexts.erase(source.get_instance_id())

func _process(_delta: float) -> void:
	var wanted := Mode.NORMAL
	for id in _contexts.keys():
		if not is_instance_id_valid(id):
			_contexts.erase(id)
			continue
		wanted = maxi(wanted, int(_contexts[id])) as Mode
	if wanted == Mode.NORMAL and not get_tree().paused:
		wanted = _world_context()
	if wanted != _mode:
		_apply(wanted)

func _world_context() -> Mode:
	var viewport := get_viewport()
	if viewport == null or viewport.get_world_2d() == null:
		return Mode.NORMAL
	var world_pos: Vector2 = viewport.get_canvas_transform().affine_inverse() * viewport.get_mouse_position()
	var query := PhysicsPointQueryParameters2D.new()
	query.position = world_pos
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hits := viewport.get_world_2d().direct_space_state.intersect_point(query, 12)
	for hit in hits:
		var collider: Object = hit.get("collider")
		if collider is Node and (collider as Node).is_in_group("interactable"):
			return Mode.INTERACT
		if collider is ItemPickup:
			return Mode.PICKUP
	for hit in hits:
		var collider: Object = hit.get("collider")
		if collider is Node and not (collider as Node).is_in_group("player"):
			if _looks_like_chest(collider, world_pos):
				return Mode.INTERACT
			return Mode.ATTACK
	return Mode.NORMAL

func _looks_like_chest(collider: Object, world_pos: Vector2) -> bool:
	if "chest" in str(collider).to_lower():
		return true
	if collider is TileMapLayer:
		var layer := collider as TileMapLayer
		var cell := layer.local_to_map(layer.to_local(world_pos))
		var data := layer.get_cell_tile_data(cell)
		if data != null:
			for key in [&"block_id", &"block_type", &"id", &"name", &"interaction"]:
				var value = _safe_custom_data(data, key)
				if "chest" in str(value).to_lower() or "сундук" in str(value).to_lower():
					return true
	return false

func _safe_custom_data(
	tile_data: TileData,
	layer_name: String
) -> Variant:
	if tile_data == null:
		return null

	if not tile_data.has_custom_data(layer_name):
		return null

	return tile_data.get_custom_data(layer_name)

func _apply(mode: Mode) -> void:
	_mode = mode
	Input.set_custom_mouse_cursor(CURSORS[mode], Input.CURSOR_ARROW, Vector2(3, 3))
