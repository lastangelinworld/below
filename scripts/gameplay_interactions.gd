class_name GameplayInteractions
extends Node

const INTERACTION_DISTANCE: float = 110.0
const UI_REFRESH_INTERVAL: float = 0.15

var player: Node2D
var inventory: InventoryData
var active_target: Node2D

var source_inventory_ui: Node
var shared_slot_scene: PackedScene
var source_window: Control

var mode: String = ""
var previous_pause: bool = false
var refresh_elapsed: float = 0.0

var overlay: ColorRect
var window_panel: PanelContainer
var title_label: Label
var timer_label: Label
var object_grid: GridContainer
var player_grid: GridContainer
var player_hotbar_grid: GridContainer
var hotbar_title: Label
var fuel_row: HBoxContainer
var fuel_view: InventorySlotUI
var hint_label: Label

var object_views: Array[InventorySlotUI] = []
var player_views: Array[InventorySlotUI] = []
var hotbar_views: Array[InventorySlotUI] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_late_ready")


func _late_ready() -> void:
	# Даём другим интерфейсам завершить начальную настройку.
	await get_tree().process_frame

	player = get_tree().get_first_node_in_group(
		"player"
	) as Node2D

	if player == null and get_tree().current_scene != null:
		player = get_tree().current_scene.find_child(
			"Player", true, false
		) as Node2D

	if player != null:
		inventory = player.get("inventory") as InventoryData

	source_inventory_ui = get_tree().get_first_node_in_group(
		"inventory_ui"
	)

	if source_inventory_ui == null:
		push_error(
			"GameplayInteractions: не найден интерфейс "
			+ "в группе inventory_ui."
		)
		return

	shared_slot_scene = source_inventory_ui.get(
		"slot_scene"
	) as PackedScene

	if shared_slot_scene == null:
		push_error(
			"GameplayInteractions: у InventoryUI "
			+ "не назначена Slot Scene."
		)
		return

	# Проверяем, что используем именно ячейку игрока.
	var probe: Node = shared_slot_scene.instantiate()
	var valid_slot: bool = probe is InventorySlotUI
	probe.free()

	if not valid_slot:
		push_error(
			"GameplayInteractions: корень Slot Scene "
			+ "должен использовать InventorySlotUI."
		)
		return

	source_window = source_inventory_ui.get_node_or_null(
		"Overlay/Center/InventoryWindow"
	) as Control

	if source_window == null:
		push_warning(
			"GameplayInteractions: окно InventoryWindow "
			+ "не найдено. Ячейки будут общими, "
			+ "но стиль панели нужно будет уточнить."
		)

	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if overlay == null:
		return

	if event is InputEventKey and event.echo:
		return

	if overlay.visible and event.is_action_pressed("ui_cancel"):
		close_window()
		get_viewport().set_input_as_handled()
		return

	if not InputMap.has_action("interact"):
		return

	if event.is_action_pressed("interact"):
		if overlay.visible:
			close_window()
		else:
			_try_interact()

		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
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

	if not is_instance_valid(player):
		return

	if bool(player.get("is_dead")):
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
	if not is_instance_valid(source_inventory_ui):
		return false

	if source_inventory_ui.has_method("is_inventory_open"):
		return bool(
			source_inventory_ui.call("is_inventory_open")
		)

	# Поддержка InventoryUI без метода is_inventory_open().
	var inventory_overlay: Control = (
		source_inventory_ui.get_node_or_null(
			"Overlay"
		) as Control
	)

	return (
		inventory_overlay != null
		and inventory_overlay.visible
	)


func _nearest_interactable() -> Node2D:
	if not is_instance_valid(player):
		return null

	var best: Node2D = null
	var best_distance: float = INTERACTION_DISTANCE

	for group_name in [
		"storage_chest",
		"campfire_interactable"
	]:
		for node in get_tree().get_nodes_in_group(group_name):
			var candidate: Node2D = node as Node2D

			if candidate == null:
				continue

			var distance: float = (
				player.global_position.distance_to(
					candidate.global_position
				)
			)

			if distance < best_distance:
				best_distance = distance
				best = candidate

	return best


