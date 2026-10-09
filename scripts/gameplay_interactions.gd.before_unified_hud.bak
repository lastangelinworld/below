class_name GameplayInteractions
extends Node

const INTERACTION_DISTANCE := 110.0
const UI_REFRESH_INTERVAL := 0.10

var player: Node2D
var inventory: InventoryData
var ui: InventoryUI

var active_target: Node2D
var mode := ""

var panel: VBoxContainer
var craft_column: Control
var hidden_controls: Dictionary = {}

var title_label: Label
var timer_label: Label
var hint_label: Label

var input_views: Array[InventorySlotUI] = []
var output_views: Array[InventorySlotUI] = []
var fuel_views: Array[InventorySlotUI] = []
var chest_views: Array[InventorySlotUI] = []

var fuel_bars: Array[ProgressBar] = []
var fuel_labels: Array[Label] = []

var refresh_elapsed := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_late_ready")


func _late_ready() -> void:
	_find_dependencies()

	var layer := CanvasLayer.new()
	add_child(layer)

	hint_label = Label.new()
	hint_label.position = Vector2(24, 100)
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label.visible = false
	layer.add_child(hint_label)


func _find_dependencies() -> bool:
	ui = get_tree().get_first_node_in_group(
		"inventory_ui"
	) as InventoryUI

	player = get_tree().get_first_node_in_group(
		"player"
	) as Node2D

	if player == null and get_tree().current_scene != null:
		player = get_tree().current_scene.find_child(
			"Player", true, false
		) as Node2D

	if ui == null or player == null:
		return false

	inventory = player.get("inventory") as InventoryData

	return inventory != null and ui.slot_scene != null


func _unhandled_input(event: InputEvent) -> void:
	if panel != null and event.is_action_pressed("ui_cancel"):
		close_window()
		get_viewport().set_input_as_handled()
		return

	if not InputMap.has_action("interact"):
		return

	if not event.is_action_pressed("interact"):
		return

	if event is InputEventKey and event.echo:
		return

	if panel != null:
		close_window()
	elif not get_tree().paused and not _inventory_is_open():
		_try_interact()

	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if hint_label != null:
		hint_label.visible = false

	if panel != null:
		if not is_instance_valid(active_target):
			close_window()
			return

		if not is_instance_valid(player):
			close_window()
			return

		if bool(player.get("is_dead")):
			close_window()
			return

		refresh_elapsed += delta

		if refresh_elapsed >= UI_REFRESH_INTERVAL:
			refresh_elapsed = 0.0
			_refresh_ui()

		return

	if get_tree().paused or _inventory_is_open():
		return

	if not is_instance_valid(player):
		return

	if bool(player.get("is_dead")):
		return

	var nearest: Node2D = _nearest_interactable()

	if nearest != null and hint_label != null:
		hint_label.visible = true
		hint_label.text = (
			"E — открыть сундук"
			if nearest.is_in_group("storage_chest")
			else "E — открыть костёр"
		)


func _inventory_is_open() -> bool:
	return (
		is_instance_valid(ui)
		and ui.is_inventory_open()
	)


func _nearest_interactable() -> Node2D:
	if not is_instance_valid(player):
		return null

	var best: Node2D
	var best_distance: float = INTERACTION_DISTANCE

	for group_name: String in [
		"storage_chest",
		"campfire_interactable"
	]:
		for node: Node in get_tree().get_nodes_in_group(group_name):
			var candidate := node as Node2D

			if candidate == null:
				continue

			if not (candidate is Campfire or candidate is ChestContainer):
				continue

			var distance: float = player.global_position.distance_to(
				candidate.global_position
			)

			if distance < best_distance:
				best_distance = distance
				best = candidate

	return best


func _try_interact() -> void:
	if not _find_dependencies():
		push_warning(
			"GameplayInteractions: не найден Player, "
			+ "InventoryUI, InventoryData или slot_scene."
		)
		return

	if bool(player.get("is_dead")):
		return

	var target: Node2D = _nearest_interactable()

	if target != null:
		_open_target(target)


