class_name GameplayInteractions
extends Node

const INTERACTION_DISTANCE: float = 110.0
const UI_REFRESH_INTERVAL: float = 0.15

var player: Node2D
var inventory: InventoryData
var active_target: Node2D

var mode: String = ""
var previous_pause: bool = false
var refresh_elapsed: float = 0.0

var overlay: ColorRect
var title_label: Label
var timer_label: Label
var object_grid: GridContainer
var player_grid: GridContainer
var fuel_button: Button
var hint_label: Label

var object_buttons: Array[Button] = []
var player_buttons: Array[Button] = []

# Независимый стак окна объекта; InventoryUI не изменяется.
var carried: ItemStack = ItemStack.new()
var carried_preview: HBoxContainer
var carried_icon: TextureRect
var carried_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_late_ready")


func _late_ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D

	if player == null and get_tree().current_scene != null:
		player = get_tree().current_scene.find_child(
			"Player", true, false
		) as Node2D

	if player != null:
		inventory = player.get("inventory") as InventoryData

	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if overlay == null:
		return

	if overlay.visible and event.is_action_pressed("ui_cancel"):
		close_window()
		get_viewport().set_input_as_handled()
		return

	if not InputMap.has_action("interact"):
		return

	if event.is_action_pressed("interact"):
		if event is InputEventKey and event.echo:
			return

		if overlay.visible:
			close_window()
		else:
			_try_interact()

		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_refresh_carried_preview()
	if overlay == null:
		return

	if overlay.visible:
		hint_label.visible = false

		if not is_instance_valid(active_target):
			close_window()
			return

		refresh_elapsed += delta

		if refresh_elapsed >= UI_REFRESH_INTERVAL:
			refresh_elapsed = 0.0
			_refresh_ui()

		return

	hint_label.visible = false

	if get_tree().paused or _inventory_is_open():
		return

	if player == null or bool(player.get("is_dead")):
		return

	var nearest: Node2D = _nearest_interactable()

	if nearest == null:
		return

	hint_label.visible = true
	hint_label.text = (
        "E — открыть сундук"
		if nearest.is_in_group("storage_chest")
		else "E — открыть костёр"
	)


func _inventory_is_open() -> bool:
	var ui: Node = get_tree().get_first_node_in_group("inventory_ui")

	if ui != null and ui.has_method("is_inventory_open"):
		return bool(ui.call("is_inventory_open"))

	return false


func _nearest_interactable() -> Node2D:
	if player == null:
		return null

	var best: Node2D = null
	var best_distance: float = INTERACTION_DISTANCE

	for group_name in ["storage_chest", "campfire_interactable"]:
		for node in get_tree().get_nodes_in_group(group_name):
			var candidate: Node2D = node as Node2D

			if candidate == null:
				continue

			var distance: float = player.global_position.distance_to(
				candidate.global_position
			)

			if distance < best_distance:
				best_distance = distance
				best = candidate

	return best


func _try_interact() -> void:
	if player == null or bool(player.get("is_dead")):
		return

	if get_tree().paused or _inventory_is_open():
		return

	if inventory == null:
		inventory = player.get("inventory") as InventoryData

	if inventory == null:
		push_warning("GameplayInteractions: инвентарь игрока не найден")
		return

	var target: Node2D = _nearest_interactable()

	if target == null:
		return

	active_target = target
	mode = (
        "chest"
		if active_target.is_in_group("storage_chest")
		else "campfire"
	)

	previous_pause = get_tree().paused
	get_tree().paused = true

	overlay.visible = true
	hint_label.visible = false
	refresh_elapsed = 0.0

	_refresh_ui()


