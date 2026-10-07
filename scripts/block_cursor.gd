extends Node2D


## Ссылка на игрока.
## Назначается через Inspector.
@export var player: CharacterBody2D

## Необязательная надпись с информацией о блоке.
@export var debug_label: Label

## Максимальная дальность взаимодействия в клетках.
@export_range(1.0, 10.0, 0.5)
var max_reach_in_tiles: float = 5.0

## Если включено, курсор берёт дальность из экспортируемого параметра игрока,
## когда у игрока есть свойство mining_reach_in_tiles.
@export var use_player_mining_reach: bool = true


## BlockCursor должен быть дочерним узлом Terrain.
@onready var terrain: TerrainLayer = (
	get_parent() as TerrainLayer
)


var target_cell: Vector2i = Vector2i.ZERO
var target_block: BlockType = null
var target_distance: float = 0.0
var target_in_range: bool = false
var _tile_size: Vector2 = Vector2(32.0, 32.0)


func _ready() -> void:
	z_index = 100

	if terrain == null:
		push_error(
			"BlockCursor должен быть дочерним узлом Terrain."
		)
		set_process(false)
		return

	if player == null:
		push_error(
			"Для BlockCursor не назначен Player в Inspector."
		)
		set_process(false)
		return

	if terrain.tile_set != null:
		_tile_size = Vector2(
			terrain.tile_set.tile_size.x,
			terrain.tile_set.tile_size.y
		)

	queue_redraw()


func _process(_delta: float) -> void:
	if terrain == null or player == null:
		return

	target_cell = terrain.global_position_to_cell(
		get_global_mouse_position()
	)

	target_block = terrain.get_block_type_at_cell(
		target_cell
	)

	var cell_local_center: Vector2 = (
		terrain.map_to_local(target_cell)
	)
	var cell_global_center: Vector2 = (
		terrain.to_global(cell_local_center)
	)

	target_distance = player.global_position.distance_to(
		cell_global_center
	)

	var tile_length: float = maxf(_tile_size.x, _tile_size.y)
	var effective_reach_in_tiles: float = max_reach_in_tiles
	if use_player_mining_reach:
		var reach_value: Variant = player.get("mining_reach_in_tiles")
		if reach_value != null:
			effective_reach_in_tiles = maxf(0.0, float(reach_value))

	# Сначала используем полную проверку доступности: соседство с телом,
	# клетку за персонажем и условное открытие верхних углов.
	# Резервные ветки оставлены для совместимости со старыми Player.
	if player.has_method("is_cell_mineable"):
		target_in_range = bool(player.call("is_cell_mineable", target_cell))
	elif use_player_mining_reach and player.has_method("is_cell_in_mining_reach"):
		target_in_range = bool(player.call("is_cell_in_mining_reach", target_cell))
	else:
		target_in_range = target_distance <= effective_reach_in_tiles * tile_length

	position = cell_local_center
	visible = target_block != null

	_update_debug_label()
	queue_redraw()


func _draw() -> void:
	if target_block == null:
		return

	var top_left := Vector2(
		-_tile_size.x * 0.5,
		-_tile_size.y * 0.5
	)

	var rectangle := Rect2(
		top_left,
		_tile_size
	)

	var fill_color: Color
	var outline_color: Color

	if not target_in_range:
		fill_color = Color(1.0, 0.1, 0.1, 0.18)
		outline_color = Color(1.0, 0.2, 0.2, 1.0)
	elif not target_block.breakable:
		fill_color = Color(1.0, 0.55, 0.1, 0.18)
		outline_color = Color(1.0, 0.65, 0.15, 1.0)
	else:
		fill_color = Color(0.1, 1.0, 0.35, 0.18)
		outline_color = Color(0.2, 1.0, 0.4, 1.0)

	draw_rect(
		rectangle,
		fill_color,
		true
	)

	draw_rect(
		rectangle,
		outline_color,
		false,
		2.0
	)


func _update_debug_label() -> void:
	if debug_label == null:
		return

	if target_block == null:
		debug_label.text = (
			"Цель: воздух\nКлетка: %s"
			% str(target_cell)
		)
		return

	var range_text: String = (
		"Да" if target_in_range else "Нет"
	)
	var breakable_text: String = (
		"Да" if target_block.breakable else "Нет"
	)
	var solid_text: String = (
		"Да" if target_block.solid else "Нет"
	)
	var gravity_text: String = (
		"Да" if target_block.affected_by_gravity else "Нет"
	)

	var drop_text: String = "ничего"

	if (
		target_block.drop_item_id != &""
		and target_block.drop_amount > 0
	):
		drop_text = "%s × %d" % [
			str(target_block.drop_item_id),
			target_block.drop_amount
		]

	var current_health: int = (
		terrain.get_block_health_at_cell(target_cell)
	)

	debug_label.text = (
		"Блок: %s [%s]\n"
		+ "Клетка: %s\n"
		+ "Прочность: %d/%d\n"
		+ "Можно разрушить: %s\n"
		+ "Непроходимый: %s\n"
		+ "Падает без опоры: %s\n"
		+ "Нужный уровень инструмента: %d\n"
		+ "Добыча: %s\n"
		+ "Шум от удара: %d\n"
		+ "Расстояние: %.0f px\n"
		+ "Клетка доступна для добычи: %s"
	) % [
		target_block.display_name,
		str(target_block.block_id),
		str(target_cell),
		current_health,
		target_block.max_health,
		breakable_text,
		solid_text,
		gravity_text,
		target_block.required_tool_level,
		drop_text,
		target_block.noise_per_hit,
		target_distance,
		range_text
	]


func has_valid_mining_target() -> bool:
	return (
		target_block != null
		and target_in_range
		and target_block.breakable
	)


func get_target_cell() -> Vector2i:
	return target_cell


func get_target_block() -> BlockType:
	return target_block
