class_name Workbench
extends StaticBody2D

## Верстак: девять ячеек крафта и одна ячейка результата.
## Сам верстак хранит только содержимое ячеек. Подбором рецепта
## занимается GameplayInteractions, чтобы верстак мог использовать
## и обычные рецепты интерфейса, и свои собственные.

## Верстак первого уровня — сетка 5×5: в неё помещаются рецепты
## из десяти и двадцати одинаковых ресурсов.
const GRID_SIDE := 5
const GRID_SIZE := GRID_SIDE * GRID_SIDE

## Рецепты, доступные только на верстаке.
## Обычные рецепты берутся из InventoryUI.Crafting Recipes.
@export var recipes: Array[CraftingRecipe] = []

var grid_ids: Array[StringName] = []
var grid_amounts: Array[int] = []


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	add_to_group("placeable_structure")
	add_to_group("workbench")
	add_to_group("workbench_interactable")
	_ensure_grid()


func _ensure_grid() -> void:
	while grid_ids.size() < GRID_SIZE:
		grid_ids.append(&"")
		grid_amounts.append(0)
	if grid_ids.size() > GRID_SIZE:
		grid_ids.resize(GRID_SIZE)
		grid_amounts.resize(GRID_SIZE)


## Снимок ячеек в формате, который ожидает CraftingRecipe.matches():
## массив из девяти ItemStack.
func build_grid_snapshot() -> Array:
	_ensure_grid()
	var snapshot: Array = []
	for i: int in range(GRID_SIZE):
		var stack := ItemStack.new()
		stack.item_id = grid_ids[i]
		stack.amount = grid_amounts[i]
		snapshot.append(stack)
	return snapshot


func is_cell_empty(index: int) -> bool:
	_ensure_grid()
	return index < 0 or index >= GRID_SIZE or grid_amounts[index] <= 0


## Кладёт предметы в выбранную ячейку. Возвращает число перемещённых единиц.
func put_items(index: int, item_id: StringName, amount: int) -> int:
	_ensure_grid()
	if item_id == &"" or amount <= 0 or index < 0 or index >= GRID_SIZE:
		return 0

	var item: ItemData = ItemRegistry.get_item(item_id)
	if item == null:
		return 0

	if grid_amounts[index] <= 0:
		var moved: int = mini(amount, item.max_stack)
		grid_ids[index] = item_id
		grid_amounts[index] = moved
		return moved

	if grid_ids[index] != item_id:
		return 0

	var free: int = maxi(0, item.max_stack - grid_amounts[index])
	var added: int = mini(amount, free)
	grid_amounts[index] += added
	return added


## Меняет содержимое ячейки на предмет с указателя (для ЛКМ).
func swap_cell(
		index: int,
		item_id: StringName,
		amount: int
) -> Dictionary:
	_ensure_grid()
	if index < 0 or index >= GRID_SIZE:
		return {}

	var displaced := {
		"item_id": grid_ids[index],
		"amount": grid_amounts[index],
	}
	grid_ids[index] = item_id if amount > 0 else &""
	grid_amounts[index] = maxi(0, amount)
	return displaced


func take_items(index: int, amount: int = -1) -> Dictionary:
	_ensure_grid()
	if index < 0 or index >= GRID_SIZE or grid_amounts[index] <= 0:
		return {}

	var count: int = (
		grid_amounts[index] if amount < 0
		else mini(amount, grid_amounts[index])
	)
	var result := {
		"item_id": grid_ids[index],
		"amount": count,
	}
	grid_amounts[index] -= count
	if grid_amounts[index] <= 0:
		grid_ids[index] = &""
		grid_amounts[index] = 0
	return result


## Первый свободный слот — для быстрого переноса по Shift.
func find_free_cell_for(item_id: StringName) -> int:
	_ensure_grid()
	var item: ItemData = ItemRegistry.get_item(item_id)
	if item == null:
		return -1

	for i: int in range(GRID_SIZE):
		if grid_amounts[i] <= 0:
			return i
		if grid_ids[i] == item_id and grid_amounts[i] < item.max_stack:
			return i
	return -1