func close_window() -> void:
	if overlay == null or not overlay.visible:
		return

	if not _return_carried():
		push_warning("Нет места для стака в руке. Сначала положите его в ячейку.")
		return

	overlay.visible = false
	active_target = null
	mode = ""

	get_tree().paused = previous_pause


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 80
	add_child(layer)

	overlay = ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.65)
	layer.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var window := PanelContainer.new()
	window.custom_minimum_size = Vector2(720, 560)
	center.add_child(window)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	window.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	box.add_child(title_label)

	timer_label = Label.new()
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(timer_label)

	object_grid = GridContainer.new()
	object_grid.columns = 4
	box.add_child(object_grid)

	fuel_button = Button.new()
	fuel_button.custom_minimum_size = Vector2(180, 44)
	fuel_button.gui_input.connect(_on_fuel_gui_input)
	fuel_button.focus_mode = Control.FOCUS_NONE
	box.add_child(fuel_button)

	var player_title := Label.new()
	player_title.text = "ИНВЕНТАРЬ ИГРОКА"
	box.add_child(player_title)

	player_grid = GridContainer.new()
	player_grid.columns = 9
	box.add_child(player_grid)

	var instructions := Label.new()
	instructions.text = "Костёр: ЛКМ — взять/положить стак. ПКМ на топливо — положить 1.\nСундук: клик снизу — положить, клик сверху — забрать."
	box.add_child(instructions)

	var close_button := Button.new()
	close_button.text = "Закрыть (E / Esc)"
	close_button.pressed.connect(close_window)
	box.add_child(close_button)

	hint_label = Label.new()
	hint_label.position = Vector2(24, 100)
	hint_label.add_theme_font_size_override("font_size", 18)
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label.visible = false
	layer.add_child(hint_label)

	var preview_layer := CanvasLayer.new()
	preview_layer.layer = 81
	add_child(preview_layer)
	carried_preview = HBoxContainer.new()
	carried_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_layer.add_child(carried_preview)
	carried_icon = TextureRect.new()
	carried_icon.custom_minimum_size = Vector2(32, 32)
	carried_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	carried_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	carried_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	carried_preview.add_child(carried_icon)
	carried_label = Label.new()
	carried_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	carried_preview.add_child(carried_label)
	carried_preview.visible = false
	overlay.visible = false


func _ensure_buttons(
		grid: GridContainer,
		views: Array[Button],
		count: int,
		for_player: bool
) -> void:
	if views.size() == count:
		return

	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()

	views.clear()

	for i in range(count):
		var button := Button.new()
		button.custom_minimum_size = Vector2(64, 52)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 28)

		if for_player:
			button.gui_input.connect(_on_player_gui_input.bind(i))
			button.focus_mode = Control.FOCUS_NONE
		else:
			button.pressed.connect(_on_object_slot_pressed.bind(i))

		grid.add_child(button)
		views.append(button)


func _set_button(
		button: Button,
		item_id: StringName,
		amount: int,
		clickable: bool
) -> void:
	button.icon = null
	button.tooltip_text = ""
	button.disabled = not clickable

	if item_id == &"" or amount <= 0:
		button.text = "—"
		return

	var item: ItemData = ItemRegistry.get_item(item_id)
	var item_name: String = (
		item.display_name if item != null else str(item_id)
	)

	button.tooltip_text = "%s × %d" % [item_name, amount]

	if item != null and item.icon != null:
		button.icon = item.icon
		button.text = str(amount)
	else:
		button.text = "%s\n×%d" % [item_name.substr(0, 10), amount]


func _refresh_ui() -> void:
	if not is_instance_valid(active_target):
		close_window()
		return

	if mode == "chest":
		var chest: ChestContainer = active_target as ChestContainer

		if chest == null:
			close_window()
			return

		title_label.text = "СУНДУК — %d ЯЧЕЕК" % chest.storage_size
		timer_label.text = "Нажмите заполненную ячейку, чтобы забрать"
		fuel_button.visible = false
		object_grid.columns = 4

		_ensure_buttons(
			object_grid, object_buttons, chest.storage_size, false
		)

		for i in range(chest.storage_size):
			_set_button(
				object_buttons[i],
				chest.storage_ids[i],
				chest.storage_amounts[i],
				true
			)
	else:
		_refresh_fire()

	if inventory == null:
		return

	_ensure_buttons(
		player_grid, player_buttons, inventory.slots.size(), true
	)

	for i in range(inventory.slots.size()):
		var stack: ItemStack = inventory.get_slot(i)

		if stack == null or stack.is_empty():
			_set_button(player_buttons[i], &"", 0, mode == "campfire")
		else:
			_set_button(
				player_buttons[i], stack.item_id, stack.amount, true
			)


