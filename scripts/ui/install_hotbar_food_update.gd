@tool
extends EditorScript
## Execute once from Godot Script Editor: File -> Run (Ctrl+Shift+X).
const CONTROLLER_PATH := "res://scripts/ui/hotbar_food_controller.gd"
const MARKER := "# below_unified_hud_v1"
const NEW_CAPACITY := """func get_addable_amount(item_id: StringName, requested_amount: int) -> int:
	if requested_amount <= 0:
		return 0
	var item: ItemData = ItemRegistry.get_item(item_id)
	if item == null:
		push_warning("Предмет не зарегистрирован: %s" % item_id)
		return 0
	var capacity := 0
	for slot_index in range(mini(36, slots.size())):
		var stack: ItemStack = get_slot(slot_index)
		if stack == null or stack.is_empty():
			capacity += item.max_stack
		elif stack.item_id == item_id:
			capacity += maxi(item.max_stack - stack.amount, 0)
	capacity = mini(capacity, requested_amount)
	if item.unit_weight_kg > 0.0:
		capacity = mini(capacity, floori(get_free_weight_kg() / item.unit_weight_kg))
	return maxi(capacity, 0)
"""
const NEW_ADD := """func add_item(item_id: StringName, amount: int) -> int:
	var accepted := get_addable_amount(item_id, amount)
	if accepted <= 0:
		return 0
	var item: ItemData = ItemRegistry.get_item(item_id)
	if item == null:
		return 0
	var remaining := accepted
	for slot_index in range(mini(36, slots.size())):
		var stack: ItemStack = get_slot(slot_index)
		if remaining <= 0:
			break
		if stack == null or stack.is_empty() or stack.item_id != item_id:
			continue
		var portion := mini(maxi(item.max_stack - stack.amount, 0), remaining)
		stack.amount += portion
		remaining -= portion
	for i in range(mini(36, slots.size())):
		if remaining <= 0:
			break
		var stack := get_slot(i)
		if not stack.is_empty():
			continue
		var portion := mini(item.max_stack, remaining)
		stack.item_id = item_id
		stack.amount = portion
		remaining -= portion
	emit_changed()
	return accepted - remaining
"""
const NEW_SETUP := """func setup(new_slot_count: int = -1, clear_existing: bool = true) -> void:
	if new_slot_count > 0:
		slot_count = new_slot_count
	slot_count = maxi(slot_count, 39)
	if clear_existing:
		slots.clear()
	while slots.size() < slot_count:
		slots.append(ItemStack.new())
	while slots.size() > slot_count:
		slots.pop_back()
	for i in range(slots.size()):
		if slots[i] == null:
			slots[i] = ItemStack.new()
	emit_changed()
"""
const NEW_FOOD_HOOK := """func below_consume_food_from_slot(slot_index: int) -> bool:
	var system: Node = get_tree().get_first_node_in_group("below_food_runtime")
	if system == null or not system.has_method("consume_from_slot"):
		return false
	return bool(system.call("consume_from_slot", slot_index, false))
"""