## Ищет рецепт по содержимому ячеек среди переданных рецептов.
## Пустой рисунок не допускается: иначе предмет создавался бы без затрат.
## Рецепт 3×3 находится и в сетке 5×5 — с любым сдвигом,
## поэтому карманные рецепты работают и на верстаке.
func find_recipe(active_recipes: Array) -> CraftingRecipe:
	return find_recipe_with_offset(active_recipes).get("recipe")


## Возвращает найденный рецепт и смещение его рисунка в сетке верстака:
## {"recipe": CraftingRecipe, "offset": Vector2i}.
## Если рецепт не найден, возвращается пустой словарь.
func find_recipe_with_offset(active_recipes: Array) -> Dictionary:
	var snapshot: Array = build_grid_snapshot()
	var filled := false
	for stack: Variant in snapshot:
		if stack != null and not stack.is_empty():
			filled = true
			break
	if not filled:
		return {}

	for recipe: CraftingRecipe in active_recipes:
		if recipe == null or recipe.output_item_id == &"":
			continue
		if recipe.output_amount <= 0:
			continue
		if recipe.pattern_side() <= 0 or recipe.pattern_side() > GRID_SIDE:
			continue

		var offset: Vector2i = recipe.find_offset(snapshot)
		if offset == Vector2i(-1, -1):
			continue

		return {"recipe": recipe, "offset": offset}

	return {}


## Содержимое ячейки результата для отображения.
func get_preview_output(recipe: CraftingRecipe) -> Dictionary:
	if recipe == null:
		return {}
	return {
		"item_id": recipe.output_item_id,
		"amount": recipe.output_amount,
	}


## Расходует по одной единице из каждой занятой ячейки рисунка
## и возвращает созданный предмет.
## offset — смещение рисунка в сетке верстака; если он не передан,
##recipe ищется заново по текущему содержимому ячеек.
func craft(
		recipe: CraftingRecipe,
		offset: Vector2i = Vector2i(-1, -1)
) -> Dictionary:
	if recipe == null or recipe.pattern_side() <= 0:
		return {}
	if recipe.pattern_side() > GRID_SIDE:
		return {}

	_ensure_grid()

	if offset == Vector2i(-1, -1):
		var found: Dictionary = find_recipe_with_offset([recipe])
		if found.is_empty():
			return {}
		offset = found["offset"]

	var side: int = recipe.pattern_side()
	if recipe.is_shapeless:
		return _craft_shapeless(recipe)

	var cells: Array = _pattern_cells(recipe, offset, side)
	if cells.is_empty():
		return {}

	# Проверка выполняется до списания: при нехватке чего-либо
	# содержимое ячеек остаётся нетронутым.
	for entry: Variant in cells:
		var cell: int = int(entry["cell"])
		var required: StringName = entry["item"]
		if grid_ids[cell] != required or grid_amounts[cell] < 1:
			return {}

	for entry: Variant in cells:
		var cell: int = int(entry["cell"])
		grid_amounts[cell] -= 1
		if grid_amounts[cell] <= 0:
			grid_ids[cell] = &""
			grid_amounts[cell] = 0

	return {
		"item_id": recipe.output_item_id,
		"amount": recipe.output_amount,
	}


## Списывает требуемое количество каждого ресурса из ячеек сетки —
## для рецептов без рисунка. Проверка выполняется до списания.
func _craft_shapeless(recipe: CraftingRecipe) -> Dictionary:
	var required: Dictionary = recipe.required_amounts()
	if required.is_empty():
		return {}

	# Сначала убеждаемся, что ресурсов хватает целиком.
	var available: Dictionary = {}
	for i: int in range(GRID_SIZE):
		if grid_ids[i] == &"" or grid_amounts[i] <= 0:
			continue
		available[grid_ids[i]] = int(available.get(grid_ids[i], 0)) + grid_amounts[i]

	for ingredient_id: StringName in required.keys():
		if int(available.get(ingredient_id, 0)) < int(required[ingredient_id]):
			return {}

	for ingredient_id: StringName in required.keys():
		var remaining: int = int(required[ingredient_id])
		for i: int in range(GRID_SIZE):
			if remaining <= 0:
				break
			if grid_ids[i] != ingredient_id or grid_amounts[i] <= 0:
				continue
			var taken: int = mini(remaining, grid_amounts[i])
			grid_amounts[i] -= taken
			remaining -= taken
			if grid_amounts[i] <= 0:
				grid_ids[i] = &""
				grid_amounts[i] = 0

	return {
		"item_id": recipe.output_item_id,
		"amount": recipe.output_amount,
	}


