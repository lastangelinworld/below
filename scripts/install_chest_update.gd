@tool
extends EditorScript

# Откройте этот файл в Script Editor и выполните File -> Run (Ctrl+Shift+X).
# Меняется актуальный player.gd, а не старая копия из архива.
const HELPER: String = "\n\n# BELOW_CHEST_MINING_V1\nfunc _below_try_damage_chest() -> bool:\n\tif terrain == null or terrain.tile_set == null:\n\t\treturn false\n\tvar cells: Array[Vector2i] = _get_attack_mining_cells()\n\t# Непроходимая коллизия сундуку не нужна: ищем его по группе.\n\tfor candidate: Node in get_tree().get_nodes_in_group(\"storage_chest\"):\n\t\tif not candidate is Node2D or candidate.is_queued_for_deletion():\n\t\t\tcontinue\n\t\tif not candidate.has_method(\"receive_structure_damage\"):\n\t\t\tcontinue\n\t\tvar chest: Node2D = candidate as Node2D\n\t\tvar chest_cell: Vector2i = terrain.global_position_to_cell(chest.global_position)\n\t\tfor cell: Vector2i in cells:\n\t\t\tif not is_cell_mineable(cell):\n\t\t\t\tcontinue\n\t\t\tvar center: Vector2 = terrain.to_global(terrain.map_to_local(cell))\n\t\t\tvar local_center: Vector2 = chest.to_local(center)\n\t\t\tif cell == chest_cell or Rect2(-16.0, -28.0, 32.0, 28.0).has_point(local_center):\n\t\t\t\t# Отладочное уничтожение блоков с одного удара здесь НЕ действует.\n\t\t\t\tchest.call(\"receive_structure_damage\", maxi(1, mining_damage))\n\t\t\t\t# Удар в сундук не повреждает одновременно его опору.\n\t\t\t\treturn true\n\treturn false\n"

func _run() -> void:
	var candidates: Array[String] = []
	_scan("res://", candidates)
	if candidates.is_empty():
		push_error("Не найден скрипт игрока с _on_pickaxe_hit и _get_attack_mining_cells. Ничего не изменено.")
		return
	# Если копий несколько, приоритет — скрипту открытой сцены игрока.
	var chosen: String = ""
	if candidates.size() == 1:
		chosen = candidates[0]
	else:
		var root: Node = get_editor_interface().get_edited_scene_root()
		if root != null:
			chosen = _find_attached_script(root, candidates)
		if chosen.is_empty():
			push_error("Найдено несколько скриптов игрока: " + str(candidates) + ". Откройте сцену нужного игрока и запустите установщик снова.")
			return
	var source: String = FileAccess.get_file_as_string(chosen)
	if source.contains("# BELOW_CHEST_MINING_V1"):
		print("Подключение сундука уже установлено: ", chosen)
		return
	var anchor: String = "func _on_pickaxe_hit() -> void:\n"
	if source.count(anchor) != 1 or source.contains("func _below_try_damage_chest("):
		push_error("Неожиданная структура скрипта игрока. Файл не изменён: " + chosen)
		return
	var backup: String = chosen + ".before_chest_update.bak"
	if not FileAccess.file_exists(backup):
		var backup_file: FileAccess = FileAccess.open(backup, FileAccess.WRITE)
		if backup_file == null:
			push_error("Не удалось записать резервную копию. Установка отменена.")
			return
		backup_file.store_string(source)
		backup_file.close()
	var updated: String = source.replace(anchor, anchor + "\tif _below_try_damage_chest():\n\t\treturn\n".c_unescape()) + HELPER
	var file: FileAccess = FileAccess.open(chosen, FileAccess.WRITE)
	if file == null:
		push_error("Не удалось записать: " + chosen)
		return
	file.store_string(updated)
	file.close()
	get_editor_interface().get_resource_filesystem().scan()
	print("ГОТОВО: удары по сундуку подключены в ", chosen, ". Резервная копия: ", backup, ". Перезапустите редактор перед проверкой игры.")

func _scan(path: String, result: Array[String]) -> void:
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var name: String = directory.get_next()
	while not name.is_empty():
		if not name.begins_with("."):
			var full: String = path.path_join(name)
			if directory.current_is_dir():
				if name != "addons":
					_scan(full, result)
			elif name.ends_with(".gd") and not name.begins_with("install_"):
				var text: String = FileAccess.get_file_as_string(full)
				if text.contains("func _on_pickaxe_hit()") and text.contains("func _get_attack_mining_cells()"):
					result.append(full)
		name = directory.get_next()
	directory.list_dir_end()

func _find_attached_script(node: Node, candidates: Array[String]) -> String:
	var script: Script = node.get_script() as Script
	if script != null and candidates.has(script.resource_path):
		return script.resource_path
	for child: Node in node.get_children():
		var found: String = _find_attached_script(child, candidates)
		if not found.is_empty():
			return found
	return ""
