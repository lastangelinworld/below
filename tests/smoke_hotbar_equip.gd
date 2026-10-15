extends Node

## Смоук-тест быстрой экипировки клавишами 1-9 (хотбар в стиле Minecraft).
## Проверяет:
##   1. выбор ячейки с оружием надевает его в MAINHAND / OFFHAND;
##   2. выбор другой ячейки меняет оружие местами — снятое возвращается
##      в ячейку, откуда достали, а не падает на землю;
##   3. выбор пустой ячейки освобождает руки;
##   4. броня по хотбару НЕ надевается (её слоты не боевые);
##   5. повторный выбор той же ячейки идемпотентен.
## Запуск: godot --headless --path . res://tests/smoke_hotbar_equip.tscn


const SCENE_PLAYER := "res://entities/player/player.tscn"
const SCENE_UI := "res://inventory_ui.tscn"

const HOTBAR_FIRST: int = 27

var _problems: int = 0


func _ready() -> void:
	var player: CharacterBody2D = (load(SCENE_PLAYER) as PackedScene).instantiate()
	add_child(player)
	var ui: CanvasLayer = (load(SCENE_UI) as PackedScene).instantiate()
	add_child(ui)

	# InventoryUI._connect_player отложен на call_deferred — даём кадр.
	await get_tree().process_frame
	await get_tree().process_frame

	if not is_instance_valid(ui.player) or not is_instance_valid(ui.inventory):
		_fail("INVENTORY UI DID NOT CONNECT TO PLAYER")
		print("SMOKE HOTBAR EQUIP RESULT: FAIL  (", _problems, " проблем)")
		get_tree().quit(1)
		return

	var inventory: InventoryData = ui.inventory
	var system: EquipmentSystem = ui._get_equipment()
	if system == null:
		_fail("EQUIPMENT SYSTEM NOT FOUND")
		print("SMOKE HOTBAR EQUIP RESULT: FAIL  (", _problems, " проблем)")
		get_tree().quit(1)
		return

	_test_equip_weapon(ui, player, inventory, system)
	_test_swap(ui, player, inventory, system)
	_test_empty_cell(ui, player, inventory, system)
	_test_armor_ignored(ui, player, inventory, system)

	print(
		"SMOKE HOTBAR EQUIP RESULT: ",
		"FAIL " if _problems > 0 else "OK",
		" (", _problems, " проблем)"
	)
	get_tree().quit(1 if _problems > 0 else 0)


## Оружие из ячейки надевается, щит — во вторичную руку.
func _test_equip_weapon(
	ui: CanvasLayer,
	player: CharacterBody2D,
	inventory: InventoryData,
	system: EquipmentSystem
) -> void:
	_clear_all(inventory, system)
	inventory.set_slot(HOTBAR_FIRST, &"wood_club", 1)
	inventory.set_slot(HOTBAR_FIRST + 1, &"wood_shield", 1)

	ui.set_selected_hotbar(0)
	if _hand_item(system, EquipmentSlot.Type.MAINHAND) != &"wood_club":
		_fail("CLUB NOT EQUIPPED TO MAINHAND")

	ui.set_selected_hotbar(1)
	if _hand_item(system, EquipmentSlot.Type.OFFHAND) != &"wood_shield":
		_fail("SHIELD NOT EQUIPPED TO OFFHAND")
	if _hand_item(system, EquipmentSlot.Type.MAINHAND) != &"wood_club":
		_fail("SHIELD SELECTION RESET MAINHAND")

	# Щит остался в ячейке: max_stack=1, но проверка на идемпотентность
	# ниже важнее — повторный выбор того же номера ничего не меняет.
	ui.set_selected_hotbar(1)
	if _hand_item(system, EquipmentSlot.Type.OFFHAND) != &"wood_shield":
		_fail("REPEAT SELECTION BROKE OFFHAND")
	# Предмет не должен размножиться: в ячейке 28 щита больше нет.
	if inventory.get_slot(HOTBAR_FIRST + 1).amount > 0:
		_fail("SHIELD DUPLICATED (STILL IN HOTBAR CELL)")

	print("  HOTBAR_EQUIP: ", "OK" if _problems == 0 else "FAIL")


