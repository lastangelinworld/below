class_name InventoryUI
extends CanvasLayer

@export var player_path: NodePath = NodePath("../Player")
@export var slot_scene: PackedScene
@export var pickup_scene: PackedScene = preload("res://data/items/item_pickup.tscn")

@export_group("Crafting")
## Назначьте сюда ресурсы рецептов campfire.tres и chest.tres.
## Первый совпавший рецепт определяет результат.
@export var crafting_recipes: Array[CraftingRecipe] = []
## Дополнительные предметы для регистрации. Назначьте chest_item.tres,
## если предмет сундука ещё не добавлен в ItemRegistry.
@export var crafting_items: Array[ItemData] = []

@onready var overlay: Control = $Overlay
@onready var inventory_window: Control = $Overlay/Center/InventoryWindow
@onready var main_grid: GridContainer = $Overlay/Center/InventoryWindow/Margin/Main/Content/PlayerColumn/MainInventoryGrid
@onready var inventory_hotbar_grid: GridContainer = $Overlay/Center/InventoryWindow/Margin/Main/Content/PlayerColumn/InventoryHotbarGrid
@onready var equipment_grid: GridContainer = $Overlay/Center/InventoryWindow/Margin/Main/Content/EquipmentColumn/EquipmentGrid
@onready var craft_grid: GridContainer = $Overlay/Center/InventoryWindow/Margin/Main/Content/CraftColumn/CraftRow/CraftGrid
@onready var result_holder: Control = $Overlay/Center/InventoryWindow/Margin/Main/Content/CraftColumn/CraftRow/ResultHolder
@onready var weight_bar: ProgressBar = $Overlay/Center/InventoryWindow/Margin/Main/WeightBar
@onready var weight_label: Label = $Overlay/Center/InventoryWindow/Margin/Main/WeightLabel
@onready var hotbar_grid: GridContainer = $HotbarHUD/Margin/VBox/HotbarGrid
@onready var selected_label: Label = $HotbarHUD/Margin/VBox/SelectedLabel
@onready var carry_preview: Control = $CarryPreview
@onready var carry_icon: TextureRect = $CarryPreview/Panel/Icon
@onready var carry_amount: Label = $CarryPreview/Panel/Amount

var external_handler: Node

var player: Node
var inventory: InventoryData
## Система экипировки игрока (Фаза 2). Может быть ещё не создана
## в момент подключения UI — ищем лениво через _get_equipment().
var equipment: EquipmentSystem
var carried := ItemStack.new()
var craft_slots: Array[ItemStack] = []
var inventory_views: Array[InventorySlotUI] = []
var hotbar_views: Array[InventorySlotUI] = []
var inventory_hotbar_views: Array[InventorySlotUI] = []
var craft_views: Array[InventorySlotUI] = []
var result_view: InventorySlotUI
## Ячейки интерфейса экипировки и их соответствие типам слотов.
var equipment_views: Array[InventorySlotUI] = []
var equipment_slot_types: Array[EquipmentSlot.Type] = []
var selected_hotbar := 0
var hovered_inventory_slot := -1
var hovered_craft_slot := -1
var hovered_equipment_slot := -1
var _previous_pause := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("inventory_ui")
	overlay.visible = false
	carry_preview.visible = false
	for i in range(9):
		craft_slots.append(ItemStack.new())
	call_deferred("_connect_player")
	# below_unified_hud_v1
	call_deferred("_below_install_unified_hud")

func _process(_delta: float) -> void:
	if carry_preview.visible:
		carry_preview.position = get_viewport().get_mouse_position() + Vector2(18, 18)

func _input(event: InputEvent) -> void:
	if get_tree().paused and not overlay.visible:
		return
	
	if _is_player_dead():
		return
	
	if event.is_action_pressed("toggle_inventory"):
		if overlay.visible:
			close_inventory()
		else:
			open_inventory()
		get_viewport().set_input_as_handled()
		return
	if overlay.visible and event.is_action_pressed("ui_cancel"):
		close_inventory()
		get_viewport().set_input_as_handled()
		return
	if overlay.visible and event.is_action_pressed("drop_item"):
		_drop_requested()
		get_viewport().set_input_as_handled()
		return
	if not overlay.visible and event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode >= KEY_1 and key.keycode <= KEY_9:
			set_selected_hotbar(key.keycode - KEY_1)