func _refresh_fire() -> void:
	title_label.text = "КОСТЁР"
	timer_label.text = "До затухания: %s" % str(
		active_target.call("get_timer_text")
	)

	fuel_button.visible = true
	object_grid.columns = 5

	var fuel_id: StringName = StringName(active_target.get("fuel_id"))
	var fuel_amount: int = int(active_target.get("fuel_amount"))

	_set_button(fuel_button, fuel_id, fuel_amount, true)
	fuel_button.text = "Топливо: " + fuel_button.text

	var input_ids: Array = active_target.get("input_ids")
	var output_ids: Array = active_target.get("output_ids")
	var progress: Array = active_target.get("cook_progress")
	var cook_seconds: float = float(active_target.get("COOK_SECONDS"))

	_ensure_buttons(object_grid, object_buttons, 10, false)

	for i in range(5):
		var input_id: StringName = StringName(input_ids[i])

		_set_button(
			object_buttons[i],
			input_id,
			1 if input_id != &"" else 0,
			false
		)

		if input_id != &"":
			var remaining: float = maxf(
				0.0, cook_seconds - float(progress[i])
			)
			object_buttons[i].text += "\n%.1f с" % remaining

		var output_id: StringName = StringName(output_ids[i])

		_set_button(
			object_buttons[5 + i],
			output_id,
			1 if output_id != &"" else 0,
			true
		)


func _on_object_slot_pressed(index: int) -> void:
	if not is_instance_valid(active_target):
		return

	if mode == "chest":
		_take_from_chest(index)
	elif index >= 5:
		_take_from_fire(index - 5)


func _put_player_slot(index: int) -> void:
	if inventory == null or not is_instance_valid(active_target):
		return

	var stack: ItemStack = inventory.get_slot(index)

	if stack == null or stack.is_empty():
		return

	var moved: int = 0

	if mode == "chest":
		var chest: ChestContainer = active_target as ChestContainer

		if chest == null:
			return

		moved = chest.store_items(stack.item_id, stack.amount)
	elif stack.item_id == &"raw_meat":
		moved = int(active_target.call("add_raw_meat", stack.amount))
	elif mode != "campfire" and (stack.item_id == &"plank_scraps" or stack.item_id == &"coal"):
		moved = int(active_target.call(
			"add_fuel", stack.item_id, stack.amount
		))

	if moved > 0:
		inventory.remove_from_slot(index, moved)

	_refresh_ui()


func _take_from_chest(index: int) -> void:
	var chest: ChestContainer = active_target as ChestContainer

	if chest == null or inventory == null:
		return

	if index < 0 or index >= chest.storage_size:
		return

	var item_id: StringName = chest.storage_ids[index]
	var amount: int = chest.storage_amounts[index]

	if item_id == &"" or amount <= 0:
		return

	var available: int = inventory.get_addable_amount(item_id, amount)

	if available <= 0:
		return

	var data: Dictionary = chest.take_items(index, available)

	if data.is_empty():
		return

	var taken: int = int(data.get("amount", 0))
	var added: int = inventory.add_item(item_id, taken)

	if added < taken:
		chest.store_items(item_id, taken - added)

	_refresh_ui()


