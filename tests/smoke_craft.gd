extends Node

## Смоук-тест рецептов и сетки верстака (Фаза 3).
## Запуск: godot --headless --path . res://tests/smoke_craft.tscn
## Autoload'ы (ItemRegistry) при запуске сцены инициализируются обычно.


func _ready() -> void:
	var failures: int = 0
	failures += _test_recipes()
	failures += _test_workbench()
	failures += _test_registry()
	print("SMOKE RESULT: ", "FAIL " if failures > 0 else "OK", " (", failures, " проблем)")
	get_tree().quit(1 if failures > 0 else 0)


func _stack(id: String, amount: int = 1) -> ItemStack:
	var stack := ItemStack.new()
	stack.item_id = StringName(id)
	stack.amount = amount
	return stack


func _test_recipes() -> int:
	var problems := 0
	var cases := [
		["res://data/recipes/workbench.tres", 3, "workbench", 1],
		["res://data/recipes/torch.tres", 3, "torch", 2],
		["res://data/recipes/wood_club.tres", 3, "wood_club", 1],
		["res://data/recipes/bone_pickaxe.tres", 3, "bone_pickaxe", 1],
		["res://data/recipes/wood_shield.tres", 3, "wood_shield", 1],
		["res://data/recipes/cloth_chest.tres", 3, "cloth_chest", 1],
		["res://data/recipes/cloth_boots.tres", 3, "cloth_boots", 1],
		["res://data/recipes/cloth_hat.tres", 3, "cloth_hat", 1],
		["res://data/recipes/bone_greatclub.tres", 5, "bone_greatclub", 1],
	]
	for case: Array in cases:
		var recipe: CraftingRecipe = load(case[0])
		if recipe == null:
			print("MISSING recipe: ", case[0])
			problems += 1
			continue
		if recipe.pattern_side() != case[1]:
			print("BAD SIDE ", recipe.recipe_id, ": ", recipe.pattern_side(), " != ", case[1])
			problems += 1
		if recipe.output_item_id != StringName(case[2]):
			print("BAD OUTPUT ", recipe.recipe_id)
			problems += 1
		if recipe.output_amount != case[3]:
			print("BAD AMOUNT ", recipe.recipe_id, ": ", recipe.output_amount)
			problems += 1
		if recipe.required_amounts().is_empty():
			print("EMPTY PATTERN ", recipe.recipe_id)
			problems += 1

	# Щит — ровно 9 обломков.
	var shield: CraftingRecipe = load("res://data/recipes/wood_shield.tres")
	if int(shield.required_amounts().get(&"plank_scraps", 0)) != 9:
		print("SHIELD NEEDS 9 SCRAPS, GOT ", shield.required_amounts())
		problems += 1

	# Кирка — 3 кости + 3 обломка.
	var pick: CraftingRecipe = load("res://data/recipes/bone_pickaxe.tres")
	var pick_req: Dictionary = pick.required_amounts()
	if int(pick_req.get(&"bone", 0)) != 3 or int(pick_req.get(&"plank_scraps", 0)) != 3:
		print("PICKAXE REQ WRONG: ", pick_req)
		problems += 1

	# Двуручная дубина — 20 костей.
	var club: CraftingRecipe = load("res://data/recipes/bone_greatclub.tres")
	if int(club.required_amounts().get(&"bone", 0)) != 20:
		print("GREATCLUB NEEDS 20 BONES, GOT ", club.required_amounts())
		problems += 1
	return problems