func _is_player_dead() -> bool:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	return bool(player.get("is_dead"))

func is_inventory_open() -> bool:
	return overlay.visible

func open_inventory() -> void:
	if inventory == null:
		_connect_player()
	if inventory == null:
		return
	_previous_pause = get_tree().paused
	overlay.visible = true
	pass
	_refresh_all()

func close_inventory() -> void:
	# Если открыт костёр или сундук, сначала нужно
	# восстановить обычную колонку крафта.
	if is_instance_valid(external_handler):
		external_handler.call("close_window")
		return

	_return_loose_items()
	overlay.visible = false
	pass

func set_selected_hotbar(index: int) -> void:
	selected_hotbar = clampi(index, 0, 8)
	if player != null:
		player.set_meta("selected_hotbar_index", selected_hotbar)
	_refresh_all()

func _connect_player() -> void:
	player = get_node_or_null(player_path)
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if player == null:
		push_error("InventoryUI: Player не найден")
		return
	inventory = player.get("inventory") as InventoryData
	if inventory == null:
		push_error("InventoryUI: у Player нет InventoryData")
		return
	if not inventory.changed.is_connected(_refresh_all):
		inventory.changed.connect(_refresh_all)
	# Система экипировки создаётся в player._ready(); если она ещё
	# не готова — _get_equipment() подтянет её при первом обновлении.
	_get_equipment()
	# Подключение отложено до завершения _ready() остальных узлов,
	# чтобы стартовая регистрация ItemRegistry не зависела от порядка сцены.
	ItemRegistry.register_items(crafting_items)
	_validate_crafting_setup()
	player.set_meta("selected_hotbar_index", selected_hotbar)
	_build_views()
	_refresh_all()

func _new_view(index: int) -> InventorySlotUI:
	var view := slot_scene.instantiate() as InventorySlotUI
	view.setup(index)
	return view