func _take_from_fire(index: int) -> void:
	if inventory == null or not is_instance_valid(active_target):
		return

	var output_ids: Array = active_target.get("output_ids")

	if index < 0 or index >= output_ids.size():
		return

	var item_id: StringName = StringName(output_ids[index])

	if item_id == &"" or not inventory.can_add_item(item_id, 1):
		return

	var data: Dictionary = active_target.call("collect_output", index)

	if data.is_empty():
		return

	var collected_id: StringName = StringName(data.get("item_id", ""))
	var amount: int = int(data.get("amount", 0))
	var added: int = inventory.add_item(collected_id, amount)

	if added < amount:
		output_ids[index] = collected_id

	_refresh_ui()


func _on_player_gui_input(event: InputEvent, index: int) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if not mouse.pressed or mouse.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		return
	player_buttons[index].accept_event()
	if mode != "campfire":
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			_put_player_slot(index)
		return
	if inventory == null:
		return
	var target: ItemStack = inventory.get_slot(index)
	if target == null:
		return
	if carried.is_empty():
		if target.is_empty():
			return
		# Эта правка касается топлива: прежняя подача мяса сохраняется.
		if target.item_id == &"raw_meat" and mouse.button_index == MOUSE_BUTTON_LEFT:
			_put_player_slot(index)
			return
		var requested: int = target.amount if mouse.button_index == MOUSE_BUTTON_LEFT else ceili(target.amount / 2.0)
		carried = inventory.take_from_slot(index, requested)
	elif target.is_empty() or target.item_id == carried.item_id:
		var item: ItemData = ItemRegistry.get_item(carried.item_id)
		var limit: int = item.max_stack if item != null else 64
		var requested: int = carried.amount if mouse.button_index == MOUSE_BUTTON_LEFT else 1
		var moved: int = mini(requested, maxi(limit - target.amount, 0))
		if item != null and item.unit_weight_kg > 0.0:
			moved = mini(moved, maxi(floori((inventory.get_free_weight_kg() + 0.000001) / item.unit_weight_kg), 0))
		if moved > 0:
			target.item_id = carried.item_id
			target.amount += moved
			carried.amount -= moved
			_clear_carried_if_empty()
			inventory.notify_changed()
	_refresh_ui()
	_refresh_carried_preview()


func _on_fuel_gui_input(event: InputEvent) -> void:
	if mode != "campfire" or not is_instance_valid(active_target):
		return
	if not event is InputEventMouseButton:
		return
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if not mouse.pressed or mouse.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		return
	fuel_button.accept_event()
	if carried.is_empty():
		var available: int = int(active_target.get("fuel_amount"))
		var requested: int = available if mouse.button_index == MOUSE_BUTTON_LEFT else ceili(available / 2.0)
		if requested > 0 and active_target.has_method("take_fuel"):
			var result: Dictionary = active_target.call("take_fuel", requested)
			carried.item_id = StringName(result.get("item_id", ""))
			carried.amount = int(result.get("amount", 0))
	else:
		var requested: int = carried.amount if mouse.button_index == MOUSE_BUTTON_LEFT else 1
		var accepted: int = int(active_target.call("add_fuel", carried.item_id, requested))
		carried.amount -= accepted
		_clear_carried_if_empty()
	_refresh_ui()
	_refresh_carried_preview()


func _clear_carried_if_empty() -> void:
	if carried.amount <= 0:
		carried.clear()


func _return_carried() -> bool:
	if carried.is_empty():
		return true
	if inventory == null:
		return false
	carried.amount -= inventory.add_item(carried.item_id, carried.amount)
	_clear_carried_if_empty()
	_refresh_carried_preview()
	return carried.is_empty()


func _refresh_carried_preview() -> void:
	if carried_preview == null:
		return
	carried_preview.visible = overlay != null and overlay.visible and not carried.is_empty()
	if not carried_preview.visible:
		return
	carried_preview.position = get_viewport().get_mouse_position() + Vector2(18, 18)
	var item: ItemData = ItemRegistry.get_item(carried.item_id)
	carried_icon.texture = item.icon if item != null else null
	var item_name: String = item.display_name if item != null else str(carried.item_id)
	carried_label.text = "%s × %d" % [item_name, carried.amount]
