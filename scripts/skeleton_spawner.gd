class_name SkeletonSpawner
extends StaticBody2D

## Каменный постамент, спавнящий скелетов каждые 15 секунд.
## Максимум 2 скелета одновременно: 1 мечник + 1 лучник.
## Ставится как костёр — ПКМ по горячему слоту.
## Скелеты появляются только на соседней горизонтальной клетке
## с твёрдым основанием; при отсутствии такой клетки спавна нет.

signal skeleton_spawned

const SPAWN_INTERVAL: float = 15.0
const MAX_SKELETONS: int = 2
const SPAWN_SCENE_PATH: String = "res://data/world/skeleton.tscn"
const ARROW_SCENE_PATH: String = "res://data/world/arrow_projectile.tscn"

## Порядок проверки соседних клеток: сначала лево, затем право.
const NEIGHBOUR_OFFSETS: Array[Vector2i] = [
	Vector2i(-1, 0),
	Vector2i(1, 0)
]

## Возвращается, когда пригодной клетки рядом нет.
const INVALID_CELL: Vector2i = Vector2i(-4096, -4096)

var _spawn_timer: float = 0.0
var _skeleton_count: int = 0
var _melee_spawned: bool = false
var _ranged_spawned: bool = false
var _world: Node
var _terrain: TerrainLayer

## Занятые клетки, собранные за один обход дерева:
## скелеты, постаменты и клетка игрока.
var _occupied_cells: Dictionary = {}


func _ready() -> void:
	# Слой враждебных тел: не мешает проверкам размещения (маска 1).
	collision_layer = 8
	collision_mask = 1
	add_to_group("placeable_structure")
	add_to_group("spawner")
	_world = get_tree().current_scene
	_terrain = _find_terrain()
	_spawn_timer = SPAWN_INTERVAL


func _physics_process(delta: float) -> void:
	_update_skeleton_count()
	if _skeleton_count >= MAX_SKELETONS:
		return
	_spawn_timer += delta
	if _spawn_timer >= SPAWN_INTERVAL:
		_spawn_timer = 0.0
		_try_spawn()


## Считает живых скелетов по типам и заодно собирает занятые клетки.
func _update_skeleton_count() -> void:
	_skeleton_count = 0
	_melee_spawned = false
	_ranged_spawned = false
	_occupied_cells.clear()

	if _world == null or _terrain == null:
		return

	for node: Node in _world.find_children("*", "", true, false):
		if not node is Node2D:
			continue

		if node is Skeleton:
			_skeleton_count += 1
			if node.is_in_group("melee_enemy"):
				_melee_spawned = true
			if node.is_in_group("ranged_enemy"):
				_ranged_spawned = true

		# В клетке игрока спавнить нельзя: скелет окажется внутри него.
		if node is Skeleton or node is SkeletonSpawner or node.is_in_group("player"):
			_occupied_cells[
				_terrain.global_position_to_cell(
					(node as Node2D).global_position
				)
			] = true


## Попытка спавна одного скелета.
func _try_spawn() -> void:
	if _world == null:
		return

	# Без террейна определить свободную клетку невозможно.
	if _terrain == null or not is_instance_valid(_terrain):
		_terrain = _find_terrain()
	if _terrain == null:
		return

	var spawn_cell: Vector2i = _find_spawn_cell()

	# Нет соседней свободной клетки — скелеты не появляются,
	# но таймер уже сброшен: повторная попытка через интервал.
	if spawn_cell == INVALID_CELL:
		return

	var skeleton_scene: PackedScene = (
		load(SPAWN_SCENE_PATH) as PackedScene
	)
	if skeleton_scene == null:
		push_error(
			"Спавнер: не найдена сцена скелета: " + SPAWN_SCENE_PATH
		)
		return

	# Сначала спавним недостающий тип.
	var make_melee: bool
	if not _melee_spawned:
		make_melee = true
	elif not _ranged_spawned:
		make_melee = false
	else:
		make_melee = randf() < 0.5

	_spawn_one(skeleton_scene, make_melee, spawn_cell)


