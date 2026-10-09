extends Node
## Runtime companion for the existing InventoryUI. No scene replacement required.
const FIRST_FOOD_SLOT := 36
const FOOD_DURATION := 1800.0
const FOOD_IDS: Array[StringName] = [&"raw_meat", &"cooked_meat"]

var ui: Node
var player: Node
var inventory: InventoryData
var food_views: Array[InventorySlotUI] = []
var food_labels: Array[Label] = []
var effects: Array[Dictionary] = []
var hud_layer: CanvasLayer
var food_grid: HBoxContainer
var hp_property: StringName = &""
var stamina_property: StringName = &""
var refresh_elapsed := 0.0
var initialized := false
var hud_root: Control
var bottom_dock: Control
var bottom_box: VBoxContainer

var compact_weight: VBoxContainer
var window_area: Control
var compact_window: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("below_food_runtime")
	ui = get_parent()
	call_deferred("_initialize")

func _initialize() -> void:
	if not is_instance_valid(ui):
		return
	inventory = ui.get("inventory") as InventoryData
	player = ui.get("player") as Node
	if inventory == null or player == null:
		push_error("HUD update: сначала подключите Player и InventoryData к InventoryUI.")
		return
	inventory.slot_count = maxi(inventory.slot_count, 39)
	while inventory.slots.size() < inventory.slot_count:
		inventory.slots.append(ItemStack.new())
	for i in range(inventory.slots.size()):
		if inventory.slots[i] == null:
			inventory.slots[i] = ItemStack.new()
	hp_property = _find_property([&"max_health", &"health_max", &"maximum_health"])
	stamina_property = _find_property([&"max_stamina", &"stamina_max", &"maximum_stamina"])
	_build_hud()
	_bind_manual_use()
	initialized = true
	_normalize_food_stocks()
	inventory.notify_changed()
	_refresh_food()

func _find_property(names: Array[StringName]) -> StringName:
	for info: Dictionary in player.get_property_list():
		var name := StringName(info.get("name", ""))
		if name in names:
			return name
	return &""