func _try_interact() -> void:
	if not is_instance_valid(player):
		return

	if bool(player.get("is_dead")):
		return

	if get_tree().paused or _inventory_is_open():
		return

	if inventory == null:
		inventory = player.get("inventory") as InventoryData

	if inventory == null:
		push_warning(
			"GameplayInteractions: инвентарь игрока не найден."
		)
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

	# Повторно берём стиль панели при открытии.
	if is_instance_valid(source_window):
		_copy_appearance(source_window, window_panel)

	_fit_window()

	previous_pause = get_tree().paused
	get_tree().paused = true

	overlay.visible = true
	hint_label.visible = false
	refresh_elapsed = 0.0

	_refresh_ui()


func close_window() -> void:
	if overlay == null or not overlay.visible:
		return

	overlay.visible = false
	active_target = null
	mode = ""

	get_tree().paused = previous_pause


func _find_effective_theme(control: Control) -> Theme:
	var current: Node = control

	while current != null:
		if current is Control:
			var current_control: Control = current as Control

			if current_control.theme != null:
				return current_control.theme

		current = current.get_parent()

	return null


func _copy_appearance(
		source: Control,
		target: Control
) -> void:
	# Общая тема, в том числе унаследованная от родителей.
	target.theme = _find_effective_theme(source)
	target.theme_type_variation = source.theme_type_variation

	# Локальные настройки оформления исходного узла.
	for property_info in source.get_property_list():
		var property_name: String = str(
			property_info.get("name", "")
		)

		if property_name.begins_with("theme_override"):
			target.set(
				property_name,
				source.get(property_name)
			)

	# Стиль панели может находиться в родительской Theme,
	# а не среди локальных переопределений.
	if source is PanelContainer or source is Panel:
		if source.has_theme_stylebox("panel"):
			target.add_theme_stylebox_override(
				"panel",
				source.get_theme_stylebox("panel")
			)


func _reference_player_slot() -> InventorySlotUI:
	if not is_instance_valid(source_inventory_ui):
		return null

	var main_grid: GridContainer = (
		source_inventory_ui.get_node_or_null(
			"Overlay/Center/InventoryWindow/Margin/Main/"
			+ "Content/PlayerColumn/MainInventoryGrid"
		) as GridContainer
	)

	if main_grid == null:
		return null

	for child in main_grid.get_children():
		if child is InventorySlotUI:
			if not child.is_queued_for_deletion():
				return child as InventorySlotUI

	return null


func _new_slot(
		index: int,
		for_player: bool
) -> InventorySlotUI:
	var view: InventorySlotUI = (
		shared_slot_scene.instantiate() as InventorySlotUI
	)

	view.setup(index)

	# Та же сцена сохраняет размеры, дочерние узлы,
	# иконку, счётчик и рамку выделения.
	# Дополнительно переносим оформление, унаследованное
	# существующей ячейкой от интерфейса игрока.
	var reference: InventorySlotUI = _reference_player_slot()

	if reference != null:
		_copy_appearance(reference, view)

	if for_player:
		view.slot_pressed.connect(_on_player_slot_pressed)
	else:
		view.slot_pressed.connect(_on_object_slot_pressed)

	return view


