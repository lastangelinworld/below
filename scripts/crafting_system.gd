class_name CraftingSystem
extends Node


@export var recipes: Array[CraftingRecipe] = []


func find_recipe(grid: Array) -> CraftingRecipe:
	for recipe: CraftingRecipe in recipes:
		if recipe != null and recipe.matches(grid):
			return recipe
	return null


func craft(grid_inventory: InventoryData, output_inventory: InventoryData) -> bool:
	if grid_inventory == null or output_inventory == null:
		return false
	var recipe: CraftingRecipe = find_recipe(grid_inventory.slots)
	if recipe == null or recipe.output_item_id == &"":
		return false
	if not output_inventory.can_add_item(recipe.output_item_id, recipe.output_amount):
		return false
	for index: int in range(9):
		var required: StringName = recipe.pattern[index]
		if required == &"":
			continue
		var stack: ItemStack = grid_inventory.get_slot(index)
		if stack == null or stack.item_id != required or stack.amount < 1:
			return false
	for index: int in range(9):
		if recipe.pattern[index] != &"":
			grid_inventory.remove_from_slot(index, 1)
	output_inventory.add_item(recipe.output_item_id, recipe.output_amount)
	return true