## Пары «ячейка сетки — требуемый предмет» для рисунка рецепта
## при заданном сдвиге. Пустые клетки рецепта в список не входят.
## Возвращает пустой массив, если рисунок выходит за пределы сетки
## или не требует ни одного ресурса.
func _pattern_cells(
		recipe: CraftingRecipe,
		offset: Vector2i,
		side: int
) -> Array:
	var cells: Array = []
	for pattern_index: int in range(recipe.pattern.size()):
		var required: StringName = recipe.pattern[pattern_index]
		if required == &"":
			continue

		var local_x: int = pattern_index % side
		var local_y: int = pattern_index / side
		var x: int = local_x + offset.x
		var y: int = local_y + offset.y

		if x < 0 or x >= GRID_SIDE or y < 0 or y >= GRID_SIDE:
			return []

		cells.append({"cell": y * GRID_SIDE + x, "item": required})

	return cells


## Возвращает все предметы из ячеек. Используется при разборке верстака,
## чтобы содержимое не пропало. Возвращает false, если дроп создать не удалось.
func drop_contents() -> bool:
	_ensure_grid()
	var totals: Dictionary = {}
	for i: int in range(GRID_SIZE):
		if grid_ids[i] != &"" and grid_amounts[i] > 0:
			totals[grid_ids[i]] = int(totals.get(grid_ids[i], 0)) + grid_amounts[i]
	if totals.is_empty():
		return true

	var pickup_scene: PackedScene = _find_pickup_scene()
	if pickup_scene == null:
		push_error("Верстак: не найдена сцена выпавшего предмета.")
		return false

	var parent: Node = get_parent()
	if parent == null:
		push_error("Верстак: нет родительского узла для выпадения предметов.")
		return false

	var prepared: Array[Node2D] = []
	for key: Variant in totals.keys():
		var item: ItemData = ItemRegistry.get_item(StringName(str(key)))
		if item == null:
			for node: Node2D in prepared:
				node.free()
			push_error("Верстак: предмет не зарегистрирован: " + str(key))
			return false
		var remaining: int = int(totals[key])
		while remaining > 0:
			var count: int = mini(remaining, maxi(1, item.max_stack))
			var instance: Node = pickup_scene.instantiate()
			if not instance is Node2D or not instance.has_method("setup"):
				instance.free()
				for node: Node2D in prepared:
					node.free()
				push_error("Верстак: сцена дропа должна быть Node2D с setup().")
				return false
			instance.call("setup", StringName(str(key)), count)
			prepared.append(instance as Node2D)
			remaining -= count

	for i: int in range(GRID_SIZE):
		grid_ids[i] = &""
		grid_amounts[i] = 0

	for i: int in range(prepared.size()):
		var pickup: Node2D = prepared[i]
		parent.add_child(pickup)
		pickup.global_position = global_position + Vector2(
			float(i % 5 - 2) * 4.0,
			-12.0 - float(i / 5) * 3.0
		)
	return true


func _find_pickup_scene() -> PackedScene:
	var terrain: Node = get_tree().get_first_node_in_group("terrain")
	if terrain != null:
		var from_terrain: Variant = terrain.get("item_pickup_scene")
		if from_terrain is PackedScene:
			return from_terrain as PackedScene

	for path: String in [
		"res://data/items/item_pickup.tscn",
		"res://items/item_pickup.tscn",
	]:
		if ResourceLoader.exists(path):
			var loaded: PackedScene = load(path) as PackedScene
			if loaded != null:
				return loaded
	return null
