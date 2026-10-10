class_name CraftingRecipe
extends Resource


@export var recipe_id: StringName = &""
## Ячейки рисунка: слева направо, сверху вниз, по строкам.
## Длина массива — квадрат стороны сетки: 9 для карманного крафта 3×3
## и 25 для верстака 5×5. Пустая строка — пустая клетка.
@export var pattern: Array[StringName] = [
	&"", &"", &"",
	&"", &"", &"",
	&"", &"", &""
]
@export var output_item_id: StringName = &""
@export_range(1, 999, 1) var output_amount: int = 1

## Бесформенный рецепт: важен набор и количество ресурсов,
## а не их расположение. Подходит для рецептов вроде
## «щит — 10 обломков досок», где раскладка в сетке 5×5 произвольна.
## Посторонние предметы в сетке крафту мешают.
@export var is_shapeless: bool = false


## Требуемое количество каждого ресурса: item_id -> штук.
func required_amounts() -> Dictionary:
	var required: Dictionary = {}
	for ingredient_id: StringName in pattern:
		if ingredient_id == &"":
			continue
		required[ingredient_id] = int(required.get(ingredient_id, 0)) + 1
	return required


## Сторона сетки, для которой описан рисунок (3, 5 …).
## Возвращает 0, если длина массива не является полным квадратом.
static func grid_side(cell_count: int) -> int:
	if cell_count < 4:
		return 0
	var side: int = int(round(sqrt(float(cell_count))))
	if side * side != cell_count:
		return 0
	return side


## Сторона сетки самого рецепта.
func pattern_side() -> int:
	return grid_side(pattern.size())


## Сторона сетки, в которой проверяется рецепт.
static func grid_side_of(grid: Array) -> int:
	return grid_side(grid.size())


## Находит смещение рисунка внутри сетки произвольного размера.
## Рецепт 3×3 помещается в сетку 5×5 с любым сдвигом, поэтому
## карманные рецепты остаются доступны и на верстаке.
## Возвращает Vector2i(-1, -1), если рисунок не ложится без остатка.
func find_offset(grid: Array) -> Vector2i:
	var pattern_cells: int = pattern.size()
	var grid_cells: int = grid.size()
	if pattern_cells <= 0 or grid_cells < pattern_cells:
		return Vector2i(-1, -1)

	var small_side: int = grid_side(pattern_cells)
	var big_side: int = grid_side(grid_cells)
	if small_side <= 0 or big_side <= 0:
		return Vector2i(-1, -1)

	if is_shapeless:
		return Vector2i.ZERO if _matches_shapeless(grid) else Vector2i(-1, -1)

	for offset_y: int in range(big_side - small_side + 1):
		for offset_x: int in range(big_side - small_side + 1):
			if _matches_at(grid, big_side, small_side, offset_x, offset_y):
				return Vector2i(offset_x, offset_y)

	return Vector2i(-1, -1)


## Точное совпадение: рисунок и сетка одинаковой стороны.
func matches(grid: Array) -> bool:
	if grid.size() != pattern.size():
		return false
	return _matches_at(grid, pattern_side(), pattern_side(), 0, 0)


## Совпадение с учётом сдвига: годится и для сетки большего размера.
func fits(grid: Array) -> bool:
	return find_offset(grid) != Vector2i(-1, -1)


## Бесформенная проверка: содержимое сетки совпадает с требуемым
## набором ресурсов независимо от расстановки.
## Учитывается количество единиц: стак из десяти досок подходит
## для требования «десять досок», даже лежа в одной ячейке.
func _matches_shapeless(grid: Array) -> bool:
	var required: Dictionary = required_amounts()
	if required.is_empty():
		return false

	var used: Dictionary = {}
	var total := 0
	for stack: Variant in grid:
		if stack == null or stack.is_empty():
			continue
		var item_id: StringName = stack.item_id
		used[item_id] = int(used.get(item_id, 0)) + int(stack.amount)
		total += int(stack.amount)

	var required_total := 0
	for ingredient_id: StringName in required.keys():
		required_total += int(required[ingredient_id])
		if int(used.get(ingredient_id, 0)) != int(required[ingredient_id]):
			return false

	# Посторонние предметы не допускаются.
	return total == required_total


func _matches_at(
		grid: Array,
		big_side: int,
		small_side: int,
		offset_x: int,
		offset_y: int
) -> bool:
	for y: int in range(big_side):
		for x: int in range(big_side):
			var expected: StringName = &""
			var inner_x: int = x - offset_x
			var inner_y: int = y - offset_y

			if (
				inner_x >= 0
				and inner_x < small_side
				and inner_y >= 0
				and inner_y < small_side
			):
				expected = pattern[inner_y * small_side + inner_x]

			var actual: StringName = &""
			var stack: Variant = grid[y * big_side + x]
			if stack != null and not stack.is_empty():
				actual = stack.item_id

			if expected != actual:
				return false

	return true