func _test_workbench() -> int:
	var problems := 0
	var bench := Workbench.new()
	add_child(bench)
	var recipes: Array = [
		load("res://data/recipes/wood_shield.tres"),
		load("res://data/recipes/bone_pickaxe.tres"),
		load("res://data/recipes/cloth_hat.tres"),
		load("res://data/recipes/cloth_chest.tres"),
		load("res://data/recipes/cloth_boots.tres"),
		load("res://data/recipes/bone_greatclub.tres"),
		load("res://data/recipes/workbench.tres"),
	]

	# 1. Щит: квадрат 3×3 из девяти обломков со сдвигом (1,1).
	for cell: int in [6, 7, 8, 11, 12, 13, 16, 17, 18]:
		bench.put_items(cell, &"plank_scraps", 1)
	var found: Dictionary = bench.find_recipe_with_offset(recipes)
	if found.get("recipe") == null or found["recipe"].recipe_id != &"wood_shield":
		print("SHIELD NOT MATCHED: ", found)
		problems += 1
	else:
		if found["offset"] != Vector2i(1, 1):
			print("SHIELD OFFSET WRONG: ", found["offset"])
			problems += 1
		var made: Dictionary = bench.craft(found["recipe"], found["offset"])
		if made.get("item_id") != &"wood_shield":
			print("SHIELD CRAFT FAILED: ", made)
			problems += 1
		var left := 0
		for i: int in Workbench.GRID_SIZE:
			left += bench.grid_amounts[i]
		if left != 0:
			print("SHIELD LEFTOVER: ", left)
			problems += 1
		if made.get("amount") != 1:
			print("SHIELD AMOUNT WRONG: ", made)
			problems += 1

	# 2. Костяная кирка 3×3 (кости сверху, изогнутая рукоять) со сдвигом (1,1).
	for i: int in Workbench.GRID_SIZE:
		bench.take_items(i, -1)
	bench.put_items(6, &"bone", 1)
	bench.put_items(7, &"bone", 1)
	bench.put_items(8, &"bone", 1)
	bench.put_items(12, &"plank_scraps", 1)
	bench.put_items(17, &"plank_scraps", 1)
	bench.put_items(18, &"plank_scraps", 1)
	found = bench.find_recipe_with_offset(recipes)
	if found.get("recipe") == null or found["recipe"].recipe_id != &"bone_pickaxe":
		print("PICKAXE (OFFSET 3x3) NOT MATCHED: ", found)
		problems += 1
	else:
		var made: Dictionary = bench.craft(found["recipe"], found["offset"])
		if made.get("item_id") != &"bone_pickaxe":
			print("PICKAXE CRAFT FAILED: ", made)
			problems += 1
		var left := 0
		for i: int in Workbench.GRID_SIZE:
			left += bench.grid_amounts[i]
		if left != 0:
			print("PICKAXE LEFTOVER: ", left)
			problems += 1

	# 3. Двуручная дубина: квадрат 4×5 из двадцати костей.
	for i: int in Workbench.GRID_SIZE:
		bench.take_items(i, -1)
	for cell: int in range(20):
		bench.put_items(cell, &"bone", 1)
	found = bench.find_recipe_with_offset(recipes)
	if found.get("recipe") == null or found["recipe"].recipe_id != &"bone_greatclub":
		print("GREATCLUB NOT MATCHED: ", found)
		problems += 1

	# 4. Тканевый нагрудник 3×3: карманный рецепт ищется в сетке 5×5
	# со сдвигом (1,1) — fiber в углах и целиком во 2-м и 3-м рядах.
	for i: int in Workbench.GRID_SIZE:
		bench.take_items(i, -1)
	for cell: int in [5, 7, 10, 11, 12, 15, 16, 17]:
		bench.put_items(cell, &"fiber", 1)
	var recipes3: Array = [load("res://data/recipes/cloth_chest.tres")]
	found = bench.find_recipe_with_offset(recipes3)
	if found.get("recipe") == null or found["recipe"].recipe_id != &"cloth_chest":
		print("CHEST NOT MATCHED: ", found)
		problems += 1
	else:
		var made: Dictionary = bench.craft(found["recipe"], found["offset"])
		if made.get("item_id") != &"cloth_chest":
			print("CHEST CRAFT FAILED: ", made)
			problems += 1
		var left := 0
		for i: int in Workbench.GRID_SIZE:
			left += bench.grid_amounts[i]
		if left != 0:
			print("CHEST LEFTOVER: ", left)
			problems += 1

	# 5. Лишний ресурс в сетке — рецепт не срабатывает и ничего не списывается.
	for i: int in Workbench.GRID_SIZE:
		bench.take_items(i, -1)
	bench.put_items(0, &"fiber", 3)
	bench.put_items(24, &"bone", 1)
	found = bench.find_recipe_with_offset(recipes)
	if not found.is_empty():
		print("HAT MATCHED WITH EXTRA BONE IN GRID: ", found)
		problems += 1
	if bench.grid_amounts[0] != 3 or bench.grid_amounts[24] != 1:
		print("GRID MUTATED ON FAILED MATCH")
		problems += 1

	# 5. Карманный рецепт верстака 3×3 находится в сетке 5×5.
	for i: int in Workbench.GRID_SIZE:
		bench.take_items(i, -1)
	bench.put_items(1, &"flint", 1)
	bench.put_items(12, &"plank_scraps", 3)
	# Рисунок верстака: флинт сверху по центру, 3 обломка в среднем ряду.
	# В сетке 5×5 при сдвиге (1,1) флинт = ячейка 7, обломки = 11..13.
	for i: int in Workbench.GRID_SIZE:
		bench.take_items(i, -1)
	bench.put_items(7, &"flint", 1)
	bench.put_items(11, &"plank_scraps", 1)
	bench.put_items(12, &"plank_scraps", 1)
	bench.put_items(13, &"plank_scraps", 1)
	found = bench.find_recipe_with_offset(recipes)
	if found.get("recipe") == null or found["recipe"].recipe_id != &"workbench":
		print("WORKBENCH 3x3 OFFSET NOT MATCHED: ", found)
		problems += 1

	return problems


func _test_registry() -> int:
	var problems := 0
	for id: String in [
		"workbench", "bone", "torch", "wood_club", "bone_pickaxe",
		"wood_shield", "cloth_hat", "cloth_chest", "cloth_boots",
		"bone_greatclub",
	]:
		var item: ItemData = ItemRegistry.get_item(StringName(id))
		if item == null:
			print("ITEM NOT REGISTERED: ", id)
			problems += 1
		elif item.icon == null:
			print("ITEM WITHOUT ICON: ", id)
			problems += 1

	# Двуручная дубина занимает MAINHAND + OFFHAND.
	var club: EquipmentComponent = (
		ItemRegistry.get_item(&"bone_greatclub") as EquipmentComponent
	)
	if club != null:
		if not club.is_dual_hand:
			print("GREATCLUB NOT DUAL HAND")
			problems += 1
		if not club.extra_slots.has(EquipmentSlot.Type.OFFHAND):
			print("GREATCLUB MISSING OFFHAND EXTRA SLOT")
			problems += 1

	# Факел и щит — во вторичный слот, ткань — по слотам брони.
	for pair: Array in [
		[&"torch", EquipmentSlot.Type.OFFHAND],
	[&"wood_shield", EquipmentSlot.Type.OFFHAND],
	[&"cloth_hat", EquipmentSlot.Type.HEAD],
	[&"cloth_chest", EquipmentSlot.Type.CHEST],
	[&"cloth_boots", EquipmentSlot.Type.BOOTS],
	]:
		var gear: EquipmentComponent = (
			ItemRegistry.get_item(pair[0]) as EquipmentComponent
		)
		if gear == null:
			continue
		if gear.slot != pair[1]:
			print("WRONG SLOT: ", pair[0], " = ", gear.slot)
			problems += 1
	return problems