func _build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 80
	add_child(layer)

	overlay = ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.65)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	if is_instance_valid(source_inventory_ui):
		var original_overlay: ColorRect = (
			source_inventory_ui.get_node_or_null(
				"Overlay"
			) as ColorRect
		)

		if original_overlay != null:
			overlay.color = original_overlay.color

	var center: CenterContainer = CenterContainer.new()
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	window_panel = PanelContainer.new()
	center.add_child(window_panel)

	if is_instance_valid(source_window):
		_copy_appearance(source_window, window_panel)

	_fit_window()

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	window_panel.add_child(margin)

	# Позволяет просматривать большой сундук,
	# не растягивая окно за пределы экрана.
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	box.add_child(title_label)

	timer_label = Label.new()
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(timer_label)

	object_grid = GridContainer.new()
	object_grid.columns = 4
	object_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(object_grid)

	fuel_row = HBoxContainer.new()
	fuel_row.add_theme_constant_override("separation", 12)
	box.add_child(fuel_row)

	var fuel_title: Label = Label.new()
	fuel_title.text = "ТОПЛИВО"
	fuel_row.add_child(fuel_title)

	fuel_view = _new_slot(-1, false)
	fuel_row.add_child(fuel_view)

	var separator: HSeparator = HSeparator.new()
	box.add_child(separator)

	var player_title: Label = Label.new()
	player_title.text = "ИНВЕНТАРЬ ИГРОКА"
	box.add_child(player_title)

	player_grid = GridContainer.new()
	player_grid.columns = 9
	player_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(player_grid)

	hotbar_title = Label.new()
	hotbar_title.text = "ПАНЕЛЬ БЫСТРОГО ДОСТУПА"
	box.add_child(hotbar_title)

	player_hotbar_grid = GridContainer.new()
	player_hotbar_grid.columns = 9
	player_hotbar_grid.size_flags_horizontal = (
		Control.SIZE_SHRINK_CENTER
	)
	box.add_child(player_hotbar_grid)

	var instructions: Label = Label.new()
	instructions.text = (
		"ЛКМ по ячейке игрока — положить.\n"
		+ "ЛКМ по ячейке объекта — забрать."
	)
	box.add_child(instructions)

	var close_button: Button = Button.new()
	close_button.text = "Закрыть (E / Esc)"
	close_button.custom_minimum_size.y = 40
	close_button.pressed.connect(close_window)
	box.add_child(close_button)

	hint_label = Label.new()
	hint_label.position = Vector2(24, 100)
	hint_label.add_theme_font_size_override("font_size", 18)
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label.visible = false
	layer.add_child(hint_label)

	overlay.visible = false


func _fit_window() -> void:
	if window_panel == null:
		return

	var viewport_size: Vector2 = (
		get_viewport().get_visible_rect().size
	)

	window_panel.custom_minimum_size = Vector2(
		minf(900.0, maxf(200.0, viewport_size.x - 32.0)),
		minf(700.0, maxf(200.0, viewport_size.y - 32.0))
	)


func _ensure_slots(
		grid: GridContainer,
		views: Array[InventorySlotUI],
		count: int,
		for_player: bool,
		start_index: int = 0
) -> void:
	if views.size() == count:
		return

	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()

	views.clear()

	for i in range(count):
		var view: InventorySlotUI = _new_slot(
			start_index + i,
			for_player
		)

		grid.add_child(view)
		views.append(view)


func _set_slot(
		view: InventorySlotUI,
		item_id: StringName,
		amount: int,
		clickable: bool
) -> void:
	var stack: ItemStack = ItemStack.new()
	stack.set_item(item_id, amount)

	# Используется тот же метод отображения,
	# что и в основном инвентаре.
	view.display_stack(stack)
	view.set_selected(false)

	var can_click: bool = (
		clickable
		and not stack.is_empty()
	)

	view.set_meta("interaction_clickable", can_click)
	view.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND
		if can_click
		else Control.CURSOR_ARROW
	)


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
		timer_label.text = "Нажмите предмет, чтобы забрать его"
		fuel_row.visible = false
		object_grid.columns = 4

		_ensure_slots(
			object_grid,
			object_views,
			chest.storage_size,
			false
		)

		for i in range(chest.storage_size):
			_set_slot(
				object_views[i],
				chest.storage_ids[i],
				chest.storage_amounts[i],
				true
			)
	else:
		_refresh_fire()

	_refresh_player_inventory()


func _refresh_player_inventory() -> void:
	if inventory == null:
		return

	var total_slots: int = inventory.slots.size()

	# Сохраняем устройство текущего интерфейса:
	# первые 27 ячеек — основной инвентарь,
	# следующие 9 — панель быстрого доступа.
	var main_count: int = mini(27, total_slots)
	var hotbar_count: int = mini(
		9,
		maxi(total_slots - main_count, 0)
	)

	_ensure_slots(
		player_grid,
		player_views,
		main_count,
		true
	)

	_ensure_slots(
		player_hotbar_grid,
		hotbar_views,
		hotbar_count,
		true,
		main_count
	)

	hotbar_title.visible = hotbar_count > 0
	player_hotbar_grid.visible = hotbar_count > 0

	for i in range(main_count):
		_display_player_slot(player_views[i], i)

	var selected_hotbar: int = -1

	if is_instance_valid(player):
		selected_hotbar = int(
			player.get_meta("selected_hotbar_index", -1)
		)

	for i in range(hotbar_count):
		_display_player_slot(
			hotbar_views[i],
			main_count + i
		)
		hotbar_views[i].set_selected(
			i == selected_hotbar
		)