func _build_hud() -> void:
	# Скрытые старые ячейки сохраняем:
	# InventoryUI продолжает использовать ссылки на них.
	var duplicate: Control = (
		ui.get("inventory_hotbar_grid") as Control
	)

	if duplicate != null:
		duplicate.hide()
		_hide_hotbar_titles(duplicate.get_parent())

	_hide_legacy_food(ui.get("inventory_window") as Node)

	hud_layer = CanvasLayer.new()
	hud_layer.name = "UnifiedHotbarLayer"
	hud_layer.layer = maxi(
		int(ui.get("layer")) + 10,
		100
	)
	add_child(hud_layer)

	hud_root = Control.new()
	hud_root.name = "UnifiedHUDRoot"
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(hud_root)
	hud_root.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	bottom_dock = Control.new()
	bottom_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(bottom_dock)

	bottom_box = VBoxContainer.new()
	bottom_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_box.add_theme_constant_override("separation", 4)
	bottom_dock.add_child(bottom_box)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 16)
	bottom_box.add_child(row)

	# Левая группа: заголовок, ячейки, номера.
	var hotbar_column := VBoxContainer.new()
	hotbar_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hotbar_column.add_theme_constant_override("separation", 3)
	row.add_child(hotbar_column)

	hotbar_column.add_child(
		_make_hud_label("БЫСТРЫЙ ДОСТУП")
	)

	var grid: GridContainer = (
		ui.get("hotbar_grid") as GridContainer
	)
	var old_vbox: Control = grid.get_parent() as Control

	grid.reparent(hotbar_column)
	grid.columns = 9
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var numbers := GridContainer.new()
	numbers.columns = 9
	numbers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	numbers.add_theme_constant_override(
		"h_separation",
		grid.get_theme_constant("h_separation")
	)
	hotbar_column.add_child(numbers)

	var hotbar_views: Array = ui.get("hotbar_views")

	for i in range(hotbar_views.size()):
		var view := hotbar_views[i] as InventorySlotUI

		if view == null:
			continue

		# Удаляем прежний обработчик выбора:
		# во время открытого окна нужен перенос предметов.
		for connection: Dictionary in (
			view.slot_pressed.get_connections()
		):
			view.slot_pressed.disconnect(
				connection["callable"]
			)

		view.slot_pressed.connect(_on_hotbar_pressed)

		var hover_callback := Callable(
			ui,
			"_on_inventory_hover"
		)

		if not view.slot_hovered.is_connected(
			hover_callback
		):
			view.slot_hovered.connect(hover_callback)

		var number := _make_hud_label(str(i + 1))
		number.custom_minimum_size = Vector2(
			view.get_combined_minimum_size().x,
			18
		)
		numbers.add_child(number)

	var separator := VSeparator.new()
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(separator)

	# Правая группа имеет такой же заголовок и отступы:
	# сами ячейки совпадают по высоте с быстрыми ячейками.
	var food_column := VBoxContainer.new()
	food_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	food_column.add_theme_constant_override("separation", 3)
	row.add_child(food_column)

	food_column.add_child(
		_make_hud_label("ЕДА · АВТОПОТРЕБЛЕНИЕ")
	)

	food_grid = HBoxContainer.new()
	food_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	food_grid.add_theme_constant_override("separation", 6)
	food_column.add_child(food_grid)

	var scene: PackedScene = (
		ui.get("slot_scene") as PackedScene
	)

	for i in range(3):
		var column := VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_theme_constant_override("separation", 3)
		food_grid.add_child(column)

		var view := scene.instantiate() as InventorySlotUI
		view.setup(FIRST_FOOD_SLOT + i)
		column.add_child(view)

		view.slot_pressed.connect(_on_food_pressed)
		view.slot_hovered.connect(
			Callable(ui, "_on_inventory_hover")
		)
		view.gui_input.connect(
			_on_manual_food_input.bind(
				FIRST_FOOD_SLOT + i
			)
		)

		food_views.append(view)

		var timer := _make_hud_label("Пусто")
		timer.custom_minimum_size.y = 18
		column.add_child(timer)
		food_labels.append(timer)

	# Название выбранного предмета — отдельной строкой,
	# ниже ячеек, номеров и таймеров.
	var selected: Label = (
		ui.get("selected_label") as Label
	)

	if selected != null:
		selected.reparent(bottom_box)
		selected.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_CENTER
		)
		selected.add_theme_font_size_override(
			"font_size",
			12
		)
		selected.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)
		selected.autowrap_mode = (
			TextServer.AUTOWRAP_WORD_SMART
		)

	if old_vbox != null:
		old_vbox.hide()

	var old_hud: Control = (
		ui.get_node_or_null("HotbarHUD") as Control
	)

	if old_hud != null:
		old_hud.hide()

	# Вес создаётся здесь, затем переносится в шапку окна инвентаря.
	compact_weight = VBoxContainer.new()
	compact_weight.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	compact_weight.add_theme_constant_override(
		"separation",
		2
	)
	compact_weight.custom_minimum_size = Vector2(240, 0)
	compact_weight.position = Vector2(12, 12)
	hud_root.add_child(compact_weight)

	var weight_label: Label = (
		ui.get("weight_label") as Label
	)
	var weight_bar: ProgressBar = (
		ui.get("weight_bar") as ProgressBar
	)

	if weight_label != null:
		weight_label.reparent(compact_weight)
		weight_label.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_LEFT
		)
		weight_label.add_theme_font_size_override(
			"font_size",
			12
		)
		weight_label.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)

	if weight_bar != null:
		weight_bar.reparent(compact_weight)
		weight_bar.custom_minimum_size = Vector2(240, 8)
		weight_bar.show_percentage = false
		weight_bar.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)

	# Убираем заданную в сцене большую высоту окна.
	# Размер теперь определяется содержимым.
	compact_window = (
		ui.get("inventory_window") as Control
	)

	if compact_window != null:
		compact_window.custom_minimum_size = Vector2.ZERO

		var content := compact_window.get_node_or_null(
			"Margin/Main/Content"
		) as Control

		if content != null:
			content.size_flags_vertical = (
				Control.SIZE_FILL
			)

		# Обычный Control не навязывает окну размеры,
		# в отличие от прежнего CenterContainer.
		window_area = Control.new()
		window_area.name = "CompactInventoryArea"
		window_area.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)

		var overlay: Control = (
			ui.get("overlay") as Control
		)
		overlay.add_child(window_area)

		window_area.set_anchors_and_offsets_preset(
			Control.PRESET_FULL_RECT
		)

		compact_window.reparent(window_area)
		compact_window.set_anchors_and_offsets_preset(
			Control.PRESET_TOP_LEFT
		)
		_mount_inventory_weight()
		_cleanup_inventory_visuals()

	# Переносимый стак рисуется поверх обеих групп.
	var preview: Control = (
		ui.get("carry_preview") as Control
	)

	if preview != null:
		preview.reparent(hud_layer)
		_mouse_ignore_recursive(preview)

	call_deferred("_layout_compact_hud")