func _open_target(target: Node2D) -> void:
	if panel != null or ui.is_inventory_open():
		return

	# В предоставленном InventoryUI:
	# CraftColumn -> CraftRow -> CraftGrid.
	craft_column = ui.craft_grid.get_parent().get_parent() as Control

	if craft_column == null:
		push_error("GameplayInteractions: CraftColumn не найдена.")
		return

	active_target = target
	mode = "campfire" if target is Campfire else "chest"

	# Сохраняем видимость обычных элементов крафта.
	hidden_controls.clear()

	for child: Node in craft_column.get_children():
		if child is Control:
			hidden_controls[child] = child.visible
			child.hide()

	panel = VBoxContainer.new()
	panel.add_theme_constant_override("separation", 8)
	craft_column.add_child(panel)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title_label)

	timer_label = Label.new()
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(timer_label)

	if mode == "campfire":
		_add_heading("СЫРОЕ МЯСО")
		_build_grid(input_views, 5, "raw", 5)

		panel.add_child(HSeparator.new())

		_add_heading("ГОТОВАЯ ПРОДУКЦИЯ")
		_build_grid(output_views, 5, "output", 5)

		panel.add_child(HSeparator.new())

		_add_heading("ТОПЛИВО")
		_build_fuel_grid()
	else:
		var chest := target as ChestContainer
		chest._ensure_storage()
		_build_grid(
			chest_views,
			chest.storage_size,
			"chest",
			4
		)

	var instructions := Label.new()
	instructions.text = (
		"ЛКМ — взять / положить стак\n"
		+ "ПКМ — положить 1\n"
		+ "Мясо — только 1 в ячейку\n"
		+ "Shift + ЛКМ — быстрый перенос"
	)
	panel.add_child(instructions)

	var close_button := Button.new()
	close_button.text = "Закрыть (E / Esc)"
	close_button.pressed.connect(close_window)
	panel.add_child(close_button)

	ui.external_handler = self
	ui.open_inventory()
	refresh_elapsed = 0.0
	_refresh_ui()


func _add_heading(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)


func _build_grid(
		views: Array[InventorySlotUI],
		count: int,
		kind: String,
		columns: int
) -> void:
	var grid := GridContainer.new()
	grid.columns = columns
	panel.add_child(grid)

	for i: int in range(count):
		var view := ui.slot_scene.instantiate() as InventorySlotUI
		view.setup(i)
		grid.add_child(view)
		view.slot_pressed.connect(
			_on_slot_pressed.bind(kind)
		)
		views.append(view)


func _build_fuel_grid() -> void:
	var grid := GridContainer.new()
	grid.columns = 5
	panel.add_child(grid)

	for i: int in range(5):
		var box := VBoxContainer.new()
		grid.add_child(box)

		var view := ui.slot_scene.instantiate() as InventorySlotUI
		view.setup(i)
		box.add_child(view)
		view.slot_pressed.connect(
			_on_slot_pressed.bind("fuel")
		)
		fuel_views.append(view)

		var bar := ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = 1.0
		bar.show_percentage = false
		bar.custom_minimum_size.y = 6
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(bar)
		fuel_bars.append(bar)

		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 10)
		box.add_child(label)
		fuel_labels.append(label)


func close_window() -> void:
	if panel == null:
		return

	# Убираем обработчик до вызова close_inventory(),
	# иначе получится повторный вызов close_window().
	if is_instance_valid(ui):
		ui.external_handler = null
		ui.close_inventory()

	for child: Variant in hidden_controls:
		if is_instance_valid(child):
			child.visible = bool(hidden_controls[child])

	hidden_controls.clear()

	if is_instance_valid(panel):
		var parent: Node = panel.get_parent()
		if parent != null:
			parent.remove_child(panel)
		panel.queue_free()

	panel = null
	craft_column = null
	active_target = null
	mode = ""

	input_views.clear()
	output_views.clear()
	fuel_views.clear()
	chest_views.clear()

	fuel_bars.clear()
	fuel_labels.clear()


func _display(
		view: InventorySlotUI,
		item_id: StringName,
		amount: int
) -> void:
	var stack := ItemStack.new()
	stack.item_id = item_id
	stack.amount = amount
	view.display_stack(stack)


