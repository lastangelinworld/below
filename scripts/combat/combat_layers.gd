class_name CombatLayers
extends Object

## Физические слои hitbox/hurtbox-боевки (матрица всего проекта).
## Слои 1, 2, 4, 8 заняты миром и телами; боевые области получают
## два свободных бита, чтобы удар решался касанием форм, а не
## расстоянием или наведением.
##
##   1  — тайлмап мира (terrain);
##   2  — тело персонажа;
##   4  — снаряды (стрелы);
##   8  — тела скелетов;
##   16 — активная область удара (Hitbox);
##   32 — получающая область (Hurtbox).

const TERRAIN: int = 1
const PLAYER: int = 2
const ARROW: int = 4
const SKELETON: int = 8
const HITBOX: int = 16
const HURTBOX: int = 32


## Ищет тайлмап-слой мира по имени «Terrain» на текущей сцене.
## Если не найден — возвращает null, чтобы вызывающий мог
## безопасно обработать отсутствие мира (например, в тестах).
static func find_terrain() -> TerrainLayer:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var scene: Node = tree.get_current_scene()
	if scene == null:
		return null
	var direct: Node = scene.get_node_or_null("Terrain")
	if direct is TerrainLayer:
		return direct as TerrainLayer
	for node: Node in scene.find_children("*", "TileMapLayer", true, false):
		if node is TerrainLayer:
			return node as TerrainLayer
	return null