func _run() -> void:
	if not FileAccess.file_exists(CONTROLLER_PATH):
		push_error("Сначала скопируйте hotbar_food_controller.gd в " + CONTROLLER_PATH)
		return
	var paths: Array[String] = []
	_collect("res://", paths)
	var changes: Dictionary = {}
	var found_ui := 0
	var found_data := 0
	var found_player := 0
	var found_interactions := 0
	for path in paths:
		if path == get_script().resource_path or path == CONTROLLER_PATH:
			continue
		var original := FileAccess.get_file_as_string(path)
		var source := original
		if _has_class(source, "InventoryUI"):
			found_ui += 1
			var required := ["_ready", "_handle_stack_click", "_on_inventory_slot_pressed", "_on_inventory_hover", "is_inventory_open"]
			for method in required:
				if not _has_function(source, method):
					push_error("Установка отменена: " + path + " не содержит " + method)
					return
			for field in ["inventory_hotbar_grid", "hotbar_grid", "slot_scene", "carry_preview", "inventory_window"]:
				if field not in source:
					push_error("Установка отменена: неподдерживаемая структура InventoryUI: " + field)
					return
			source = _remove_window_pause(source)
			if MARKER not in source:
				source = _append_to_ready(source, "\t" + MARKER + "\n\tcall_deferred(\"_below_install_unified_hud\")\n")
				source += "\n\nfunc _below_install_unified_hud() -> void:\n\tif has_node(\"UnifiedHotbarFoodController\"):\n\t\treturn\n\tvar helper_script: Script = load(\"" + CONTROLLER_PATH + "\") as Script\n\tvar helper: Node = helper_script.new()\n\thelper.name = \"UnifiedHotbarFoodController\"\n\tadd_child(helper)\n"
		if _has_class(source, "InventoryData"):
			found_data += 1
			for method in ["setup", "get_addable_amount", "add_item"]:
				if not _has_function(source, method):
					push_error("Установка отменена: в InventoryData отсутствует " + method)
					return
			source = _replace_function(source, "setup", NEW_SETUP)
			source = _replace_function(source, "get_addable_amount", NEW_CAPACITY)
			source = _replace_function(source, "add_item", NEW_ADD)
		if _has_class(source, "GameplayInteractions"):
			found_interactions += 1
			source = _remove_window_pause(source)
			if "below_interaction_windows" not in source:
				source = _append_to_ready(source, "\tadd_to_group(\"below_interaction_windows\")\n")
		if _has_function(source, "below_consume_food_from_slot") and not _has_class(source, "InventoryUI"):
			found_player += 1
			source = _replace_function(source, "below_consume_food_from_slot", NEW_FOOD_HOOK)
		if source != original:
			changes[path] = source
	if found_ui != 1 or found_data != 1 or found_player != 1:
		push_error("Установка отменена. Нужен один InventoryUI, один InventoryData и один скрипт игрока с below_consume_food_from_slot. Найдено: %d / %d / %d" % [found_ui, found_data, found_player])
		return
	# Preflight is complete. Save ORIGINAL backups before modifying any source.
	for path: String in changes:
		var backup_path := path + ".before_unified_hud.bak"
		if not FileAccess.file_exists(backup_path):
			var backup := FileAccess.open(backup_path, FileAccess.WRITE)
			if backup == null:
				push_error("Не удалось сохранить резервную копию: " + backup_path)
				return
			backup.store_string(FileAccess.get_file_as_string(path))
			backup.close()
	for path: String in changes:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			push_error("Не удалось записать " + path + ". Восстановите .bak для уже изменённых файлов.")
			return
		file.store_string(str(changes[path]))
		file.close()
		print("Обновлено: ", path)
	get_editor_interface().get_resource_filesystem().scan()
	print("Готово. Закройте и снова откройте проект, затем запустите игру. Изменено файлов: ", changes.size())
	if found_interactions == 0:
		push_warning("GameplayInteractions не найден: пауза других окон не изменена. Проверьте их скрипты отдельно.")

func _collect(directory: String, result: Array[String]) -> void:
	var dir := DirAccess.open(directory)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if not name.begins_with("."):
			var path := directory.path_join(name)
			if dir.current_is_dir():
				_collect(path, result)
			elif name.ends_with(".gd"):
				result.append(path)
		name = dir.get_next()
	dir.list_dir_end()

func _has_class(source: String, class_name_text: String) -> bool:
	var pattern := RegEx.new()
	pattern.compile("(?m)^class_name[ \\t]+" + class_name_text + "(?:[ \\t]*$|[ \\t]+extends)")
	return pattern.search(source) != null

func _has_function(source: String, method: String) -> bool:
	return ("\nfunc " + method + "(") in ("\n" + source)

func _replace_function(source: String, method: String, replacement: String) -> String:
	var lines := source.split("\n")
	var start := -1
	var finish := lines.size()
	for i in range(lines.size()):
		if lines[i].begins_with("func " + method + "("):
			start = i
		elif start >= 0 and lines[i].begins_with("func "):
			finish = i
			break
	if start < 0:
		return source
	var output := ""
	for i in range(start):
		output += lines[i] + "\n"
	output += replacement.strip_edges() + "\n\n"
	for i in range(finish, lines.size()):
		output += lines[i]
		if i < lines.size() - 1:
			output += "\n"
	return output

func _append_to_ready(source: String, addition: String) -> String:
	var lines := source.split("\n")
	var ready_started := false
	var finish := lines.size()
	for i in range(lines.size()):
		if lines[i].begins_with("func _ready("):
			ready_started = true
		elif ready_started and lines[i].begins_with("func "):
			finish = i
			break
	if not ready_started:
		return source
	# Insert before trailing blank/comment lines, not inside the next function.
	while finish > 0 and (lines[finish - 1].strip_edges().is_empty() or lines[finish - 1].begins_with("#")):
		finish -= 1
	lines.insert(finish, addition.trim_suffix("\n"))
	return "\n".join(lines)

func _remove_window_pause(source: String) -> String:
	var pattern := RegEx.new()
	pattern.compile("get_tree\\(\\)\\.paused[ \\t]*=[ \\t]*(?:true|false|_previous_pause|previous_pause)(?![A-Za-z0-9_])")
	# Replacing with pass works for both multiline and semicolon-separated code.
	return pattern.sub(source, "pass", true)