func _refresh_ui() -> void:
	if panel == null or not is_instance_valid(active_target):
		return

	if mode == "campfire":
		var fire := active_target as Campfire

		title_label.text = "КОСТЁР"
		timer_label.text = "До затухания: " + fire.get_timer_text()

		for i: int in range(5):
			_display(input_views[i], fire.input_ids[i], 1)
			_display(output_views[i], fire.output_ids[i], 1)
			_display(
				fuel_views[i],
				fire.fuel_ids[i],
				fire.fuel_amounts[i]
			)

			# Для топлива показываем даже очередь из 1 единицы.
			fuel_views[i].amount_label.text = (
				str(fire.fuel_amounts[i])
				if fire.fuel_amounts[i] > 0
				else ""
			)

			fuel_bars[i].value = fire.get_fuel_progress(i)
			fuel_labels[i].text = (
				Campfire.format_seconds(
					fire.active_fuel_seconds[i]
				)
				if fire.active_fuel_seconds[i] > 0.0
				else "—"
			)

			fuel_views[i].tooltip_text += (
				"\nОжидает: %d" % fire.fuel_amounts[i]
			)

			if fire.active_fuel_seconds[i] > 0.0:
				var item: ItemData = ItemRegistry.get_item(
					fire.active_fuel_ids[i]
				)
				var item_name: String = (
					item.display_name
					if item != null
					else str(fire.active_fuel_ids[i])
				)

				fuel_views[i].tooltip_text += (
					"\nГорит: %s\nОсталось: %s"
					% [item_name, fuel_labels[i].text]
				)

			if fire.input_ids[i] != &"":
				input_views[i].tooltip_text += (
					"\nДо готовности: %s"
					% Campfire.format_seconds(
						Campfire.COOK_SECONDS
						- fire.cook_progress[i]
					)
				)

			if fire.output_ids[i] == &"cooked_meat":
				output_views[i].tooltip_text += (
					"\nДо превращения в уголь: %s"
					% Campfire.format_seconds(
						Campfire.READY_SECONDS
						- fire.ready_progress[i]
					)
				)
	else:
		var chest := active_target as ChestContainer
		title_label.text = "СУНДУК — %d ЯЧЕЕК" % chest.storage_size
		timer_label.text = ""

		for i: int in range(chest.storage_size):
			_display(
				chest_views[i],
				chest.storage_ids[i],
				chest.storage_amounts[i]
			)


func _on_slot_pressed(
		index: int,
		button: MouseButton,
		kind: String
) -> void:
	if not is_instance_valid(active_target):
		return

	if button == MOUSE_BUTTON_LEFT:
		if Input.is_key_pressed(KEY_SHIFT) and ui.carried.is_empty():
			_quick_from_object(index, kind)
			ui._refresh_all()
			_refresh_ui()
			return

	if ui.carried.is_empty():
		_pick_from_object(index, button, kind)
	else:
		_put_into_object(index, button, kind)

	ui._refresh_all()
	_refresh_ui()


func _pick_from_object(
		index: int,
		button: MouseButton,
		kind: String
) -> void:
	var result: Dictionary = {}

	if kind == "chest":
		var chest := active_target as ChestContainer
		var count: int = chest.storage_amounts[index]

		if button == MOUSE_BUTTON_RIGHT:
			count = ceili(float(count) / 2.0)

		result = chest.take_items(index, count)
	else:
		var fire := active_target as Campfire

		match kind:
			"raw":
				result = fire.take_raw_meat(index)

			"output":
				result = fire.collect_output(index)

			"fuel":
				var count: int = fire.fuel_amounts[index]

				if button == MOUSE_BUTTON_RIGHT:
					count = ceili(float(count) / 2.0)

				result = fire.take_fuel(index, count)

	if not result.is_empty():
		ui.carried.item_id = StringName(result["item_id"])
		ui.carried.amount = int(result["amount"])