func _clear(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()

func _build_views() -> void:
	if slot_scene == null:
		push_error("InventoryUI: Slot Scene не назначена")
		return
	_clear(main_grid); _clear(inventory_hotbar_grid); _clear(hotbar_grid); _clear(craft_grid); _clear(result_holder); _clear(equipment_grid)
	inventory_views.clear(); inventory_hotbar_views.clear(); hotbar_views.clear(); craft_views.clear()
	equipment_views.clear(); equipment_slot_types.clear()
	for i in range(27):
		var v := _new_view(i)
		main_grid.add_child(v)
		v.slot_pressed.connect(_on_inventory_slot_pressed)
		v.slot_hovered.connect(_on_inventory_hover)
		inventory_views.append(v)
	for i in range(9):
		var slot_index := 27 + i
		var inside := _new_view(slot_index)
		inventory_hotbar_grid.add_child(inside)
		inside.slot_pressed.connect(_on_inventory_slot_pressed)
		inside.slot_hovered.connect(_on_inventory_hover)
		inventory_hotbar_views.append(inside)
		var hud := _new_view(slot_index)
		hotbar_grid.add_child(hud)
		hud.slot_pressed.connect(func(_idx: int, _button: MouseButton): set_selected_hotbar(i))
		hotbar_views.append(hud)
	for i in range(9):
		var v := _new_view(i)
		craft_grid.add_child(v)
		v.slot_pressed.connect(_on_craft_slot_pressed)
		v.slot_hovered.connect(_on_craft_hover)
		craft_views.append(v)
	result_view = _new_view(0)
	result_holder.add_child(result_view)
	result_view.slot_pressed.connect(_on_result_pressed)
	_build_equipment_views()

## Строит ячейки экипировки в порядке EquipmentSlot.ALL_SLOTS.
## Индекс ячейки = индекс типа слота в equipment_slot_types,
## поэтому сигнал slot_pressed отдаёт привычный номер строки/колонки.
func _build_equipment_views() -> void:
	for i in range(EquipmentSlot.ALL_SLOTS.size()):
		var slot_type: EquipmentSlot.Type = EquipmentSlot.ALL_SLOTS[i]
		var view := _new_view(i)
		view.slot_hint = EquipmentSlot.get_display_name(slot_type)
		equipment_grid.add_child(view)
		view.clear_display()
		view.slot_pressed.connect(_on_equipment_slot_pressed)
		view.slot_hovered.connect(_on_equipment_hover)
		equipment_views.append(view)
		equipment_slot_types.append(slot_type)


## Лениво находит систему экипировки игрока и подписывается на её
## изменения. Возвращает null, если игрок ещё не инициализирован.
func _get_equipment() -> EquipmentSystem:
	if is_instance_valid(equipment):
		return equipment
	if player == null:
		return null
	equipment = player.get("equipment") as EquipmentSystem
	if equipment != null and not equipment.equipment_changed.is_connected(_on_equipment_changed):
		equipment.equipment_changed.connect(_on_equipment_changed)
	return equipment


func _on_equipment_changed(_slot: EquipmentSlot.Type) -> void:
	_refresh_equipment()


## Обновляет содержимое ячеек экипировки.
func _refresh_equipment() -> void:
	if equipment_views.is_empty():
		return
	var system := _get_equipment()
	for i in range(equipment_views.size()):
		if system == null:
			equipment_views[i].clear_display()
			continue
		equipment_views[i].display_stack(
			system.get_display_stack(equipment_slot_types[i])
		)

func _refresh_all() -> void:
	if inventory == null or inventory_views.is_empty():
		return
	for i in range(27):
		inventory_views[i].display_stack(inventory.get_slot(i))
	for i in range(9):
		inventory_hotbar_views[i].display_stack(inventory.get_slot(27 + i))
		hotbar_views[i].display_stack(inventory.get_slot(27 + i))
		inventory_hotbar_views[i].set_selected(i == selected_hotbar)
		hotbar_views[i].set_selected(i == selected_hotbar)
	var current := inventory.get_total_weight_kg()
	weight_bar.max_value = inventory.max_weight_kg
	weight_bar.value = current
	weight_label.text = "Вес: %.2f / %.2f кг" % [current, inventory.max_weight_kg]
	weight_label.modulate = Color("ff5b5b") if current >= inventory.max_weight_kg else (Color("ffc24d") if current >= inventory.max_weight_kg * 0.8 else Color.WHITE)
	var selected := inventory.get_slot(27 + selected_hotbar)
	if selected == null or selected.is_empty():
		selected_label.text = "%d — пусто" % (selected_hotbar + 1)
	else:
		var item: ItemData = ItemRegistry.get_item(selected.item_id)
		selected_label.text = "%d — %s × %d" % [selected_hotbar + 1, item.display_name if item else str(selected.item_id), selected.amount]
	_refresh_equipment()
	_refresh_craft()
	_refresh_carried()

func _on_inventory_hover(index: int, entered: bool) -> void:
	hovered_inventory_slot = index if entered else (-1 if hovered_inventory_slot == index else hovered_inventory_slot)

func _on_equipment_hover(index: int, entered: bool) -> void:
	hovered_equipment_slot = index if entered else (-1 if hovered_equipment_slot == index else hovered_equipment_slot)


## Клик по ячейке экипировки: ЛКМ — надеть/снять весь предмет,
## ПКМ — снять половину (для стаков). Надеть можно только 1 единицу,
## вытесненная вещь возвращается на курсор.
## Ячейка дополнительного слота (вторая рука двуручного оружия)
## снимает предмет целиком вместе с основным слотом.
func _on_equipment_slot_pressed(index: int, button: MouseButton) -> void:
	if index < 0 or index >= equipment_slot_types.size():
		return
	var system := _get_equipment()
	if system == null:
		return
	var slot_type: EquipmentSlot.Type = equipment_slot_types[index]

	if carried.is_empty():
		var stack: ItemStack = system.get_display_stack(slot_type)
		if stack.is_empty():
			return
		# Из занятой дополнительной руки берут только весь предмет.
		var amount := stack.amount
		if button == MOUSE_BUTTON_RIGHT and not system.is_secondary_cell(slot_type):
			amount = ceili(stack.amount / 2.0)
		carried = system.take_from_slot(slot_type, amount)
		_refresh_all()
		return

	# На курсоре предмет: пробуем надеть (всегда 1 единица —
	# оружие и броня занимают слот целиком).
	if not system.can_accept_item(slot_type, carried.item_id):
		_refresh_all()
		return
	var putting := ItemStack.new()
	putting.item_id = carried.item_id
	putting.amount = 1
	var displaced: ItemStack = system.swap_single(slot_type, putting)
	carried.amount -= 1
	_clear_if_empty(carried)
	if not displaced.is_empty():
		if carried.is_empty():
			carried = displaced
		else:
			# На курсоре уже есть предмет — вытесненную вещь
			# кладём в инвентарь, иначе она упадёт на землю.
			_store_or_drop(displaced)

	# Двуручное оружие освободило руку: щит или факел возвращаем игроку.
	for ejected: Variant in system.drain_ejections():
		var ejected_stack := ejected as ItemStack
		if ejected_stack != null and not ejected_stack.is_empty():
			_store_or_drop(ejected_stack)

	_refresh_all()


## Кладёт предмет в инвентарь; если места нет — роняет под ноги.
func _store_or_drop(stack: ItemStack) -> void:
	var accepted: int = inventory.add_item(stack.item_id, stack.amount)
	if accepted < stack.amount:
		_spawn_dropped(stack.item_id, stack.amount - accepted)

func _on_craft_hover(index: int, entered: bool) -> void:
	hovered_craft_slot = index if entered else (-1 if hovered_craft_slot == index else hovered_craft_slot)

func _on_inventory_slot_pressed(
		index: int,
		button: MouseButton
) -> void:
	if is_instance_valid(external_handler):
		if button == MOUSE_BUTTON_LEFT:
			if Input.is_key_pressed(KEY_SHIFT):
				external_handler.call(
					"quick_transfer_player",
					index
				)
				return

	# Shift+ЛКМ по обычному инвентарю — быстрое надевание экипировки.
	if button == MOUSE_BUTTON_LEFT and Input.is_key_pressed(KEY_SHIFT):
		if _quick_equip_from_inventory(index):
			return

	_handle_stack_click(
		inventory.get_slot(index),
		button,
		func(): inventory.notify_changed(),
		func(amount: int):
			carried = inventory.take_from_slot(index, amount)
	)

## Shift+ЛКМ по ячейке инвентаря: надевает предмет в первый
## подходящий слот экипировки. Пустые слоты предпочитаются занятым,
## чтобы случайно не вытеснить надетую вещь. Возвращает false,
## если предмет не является экипировкой — тогда работает обычный перенос.
func _quick_equip_from_inventory(index: int) -> bool:
	var system := _get_equipment()
	if system == null or inventory == null:
		return false
	var stack: ItemStack = inventory.get_slot(index)
	if stack == null or stack.is_empty():
		return false

	var fallback_slot := EquipmentSlot.Type.NONE
	for slot_type: EquipmentSlot.Type in EquipmentSlot.ALL_SLOTS:
		if not system.can_accept_item(slot_type, stack.item_id):
			continue
		if system.is_slot_empty(slot_type):
			if system.equip_from_inventory(inventory, index, slot_type):
				_return_ejected(system)
				_refresh_all()
				return true
			return false
		if fallback_slot == EquipmentSlot.Type.NONE:
			fallback_slot = slot_type

	if fallback_slot == EquipmentSlot.Type.NONE:
		return false
	if not system.equip_from_inventory(inventory, index, fallback_slot):
		return false
	_return_ejected(system)
	_refresh_all()
	return true


## Возвращает предметы, вытесненные из дополнительных слотов
## (двуручное оружие заняло руку со щитом или факелом).
func _return_ejected(system: EquipmentSystem) -> void:
	for ejected: Variant in system.drain_ejections():
		var ejected_stack := ejected as ItemStack
		if ejected_stack != null and not ejected_stack.is_empty():
			_store_or_drop(ejected_stack)

func _on_craft_slot_pressed(index: int, button: MouseButton) -> void:
	var target := craft_slots[index]
	_handle_stack_click(target, button, _refresh_all, func(amount: int): carried = _take_from_local(target, amount))

func _handle_stack_click(target: ItemStack, button: MouseButton, changed: Callable, take_callable: Callable) -> void:
	if carried.is_empty():
		if target == null or target.is_empty():
			return
		var amount := target.amount if button == MOUSE_BUTTON_LEFT else ceili(target.amount / 2.0)
		take_callable.call(amount)
		changed.call()
		_refresh_all()
		return
	if target == null:
		return
	if target.is_empty():
		var put := carried.amount if button == MOUSE_BUTTON_LEFT else 1
		target.item_id = carried.item_id
		target.amount = put
		carried.amount -= put
		_clear_if_empty(carried)
	elif target.item_id == carried.item_id:
		var item: ItemData = ItemRegistry.get_item(carried.item_id)
		var room := maxi((item.max_stack if item else 64) - target.amount, 0)
		var put := mini(room, carried.amount if button == MOUSE_BUTTON_LEFT else 1)
		target.amount += put
		carried.amount -= put
		_clear_if_empty(carried)
	elif button == MOUSE_BUTTON_LEFT:
		var old_id := target.item_id
		var old_amount := target.amount
		target.item_id = carried.item_id
		target.amount = carried.amount
		carried.item_id = old_id
		carried.amount = old_amount
	changed.call()
	_refresh_all()

func _take_from_local(stack: ItemStack, amount: int) -> ItemStack:
	var result := ItemStack.new()
	result.item_id = stack.item_id
	result.amount = mini(amount, stack.amount)
	stack.amount -= result.amount
	_clear_if_empty(stack)
	return result

func _clear_if_empty(stack: ItemStack) -> void:
	if stack.amount <= 0:
		stack.item_id = &""
		stack.amount = 0

func _validate_crafting_setup() -> void:
	if crafting_recipes.is_empty():
		push_warning(
			"InventoryUI: Crafting Recipes пуст. Назначьте рецепты костра и сундука в Inspector."
		)
		return

	for recipe: CraftingRecipe in crafting_recipes:
		if recipe == null:
			push_warning("InventoryUI: пустой элемент в Crafting Recipes.")
			continue
		if not _is_valid_crafting_recipe(recipe):
			push_warning(
				"InventoryUI: некорректный рецепт: %s" % str(recipe.recipe_id)
			)
			continue
		var item: ItemData = ItemRegistry.get_item(recipe.output_item_id)
		if item == null:
			push_warning(
				"InventoryUI: не зарегистрирован результат крафта: %s. Добавьте его ItemData в ItemRegistry или Crafting Items."
				% str(recipe.output_item_id)
			)
		elif recipe.output_amount > item.max_stack:
			push_warning(
				"InventoryUI: результат рецепта %s превышает максимальный размер стака."
				% str(recipe.recipe_id)
			)


func _is_valid_crafting_recipe(recipe: CraftingRecipe) -> bool:
	if recipe == null or recipe.pattern_side() != 3:
		return false
	if recipe.output_item_id == &"" or recipe.output_amount <= 0:
		return false

	# Пустой рецепт не должен позволять создавать предметы без ингредиентов.
	for ingredient_id: StringName in recipe.pattern:
		if ingredient_id != &"":
			return true
	return false


func _get_matching_recipe() -> CraftingRecipe:
	for recipe: CraftingRecipe in crafting_recipes:
		if not _is_valid_crafting_recipe(recipe):
			continue
		if not recipe.fits(craft_slots):
			continue

		var item: ItemData = ItemRegistry.get_item(recipe.output_item_id)
		if item == null or recipe.output_amount > item.max_stack:
			continue
		return recipe
	return null


# Сохранены вспомогательные методы прежней версии интерфейса.
func _get_craft_result_id() -> StringName:
	var recipe: CraftingRecipe = _get_matching_recipe()
	return recipe.output_item_id if recipe != null else &""


func _recipe_matches() -> bool:
	return _get_matching_recipe() != null


func _refresh_craft() -> void:
	for i in range(craft_views.size()):
		craft_views[i].display_stack(craft_slots[i])

	var output := ItemStack.new()
	var recipe: CraftingRecipe = _get_matching_recipe()
	if recipe != null:
		output.item_id = recipe.output_item_id
		output.amount = recipe.output_amount

	if result_view != null:
		result_view.display_stack(output)


func _on_result_pressed(_index: int, button: MouseButton) -> void:
	if button != MOUSE_BUTTON_LEFT:
		return

	# Проверяем рецепт заново непосредственно при нажатии,
	# а не используем ранее показанный результат.
	var recipe: CraftingRecipe = _get_matching_recipe()
	if recipe == null:
		return

	var result_id: StringName = recipe.output_item_id
	var result_amount: int = recipe.output_amount
	var item: ItemData = ItemRegistry.get_item(result_id)
	if item == null:
		return

	var carried_amount: int = 0
	if not carried.is_empty():
		if carried.item_id != result_id:
			return
		carried_amount = carried.amount

	# Результат выдаётся целиком. Если на указателе нет места,
	# ингредиенты остаются нетронутыми.
	if carried_amount + result_amount > item.max_stack:
		return

	# Все проверки закончены: расходуем ресурсы.
	if recipe.is_shapeless:
		var required: Dictionary = recipe.required_amounts()
		for ingredient_id: StringName in required.keys():
			var remaining: int = int(required[ingredient_id])
			for stack: ItemStack in craft_slots:
				if remaining <= 0:
					break
				if stack.is_empty() or stack.item_id != ingredient_id:
					continue
				var taken: int = mini(remaining, stack.amount)
				stack.amount -= taken
				remaining -= taken
				_clear_if_empty(stack)
	else:
		# По одной единице из каждой непустой ячейки рисунка рецепта.
		for i in range(recipe.pattern.size()):
			if recipe.pattern[i] == &"":
				continue
			var stack: ItemStack = craft_slots[i]
			stack.amount -= 1
			_clear_if_empty(stack)

	carried.item_id = result_id
	carried.amount = carried_amount + result_amount
	_refresh_all()


func _refresh_carried() -> void:
	if carried.is_empty():
		carry_preview.visible = false
		carry_icon.texture = null
		carry_amount.text = ""
		return
	carry_preview.visible = true
	var item: ItemData = ItemRegistry.get_item(carried.item_id)
	carry_icon.texture = item.icon if item else null
	carry_amount.text = str(carried.amount)

func _drop_requested() -> void:
	if not carried.is_empty():
		_spawn_dropped(carried.item_id, carried.amount)
		carried = ItemStack.new()
	elif hovered_inventory_slot >= 0:
		var stack := inventory.take_from_slot(hovered_inventory_slot)
		if stack != null and not stack.is_empty():
			_spawn_dropped(stack.item_id, stack.amount)
	elif hovered_craft_slot >= 0:
		var stack := _take_from_local(craft_slots[hovered_craft_slot], craft_slots[hovered_craft_slot].amount)
		if not stack.is_empty():
			_spawn_dropped(stack.item_id, stack.amount)
	_refresh_all()

func _spawn_dropped(item_id: StringName, amount: int) -> void:
	if amount <= 0 or player == null or pickup_scene == null:
		return
	var pickup := pickup_scene.instantiate()
	get_tree().current_scene.add_child(pickup)
	pickup.global_position = player.global_position + Vector2(randf_range(-22.0, 22.0), -12.0)
	if pickup.has_method("setup"):
		pickup.setup(item_id, amount)
	if pickup.has_method("block_automatic_pickup"):
		pickup.block_automatic_pickup(1800.0)

func _return_loose_items() -> void:
	var loose: Array[ItemStack] = []
	if not carried.is_empty():
		loose.append(carried)
		carried = ItemStack.new()
	for stack in craft_slots:
		if not stack.is_empty():
			loose.append(stack)
	for i in range(9):
		craft_slots[i] = ItemStack.new()
	for stack in loose:
		var accepted := inventory.add_item(stack.item_id, stack.amount)
		if accepted < stack.amount:
			_spawn_dropped(stack.item_id, stack.amount - accepted)
	_refresh_all()


func _below_install_unified_hud() -> void:
	if has_node("UnifiedHotbarFoodController"):
		return
	var helper_script: Script = load("res://scripts/ui/hotbar_food_controller.gd") as Script
	var helper: Node = helper_script.new()
	helper.name = "UnifiedHotbarFoodController"
	add_child(helper)
