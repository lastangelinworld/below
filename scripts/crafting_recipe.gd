class_name CraftingRecipe
extends Resource


@export var recipe_id: StringName = &""
## Девять ячеек: слева направо, сверху вниз. Пустая строка — пустая клетка.
@export var pattern: Array[StringName] = [
	&"", &"", &"",
	&"", &"", &"",
	&"", &"", &""
]
@export var output_item_id: StringName = &""
@export_range(1, 999, 1) var output_amount: int = 1


func matches(grid: Array) -> bool:
	if grid.size() != 9 or pattern.size() != 9:
		return false
	for index: int in range(9):
		var actual_item: StringName = &""
		var stack: Variant = grid[index]
		if stack != null and not stack.is_empty():
			actual_item = stack.item_id
		if pattern[index] != actual_item:
			return false
	return true