## Ищет соседнюю горизонтальную клетку, пригодную для спавна:
## сама клетка пуста, под ней твёрдый блок, в ней никто не стоит.
## При равной пригодности сторон выбор случайный, чтобы скелеты
## не появлялись всегда только с одной стороны постамента.
func _find_spawn_cell() -> Vector2i:
	var own_cell: Vector2i = _get_own_cell()
	var usable: Array[Vector2i] = []

	for offset: Vector2i in NEIGHBOUR_OFFSETS:
		var candidate: Vector2i = own_cell + offset
		if _is_cell_walkable(candidate):
			usable.append(candidate)

	if usable.is_empty():
		return INVALID_CELL

	if usable.size() == 1:
		return usable[0]

	return usable[1] if randf() < 0.5 else usable[0]


## Клетка, занятая самим постаментом.
func _get_own_cell() -> Vector2i:
	var saved_cell: Variant = get_meta("placement_cell", null)
	if saved_cell is Vector2i:
		return saved_cell

	# У постаmntа корень — нижняя граница клетки,
	# поэтому берём середину тела, а не точку опоры.
	return _terrain.global_position_to_cell(
		global_position + Vector2(0.0, -_cell_size().y * 0.25)
	)


## Клетка пуста, под ней блок, и в ней никто не стоит.
func _is_cell_walkable(cell: Vector2i) -> bool:
	if _terrain.has_block_at_cell(cell):
		return false

	# Нужен твёрдый фундамент — иначе скелет упадёт в пропасть.
	if not _terrain.has_block_at_cell(cell + Vector2i(0, 1)):
		return false

	return not _occupied_cells.has(cell)


func _cell_size() -> Vector2:
	var center: Vector2 = (
		_terrain.get_cell_global_center(Vector2i.ZERO)
	)
	var right: Vector2 = (
		_terrain.get_cell_global_center(Vector2i(1, 0))
	)
	return Vector2(absf(right.x - center.x), absf(right.y - center.y))


func _spawn_one(
	scene: PackedScene,
	is_melee: bool,
	spawn_cell: Vector2i
) -> void:
	var skeleton: Skeleton = scene.instantiate() as Skeleton
	if skeleton == null:
		return

	skeleton.melee_unit = is_melee
	skeleton.randomize_type = false
	skeleton.arrow_scene = _load_arrow_scene()

	# Корень скелета — его ноги, поэтому ставим на нижнюю
	# границу клетки: иначе часть тела входит в фундамент.
	skeleton.global_position = _get_cell_floor_position(spawn_cell)

	_world.add_child(skeleton)
	_occupied_cells[spawn_cell] = true
	skeleton_spawned.emit()


## Точка опоры в нижней части клетки.
func _get_cell_floor_position(cell: Vector2i) -> Vector2:
	var center: Vector2 = _terrain.get_cell_global_center(cell)
	var below_center: Vector2 = (
		_terrain.get_cell_global_center(cell + Vector2i(0, 1))
	)

	# Середина между центром клетки и центром клетки под ней
	# совпадает с верхней гранью фундамента.
	return center + (below_center - center) * 0.5


## Загрузка сцены стрелы для лучника.
func _load_arrow_scene() -> PackedScene:
	if ResourceLoader.exists(ARROW_SCENE_PATH):
		return load(ARROW_SCENE_PATH) as PackedScene
	return null


func _find_terrain() -> TerrainLayer:
	var grouped: Node = get_tree().get_first_node_in_group("terrain")
	if grouped is TerrainLayer:
		return grouped as TerrainLayer

	if _world == null:
		return null

	var direct: Node = _world.get_node_or_null("Terrain")
	if direct is TerrainLayer:
		return direct as TerrainLayer

	for node: Node in _world.find_children(
		"*",
		"TileMapLayer",
		true,
		false
	):
		if node is TerrainLayer:
			return node as TerrainLayer

	return null