func _mouse_ignore_recursive(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_mouse_ignore_recursive(child)

func _hide_hotbar_titles(parent: Node) -> void:
	if parent == null:
		return
	for child in parent.get_children():
		if child is Label:
			var text := str(child.text).to_lower()
			if "быстр" in text or "hotbar" in text:
				child.hide()

func _hide_legacy_food(node: Node) -> void:
	if node == null:
		return

	for child: Node in node.get_children():
		var child_name: String = (
			str(child.name).to_lower()
		)

		if child is Control:
			if (
				"food" in child_name
				or "еда" in child_name
			):
				child.hide()
				continue

		if child is Label:
			var text: String = (
				str(child.text).strip_edges().to_lower()
			)

			if (
				text.begins_with("еда")
				or text.begins_with("питание")
				or text.begins_with("ячейки еды")
			):
				child.hide()
				continue

		_hide_legacy_food(child)

func _is_editing() -> bool:
	if bool(ui.call("is_inventory_open")):
		return true
	# Supports both original and updated GameplayInteractions windows.
	for node in get_tree().get_nodes_in_group("below_interaction_windows"):
		for info: Dictionary in node.get_property_list():
			if str(info.get("name", "")) == "overlay":
				var overlay: Control = node.get("overlay") as Control
				if overlay != null and overlay.visible:
					return true
	var carried: ItemStack = ui.get("carried") as ItemStack
	return carried != null and not carried.is_empty()

func _on_hotbar_pressed(index: int, button: MouseButton) -> void:
	if _is_dead() or get_tree().paused:
		return
	if _is_editing():
		ui.call("_on_inventory_slot_pressed", index, button)
	elif button == MOUSE_BUTTON_LEFT:
		ui.call("set_selected_hotbar", index - 27)

func _on_food_pressed(
		index: int,
		button: MouseButton
) -> void:
	if (
		not _is_editing()
		or _is_dead()
		or get_tree().paused
	):
		return

	if (
		button != MOUSE_BUTTON_LEFT
		and button != MOUSE_BUTTON_RIGHT
	):
		return

	var carried: ItemStack = (
		ui.get("carried") as ItemStack
	)

	if carried == null:
		return

	if not carried.is_empty():
		if carried.item_id not in FOOD_IDS:
			return

		var lane: int = index - FIRST_FOOD_SLOT

		if not _food_allowed(lane, carried.item_id):
			return

	var target: ItemStack = inventory.get_slot(index)

	var take := func(amount: int):
		ui.set(
			"carried",
			inventory.take_from_slot(index, amount)
		)

	ui.call(
		"_handle_stack_click",
		target,
		button,
		Callable(inventory, "notify_changed"),
		take
	)

	_refresh_food()

func _bind_manual_use() -> void:
	for field in ["inventory_views", "hotbar_views", "inventory_hotbar_views"]:
		var views: Variant = ui.get(field)
		if views is Array:
			for view in views:
				if view is InventorySlotUI and not view.has_meta("below_manual_food_bound"):
					view.set_meta("below_manual_food_bound", true)
					view.gui_input.connect(_on_manual_food_input.bind(view.slot_index))

func _on_manual_food_input(event: InputEvent, index: int) -> void:
	var mouse := event as InputEventMouseButton
	if mouse == null or not mouse.pressed or mouse.button_index != MOUSE_BUTTON_MIDDLE:
		return
	if _is_editing() and not _is_dead() and not get_tree().paused:
		consume_from_slot(index, false)
		get_viewport().set_input_as_handled()

func _is_dead() -> bool:
	if not is_instance_valid(player):
		return true
	for info: Dictionary in player.get_property_list():
		if str(info.get("name", "")) == "is_dead":
			return bool(player.get("is_dead"))
	return false

func _process(delta: float) -> void:
	if not initialized or not is_instance_valid(player):
		return
	
	_layout_compact_hud()
	
	if _is_dead():
		if not effects.is_empty():
			_clear_effects()
		return
	for i in range(effects.size() - 1, -1, -1):
		effects[i]["remaining"] = float(effects[i]["remaining"]) - delta
		if float(effects[i]["remaining"]) <= 0.0:
			_remove_effect(i)
	for i in range(3):
		consume_from_slot(FIRST_FOOD_SLOT + i, true)
	refresh_elapsed += delta
	if refresh_elapsed >= 0.2:
		refresh_elapsed = 0.0
		_bind_manual_use()
		_cleanup_inventory_visuals()
		_refresh_food()

func consume_from_slot(index: int, automatic: bool = false) -> bool:
	if not initialized or _is_dead() or get_tree().paused:
		return false
	var stack: ItemStack = inventory.get_slot(index)
	if stack == null or stack.is_empty() or stack.item_id not in FOOD_IDS:
		return false
	if hp_property == &"" or stamina_property == &"":
		return false
	var existing := -1
	for i in range(effects.size()):
		if StringName(effects[i]["item_id"]) == stack.item_id:
			existing = i
			break
	if existing >= 0:
		# Automatic refill only at expiry; manual refill after half the duration.
		if automatic or float(effects[existing]["remaining"]) > FOOD_DURATION * 0.5:
			return false
	elif effects.size() >= 3:
		return false
	var id: StringName = stack.item_id
	var lane := index - FIRST_FOOD_SLOT if index >= FIRST_FOOD_SLOT else -1
	if existing >= 0:
		if lane < 0:
			lane = int(effects[existing]["lane"])
		_remove_effect(existing)
	var occupied: Array[int] = []
	for effect in effects:
		occupied.append(int(effect["lane"]))
	if lane < 0 or lane > 2 or lane in occupied:
		for i in range(3):
			if i not in occupied:
				lane = i
				break
	var hp := 5 if id == &"raw_meat" else 10
	var stamina := 0.0 if id == &"raw_meat" else 5.0
	stack.amount -= 1
	if stack.amount <= 0:
		stack.clear()
	effects.append({"item_id": id, "remaining": FOOD_DURATION, "hp": hp, "stamina": stamina, "lane": lane})
	_change_stat(hp_property, hp)
	_change_stat(stamina_property, stamina)
	_emit_stats()
	inventory.notify_changed()
	_refresh_food()
	return true

func _change_stat(property_name: StringName, difference: float) -> void:
	var previous: Variant = player.get(property_name)
	var next := maxf(1.0, float(previous) + difference)
	player.set(property_name, int(round(next)) if typeof(previous) == TYPE_INT else next)

func _remove_effect(index: int) -> void:
	var effect: Dictionary = effects[index]
	_change_stat(hp_property, -float(effect["hp"]))
	_change_stat(stamina_property, -float(effect["stamina"]))
	effects.remove_at(index)
	var health_name := _find_property([&"current_health", &"health"])
	var stamina_name := _find_property([&"current_stamina", &"stamina"])
	if health_name != &"":
		var health: Variant = player.get(health_name)
		var next_health := minf(float(health), float(player.get(hp_property)))
		player.set(health_name, int(next_health) if typeof(health) == TYPE_INT else next_health)
	if stamina_name != &"":
		player.set(stamina_name, minf(float(player.get(stamina_name)), float(player.get(stamina_property))))
	_emit_stats()

func _emit_stats() -> void:
	var health_name := _find_property([&"current_health", &"health"])
	var stamina_name := _find_property([&"current_stamina", &"stamina"])
	if player.has_signal("health_changed") and health_name != &"":
		player.emit_signal("health_changed", player.get(health_name), player.get(hp_property))
	if player.has_signal("stamina_changed") and stamina_name != &"":
		player.emit_signal("stamina_changed", player.get(stamina_name), player.get(stamina_property))

func _clear_effects() -> void:
	while not effects.is_empty():
		_remove_effect(effects.size() - 1)
	_refresh_food()

func _refresh_food() -> void:
	if inventory == null or food_views.size() != 3:
		return
	for i in range(3):
		var stack: ItemStack = inventory.get_slot(FIRST_FOOD_SLOT + i)
		var effect: Dictionary = {}
		for candidate in effects:
			if not stack.is_empty() and StringName(candidate["item_id"]) == stack.item_id:
				effect = candidate
				break
		if effect.is_empty():
			for candidate in effects:
				if int(candidate["lane"]) == i:
					effect = candidate
					break
		food_views[i].display_stack(stack)
		food_views[i].modulate = Color.WHITE
		if stack.is_empty() and not effect.is_empty():
			var consumed := ItemStack.new()
			consumed.set_item(StringName(effect["item_id"]), 1)
			food_views[i].display_stack(consumed)
			food_views[i].modulate = Color(1, 1, 1, 0.55)
			food_views[i].tooltip_text += "\nУже съедено: здесь показан активный эффект, а не предмет."
		food_views[i].tooltip_text += "\nТолько еда. ЛКМ — стак, ПКМ — одна единица.\nАвтоматически расходуется одна порция при отсутствии эффекта."
		if effect.is_empty():
			food_labels[i].text = "Пусто" if stack.is_empty() else "Ожидание"
		else:
			var seconds := maxi(0, ceili(float(effect["remaining"])))
			food_labels[i].text = "%02d:%02d" % [seconds / 60, seconds % 60]

func _exit_tree() -> void:
	# Avoid leaving bonuses on a surviving player when the interface is removed.
	if initialized and is_instance_valid(player):
		_clear_effects()

func _make_hud_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	label.add_theme_font_size_override("font_size", 12)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _layout_compact_hud() -> void:
	if bottom_box == null or bottom_dock == null:
		return

	var viewport_size: Vector2 = (
		get_viewport().get_visible_rect().size
	)

	var dock_size: Vector2 = (
		bottom_box.get_combined_minimum_size()
	)

	bottom_box.size = dock_size

	var dock_scale: float = minf(
		1.0,
		maxf(0.1, viewport_size.x - 24.0)
		/ maxf(1.0, dock_size.x)
	)

	bottom_dock.scale = Vector2(
		dock_scale,
		dock_scale
	)

	var visible_dock_size := dock_size * dock_scale

	bottom_dock.position = Vector2(
		(viewport_size.x - visible_dock_size.x) * 0.5,
		viewport_size.y - visible_dock_size.y - 12.0
	)

	if compact_weight != null:
		compact_weight.size = Vector2(
			240,
			compact_weight.get_combined_minimum_size().y
		)

	if compact_window == null:
		return

	# Снизу оставляем место для быстрого доступа и еды.
	var top := 12.0
	var bottom: float = (
		bottom_dock.position.y - 14.0
	)

	var available := Vector2(
		maxf(100.0, viewport_size.x - 24.0),
		maxf(80.0, bottom - top)
	)

	var natural: Vector2 = (
		compact_window.get_combined_minimum_size()
	)

	compact_window.size = natural

	var window_scale: float = minf(
		1.0,
		minf(
			available.x / maxf(1.0, natural.x),
			available.y / maxf(1.0, natural.y)
		)
	)

	compact_window.scale = Vector2(
		window_scale,
		window_scale
	)

	var displayed := natural * window_scale

	compact_window.position = Vector2(
		(viewport_size.x - displayed.x) * 0.5,
		top + (available.y - displayed.y) * 0.5
	)
	
func _food_allowed(
		lane: int,
		item_id: StringName
) -> bool:
	if lane < 0 or lane >= 3:
		return false

	# Одинаковый запас нельзя держать
	# в разных ячейках автопотребления.
	for i in range(3):
		if i == lane:
			continue

		var stack: ItemStack = inventory.get_slot(
			FIRST_FOOD_SLOT + i
		)

		if (
			stack != null
			and not stack.is_empty()
			and stack.item_id == item_id
		):
			return false

	# Съеденная последняя порция продолжает занимать
	# ячейку своим активным эффектом.
	for effect: Dictionary in effects:
		var effect_id := StringName(effect["item_id"])
		var effect_lane := int(effect["lane"])

		if effect_id == item_id and effect_lane != lane:
			return false

		# Нельзя заменить действующий эффект другим
		# блюдом в этой же ячейке.
		if effect_lane == lane and effect_id != item_id:
			return false

	return true
	
func _normalize_food_stocks() -> void:
	var changed := false

	for i in range(3):
		var stack: ItemStack = inventory.get_slot(
			FIRST_FOOD_SLOT + i
		)

		if stack == null or stack.is_empty():
			continue

		var first := -1

		for j in range(i):
			var previous: ItemStack = inventory.get_slot(
				FIRST_FOOD_SLOT + j
			)

			if (
				previous != null
				and not previous.is_empty()
				and previous.item_id == stack.item_id
			):
				first = j
				break

		if first < 0:
			continue

		var previous: ItemStack = inventory.get_slot(
			FIRST_FOOD_SLOT + first
		)
		var item: ItemData = ItemRegistry.get_item(
			stack.item_id
		)

		# Сначала дополняем первую ячейку этого блюда.
		if item != null:
			var merged: int = mini(
				stack.amount,
				maxi(0, item.max_stack - previous.amount)
			)

			previous.amount += merged
			stack.amount -= merged

		# Затем возвращаем оставшееся в рюкзак.
		if stack.amount > 0:
			var returned: int = inventory.add_item(
				stack.item_id,
				stack.amount
			)
			stack.amount -= returned

		# При полном рюкзаке используем существующий
		# механизм выпадения предметов.
		if (
			stack.amount > 0
			and ui.get("pickup_scene") != null
			and ui.has_method("_spawn_dropped")
		):
			ui.call(
				"_spawn_dropped",
				stack.item_id,
				stack.amount
			)
			stack.amount = 0

		if stack.amount <= 0:
			stack.clear()
		else:
			# Если выпадение не настроено, остаток
			# сохраняется, а не уничтожается.
			push_warning(
				"Не удалось убрать повтор еды: "
				+ "освободите место в рюкзаке."
			)

		changed = true

	if changed:
		inventory.notify_changed()

# UI-only cleanup. No inventory items or active food effects are deleted.
func _mount_inventory_weight() -> void:
	if compact_window == null or compact_weight == null:
		return
	var main := compact_window.get_node_or_null("Margin/Main") as VBoxContainer
	if main == null:
		# Fallback for a differently named scene hierarchy.
		compact_weight.reparent(compact_window, false)
		compact_weight.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		compact_weight.position = Vector2(20, 16)
		return

	var title: Label = null
	for child: Node in main.get_children():
		if child is Label and str(child.text).strip_edges().to_upper() == "ИНВЕНТАРЬ":
			title = child as Label
			break

	var header := HBoxContainer.new()
	header.name = "CompactInventoryHeader"
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 8)
	main.add_child(header)
	main.move_child(header, 0)
	compact_weight.reparent(header, false)
	compact_weight.position = Vector2.ZERO
	compact_weight.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	compact_weight.custom_minimum_size = Vector2(240, 0)
	if title != null:
		title.reparent(header, false)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var balance := Control.new()
		balance.custom_minimum_size.x = 240
		balance.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_child(balance)
	else:
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_child(spacer)