func _display_player_slot(
		view: InventorySlotUI,
		index: int
) -> void:
	var stack: ItemStack = inventory.get_slot(index)

	if stack == null or stack.is_empty():
		_set_slot(view, &"", 0, false)
	else:
		_set_slot(
			view,
			stack.item_id,
			stack.amount,
			true
		)


func _refresh_fire() -> void:
	title_label.text = "КОСТЁР"
	timer_label.text = (
		"До затухания: %s\n"
		+ "Верхний ряд — готовится. Нижний — результат."
	) % str(active_target.call("get_timer_text"))

	fuel_row.visible = true
	object_grid.columns = 5

	var fuel_id: StringName = StringName(
		active_target.get("fuel_id")
	)
	var fuel_amount: int = int(
		active_target.get("fuel_amount")
	)

	_set_slot(fuel_view, fuel_id, fuel_amount, false)

	var input_ids: Array = active_target.get("input_ids")
	var output_ids: Array = active_target.get("output_ids")
	var progress: Array = active_target.get("cook_progress")
	var cook_seconds: float = float(
		active_target.get("COOK_SECONDS")
	)

	_ensure_slots(
		object_grid,
		object_views,
		10,
		false
	)

	for i in range(5):
		var input_id: StringName = &""

		if i < input_ids.size():
			input_id = StringName(input_ids[i])

		_set_slot(
			object_views[i],
			input_id,
			1 if input_id != &"" else 0,
			false
		)

		if input_id != &"":
			var current_progress: float = 0.0

			if i < progress.size():
				current_progress = float(progress[i])

			var remaining: float = maxf(
				0.0,
				cook_seconds - current_progress
			)

			object_views[i].tooltip_text += (
				"\nДо готовности: %.1f с" % remaining
			)

		var output_id: StringName = &""

		if i < output_ids.size():
			output_id = StringName(output_ids[i])

		_set_slot(
			object_views[5 + i],
			output_id,
			1 if output_id != &"" else 0,
			true
		)


func _on_player_slot_pressed(
		index: int,
		mouse_button: MouseButton
) -> void:
	if mouse_button != MOUSE_BUTTON_LEFT:
		return

	_put_player_slot(index)


func _on_object_slot_pressed(
		index: int,
		mouse_button: MouseButton
) -> void:
	if mouse_button != MOUSE_BUTTON_LEFT:
		return

	if not is_instance_valid(active_target):
		return

	if index < 0 or index >= object_views.size():
		return

	if not bool(
		object_views[index].get_meta(
			"interaction_clickable",
			false
		)
	):
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

		moved = chest.store_items(
			stack.item_id,
			stack.amount
		)
	elif stack.item_id == &"raw_meat":
		moved = int(
			active_target.call(
				"add_raw_meat",
				stack.amount
			)
		)
	elif (
		stack.item_id == &"plank_scraps"
		or stack.item_id == &"coal"
	):
		moved = int(
			active_target.call(
				"add_fuel",
				stack.item_id,
				stack.amount
			)
		)

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

	var available: int = inventory.get_addable_amount(
		item_id,
		amount
	)

	if available <= 0:
		return

	var data: Dictionary = chest.take_items(
		index,
		available
	)

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

	var data: Dictionary = active_target.call(
		"collect_output",
		index
	)

	if data.is_empty():
		return

	var collected_id: StringName = StringName(
		data.get("item_id", "")
	)
	var amount: int = int(data.get("amount", 0))
	var added: int = inventory.add_item(
		collected_id,
		amount
	)

	if added < amount:
		output_ids[index] = collected_id

	_refresh_ui()