func _put_into_object(
		index: int,
		button: MouseButton,
		kind: String
) -> void:
	var requested: int = (
		ui.carried.amount
		if button == MOUSE_BUTTON_LEFT
		else 1
	)
	var moved := 0

	if kind == "chest":
		var chest := active_target as ChestContainer
		var item: ItemData = ItemRegistry.get_item(
			ui.carried.item_id
		)

		if item == null:
			return

		if chest.storage_amounts[index] <= 0:
			moved = mini(requested, item.max_stack)

			if moved > 0:
				chest.storage_ids[index] = ui.carried.item_id
				chest.storage_amounts[index] = moved

		elif chest.storage_ids[index] == ui.carried.item_id:
			moved = mini(
				requested,
				maxi(
					0,
					item.max_stack - chest.storage_amounts[index]
				)
			)
			chest.storage_amounts[index] += moved

		elif button == MOUSE_BUTTON_LEFT:
			var old_id: StringName = chest.storage_ids[index]
			var old_amount: int = chest.storage_amounts[index]

			chest.storage_ids[index] = ui.carried.item_id
			chest.storage_amounts[index] = ui.carried.amount

			ui.carried.item_id = old_id
			ui.carried.amount = old_amount
			return
	else:
		var fire := active_target as Campfire

		match kind:
			"raw":
				if ui.carried.item_id == &"raw_meat":
					# Всегда максимум один кусок,
					# независимо от кнопки мыши.
					moved = fire.put_raw_meat(index)

			"fuel":
				moved = fire.add_fuel_to_slot(
					index,
					ui.carried.item_id,
					requested
				)

			"output":
				# В нижний ряд предметы не помещаются.
				# Можно только добавить готовый результат
				# к совместимому стаку в руке.
				var output_id: StringName = fire.output_ids[index]

				if output_id == &"":
					return

				if output_id != ui.carried.item_id:
					return

				var item: ItemData = ItemRegistry.get_item(output_id)
				if item == null or ui.carried.amount >= item.max_stack:
					return

				var result: Dictionary = fire.collect_output(index)
				if not result.is_empty():
					ui.carried.amount += int(result["amount"])
				return

	ui.carried.amount -= moved
	ui._clear_if_empty(ui.carried)


func quick_transfer_player(index: int) -> void:
	if not is_instance_valid(active_target):
		return

	if not ui.carried.is_empty():
		return

	var stack: ItemStack = inventory.get_slot(index)

	if stack == null or stack.is_empty():
		return

	var moved := 0

	if mode == "chest":
		var chest := active_target as ChestContainer
		moved = chest.store_items(stack.item_id, stack.amount)
	else:
		var fire := active_target as Campfire

		if stack.item_id == &"raw_meat":
			moved = fire.add_raw_meat(stack.amount)

		elif stack.item_id == &"plank_scraps" or stack.item_id == &"coal":
			moved = fire.add_fuel(stack.item_id, stack.amount)

	if moved > 0:
		inventory.remove_from_slot(index, moved)

	ui._refresh_all()
	_refresh_ui()


func _quick_from_object(index: int, kind: String) -> void:
	var item_id: StringName = &""
	var amount := 0

	if kind == "chest":
		var chest := active_target as ChestContainer
		item_id = chest.storage_ids[index]
		amount = chest.storage_amounts[index]
	else:
		var fire := active_target as Campfire

		match kind:
			"raw":
				item_id = fire.input_ids[index]
				amount = 1 if item_id != &"" else 0

			"output":
				item_id = fire.output_ids[index]
				amount = 1 if item_id != &"" else 0

			"fuel":
				item_id = fire.fuel_ids[index]
				amount = fire.fuel_amounts[index]

	if amount <= 0:
		return

	# Сначала убеждаемся, что инвентарь принимает ресурс.
	var accepted: int = inventory.add_item(item_id, amount)

	if accepted <= 0:
		return

	if kind == "chest":
		var chest := active_target as ChestContainer
		chest.take_items(index, accepted)
	else:
		var fire := active_target as Campfire

		match kind:
			"raw":
				fire.take_raw_meat(index)

			"output":
				fire.collect_output(index)

			"fuel":
				fire.take_fuel(index, accepted)