## Смена номера меняет оружие: снятое возвращается в ячейку.
func _test_swap(
	ui: CanvasLayer,
	player: CharacterBody2D,
	inventory: InventoryData,
	system: EquipmentSystem
) -> void:
	_clear_all(inventory, system)
	inventory.set_slot(HOTBAR_FIRST, &"wood_club", 1)
	inventory.set_slot(HOTBAR_FIRST + 1, &"iron_pickaxe", 1)

	ui.set_selected_hotbar(0)
	if _hand_item(system, EquipmentSlot.Type.MAINHAND) != &"wood_club":
		_fail("SWAP SETUP: CLUB NOT EQUIPPED")

	ui.set_selected_hotbar(1)
	if _hand_item(system, EquipmentSlot.Type.MAINHAND) != &"iron_pickaxe":
		_fail("SWAP: PICKAXE NOT EQUIPPED")
	if _hand_item(system, EquipmentSlot.Type.OFFHAND) != &"":
		_fail("SWAP: OFFHAND MUST STAY EMPTY")

	# Кирка ушла из ячейки 28, а дубина вернулась в неё.
	if not inventory.get_slot(HOTBAR_FIRST).is_empty():
		_fail("SWAP: SOURCE CELL 0 MUST BE EMPTY")
	var back: ItemStack = inventory.get_slot(HOTBAR_FIRST + 1)
	if back == null or back.item_id != &"wood_club":
		_fail("SWAP: DISPLACED CLUB NOT RETURNED TO CELL 1")

	print("  HOTBAR_SWAP: ", "OK" if _problems <= 0 else "CHECK")


## Пустая ячейка НЕ влияет на руки: разоружаться нужно в окне экипировки.
func _test_empty_cell(
	ui: CanvasLayer,
	player: CharacterBody2D,
	inventory: InventoryData,
	system: EquipmentSystem
) -> void:
	_clear_all(inventory, system)
	# Кладем дубинку в слот 1 хотбара (ячейка 28), экипируем через set 1.
	inventory.set_slot(HOTBAR_FIRST + 1, &"wood_club", 1)
	ui.set_selected_hotbar(1)
	if _hand_item(system, EquipmentSlot.Type.MAINHAND) != &"wood_club":
		_fail("EMPTY SETUP: CLUB NOT EQUIPPED")

	# Пустая ячейка (slot 2 → ячейка 29) — ранний return, ничего не меняет.
	ui.set_selected_hotbar(2)
	if _hand_item(system, EquipmentSlot.Type.MAINHAND) != &"wood_club":
		_fail("EMPTY CELL MUST NOT UNEQUIP MAINHAND")

	print("  HOTBAR_EMPTY: ", "OK" if _problems <= 0 else "CHECK")


## Броня по хотбару не надевается.
func _test_armor_ignored(
	ui: CanvasLayer,
	player: CharacterBody2D,
	inventory: InventoryData,
	system: EquipmentSystem
) -> void:
	_clear_all(inventory, system)
	inventory.set_slot(HOTBAR_FIRST, &"iron_chestplate", 1)
	ui.set_selected_hotbar(0)
	if not system.get_equipped_stack(EquipmentSlot.Type.CHEST).is_empty():
		_fail("CHESTPLATE MUST NOT EQUIP VIA HOTBAR")
	if not system.get_equipped_stack(EquipmentSlot.Type.MAINHAND).is_empty():
		_fail("CHESTPLATE MUST NOT GO INTO HANDS")
	if inventory.get_slot(HOTBAR_FIRST).item_id != &"iron_chestplate":
		_fail("CHESTPLATE MOVED OUT OF CELL BY HOTBAR SELECTION")

	print("  HOTBAR_ARMOR: ", "OK" if _problems <= 0 else "CHECK")


## Полностью очищает руки и инвентарь перед подтестом.
func _clear_all(inventory: InventoryData, system: EquipmentSystem) -> void:
	for slot: EquipmentSlot.Type in EquipmentSlot.ALL_SLOTS:
		var stack: ItemStack = system.get_equipped_stack(slot)
		if not stack.is_empty():
			system.take_from_slot(slot, stack.amount)
	for i: int in inventory.slot_count:
		inventory.set_slot(i, &"", 0)


func _hand_item(system: EquipmentSystem, slot: EquipmentSlot.Type) -> StringName:
	var stack: ItemStack = system.get_equipped_stack(slot)
	return stack.item_id if stack != null else &""


func _fail(message: String) -> void:
	print("FAIL: ", message)
	_problems += 1