func _cleanup_inventory_visuals() -> void:
	if compact_window == null:
		return
	_hide_legacy_food(compact_window)
	_hide_old_food_rows(compact_window)
	_hide_crossed_recipe_text(compact_window)


func _collect_old_slot_views(node: Node, result: Array[InventorySlotUI]) -> void:
	if node is InventorySlotUI:
		result.append(node as InventorySlotUI)
		return
	for child: Node in node.get_children():
		_collect_old_slot_views(child, result)


func _has_food_timer(node: Node) -> bool:
	if node is Label:
		var text: String = str(node.text).strip_edges().to_lower()
		if text == "пусто" or text == "пустая ячейка":
			return true
		var parts := text.split(":")
		if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
			return true
	for child: Node in node.get_children():
		if _has_food_timer(child):
			return true
	return false


func _hide_old_food_rows(node: Node) -> void:
	# The bottom auto-consumption panel is outside compact_window and
	# therefore never enters this traversal.
	if node is Container and node != compact_window:
		var views: Array[InventorySlotUI] = []
		_collect_old_slot_views(node, views)
		if views.size() == 3 and _has_food_timer(node):
			(node as Control).hide()
			return
	# Some previous InventoryUI versions create anonymous food controls.
	# Detect their slot indices in addition to the named Food containers.
	if node is InventorySlotUI:
		var view := node as InventorySlotUI
		if view.slot_index >= FIRST_FOOD_SLOT and view.slot_index < FIRST_FOOD_SLOT + 3:
			view.hide()
		return
	for child: Node in node.get_children():
		_hide_old_food_rows(child)


func _hide_crossed_recipe_text(node: Node) -> void:
	if node is Label or node is RichTextLabel:
		var text: String = str(node.get("text")).strip_edges().to_lower().replace("ё", "е")
		# Hide the crossed-out campfire recipe/ingredient list only.
		# Keep the crafting title, arrow, slots and mouse/keyboard help.
		if ("костер" in text and ("кремень" in text or "доск" in text)) or text in ["костер", "костер:", "кремень", "доски ×3", "доски x3", "доски х3"]:
			(node as Control).hide()
	for child: Node in node.get_children():
		_hide_crossed_recipe_text(child)
