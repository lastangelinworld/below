extends Node

## Смоук-тест поиза и стаггера (Фаза 4).
## Запуск: godot --headless --path . res://tests/smoke_poise.tscn


var _fake_time: float = 0.0


func _ready() -> void:
	var failures: int = 0
	failures += _test_stagger_threshold()
	failures += _test_regen_after_delay()
	failures += _test_parry_stagger_reuses_component()
	failures += _test_weapons_have_poise()
	failures += _test_equipment_totals_poise()
	failures += _test_encumbrance_calculation()
	failures += _test_overencumbered_restrictions()
	print("SMOKE POISE RESULT: ", "FAIL " if failures > 0 else "OK", " (", failures, " проблем)")
	get_tree().quit(1 if failures > 0 else 0)


func _now() -> float:
	return _fake_time


func _make_poise() -> PoiseComponent:
	var poise := PoiseComponent.new()
	add_child(poise)
	poise.configure(_now)
	poise.max_poise = 26.0
	poise.stagger_duration = 1.1
	poise.poise_regen_per_second = 9.0
	poise.recovery_delay = 2.0
	poise.restore_full()
	return poise


func _test_stagger_threshold() -> int:
	var problems := 0
	var poise := _make_poise()

	if poise.apply_damage(10.0):
		print("FAIL: STAGGER TOO EARLY AT 10 DMG")
		problems += 1
	if poise.is_staggered():
		print("FAIL: STAGGERED BEFORE POISE DEPLETED")
		problems += 1

	if not poise.apply_damage(20.0):
		print("FAIL: STAGGER NOT TRIGGERED ON DEPLETED POISE")
		problems += 1
	if not poise.is_staggered():
		print("FAIL: IS_STAGGERED FALSE AFTER TRIGGER")
		problems += 1
	if poise.current_poise > 0.0:
		print("FAIL: POISE NOT CLAMPED TO ZERO")
		problems += 1

	_fake_time = 0.0
	var ended_early: bool = false
	for step: int in range(10):
		if poise.tick(0.1):
			ended_early = true
	if ended_early:
		print("FAIL: STAGGER ENDED BEFORE ITS DURATION")
		problems += 1
	if not is_equal_approx(poise.current_poise, 0.0):
		print("FAIL: POISE REGEN DURING STAGGER")
		problems += 1

	if not poise.tick(0.5):
		print("FAIL: STAGGER END NOT REPORTED")
		problems += 1
	if poise.is_staggered():
		print("FAIL: STILL STAGGERED AFTER END")
		problems += 1

	print("  STAGGER_THRESHOLD: OK" if problems == 0 else "  STAGGER_THRESHOLD: FAIL")
	return problems


func _test_regen_after_delay() -> int:
	var problems := 0
	var poise := _make_poise()
	poise.apply_damage(20.0)
	var damaged_poise: float = poise.current_poise

	_fake_time = 0.0
	poise.tick(1.0)
	if not is_equal_approx(poise.current_poise, damaged_poise):
		print("FAIL: POISE REGEN BEFORE RECOVERY DELAY")
		problems += 1

	_fake_time = 5.0
	for step: int in range(60):
		poise.tick(0.1)
	if not is_equal_approx(poise.current_poise, poise.max_poise):
		print("FAIL: POISE DID NOT FULLY RECOVER: ", poise.current_poise)
		problems += 1

	poise.apply_damage(1000.0)
	if poise.current_poise < 0.0:
		print("FAIL: NEGATIVE POISE")
		problems += 1

	print("  REGEN_AFTER_DELAY: OK" if problems == 0 else "  REGEN_AFTER_DELAY: FAIL")
	return problems


func _test_parry_stagger_reuses_component() -> int:
	var problems := 0

	var skeleton := Skeleton.new()
	add_child(skeleton)
	skeleton.apply_stagger(1.0)
	if not skeleton.is_staggered():
		print("FAIL: SKELETON STAGGER NOT APPLIED")
		problems += 1
	if not BackstabRules.is_staggered(skeleton):
		print("FAIL: SKELETON NOT OPEN FOR EXECUTION AFTER PARRY")
		problems += 1
	var multiplier: float = BackstabRules.multiplier(skeleton.global_position, skeleton)
	if not is_equal_approx(multiplier, BackstabRules.EXECUTION_MULTIPLIER):
		print("FAIL: EXECUTION MULTIPLIER WRONG: ", multiplier)
		problems += 1
	skeleton.free()

	print("  PARRY_STAGGER_REUSE: OK" if problems == 0 else "  PARRY_STAGGER_REUSE: FAIL")
	return problems


func _test_weapons_have_poise() -> int:
	var problems := 0
	var expected := {
		"iron_sword": 8.0,
		"wood_club": 6.0,
		"bone_pickaxe": 5.0,
		"iron_pickaxe": 6.0,
		"bone_greatclub": 12.0,
	}
	for id: String in expected.keys():
		var res: Resource = load("res://data/items/%s_item.tres" % id)
		var component: EquipmentComponent = res as EquipmentComponent
		if component == null:
			print("FAIL: NOT EQUIPMENT ", id)
			problems += 1
			continue
		if component.poise_damage <= 0.0:
			print("FAIL: WEAPON WITHOUT POISE DAMAGE ", id)
			problems += 1
		elif not is_equal_approx(component.poise_damage, float(expected[id])):
			print("FAIL: POISE DRIFT ", id, ": ", component.poise_damage, " != ", expected[id])
			problems += 1

	print("  WEAPONS_POISE: OK" if problems == 0 else "  WEAPONS_POISE: FAIL")
	return problems


func _test_equipment_totals_poise() -> int:
	var problems := 0

	var sword: EquipmentComponent = (
		load("res://data/items/iron_sword_item.tres") as EquipmentComponent
	)
	var shield: EquipmentComponent = (
		load("res://data/items/wood_shield_item.tres") as EquipmentComponent
	)
	if sword == null or shield == null:
		print("FAIL: WEAPON RESOURCES UNLOADABLE")
		return 1

	# ItemRegistry — autoload проекта (как в smoke_craft).
	ItemRegistry.register_item(sword)
	ItemRegistry.register_item(shield)

	var holder = preload("res://tests/poise_stat_holder.gd").new()
	add_child(holder)

	var system := EquipmentSystem.new()
	holder.add_child(system)
	system.setup(holder)

	var inventory := InventoryData.new()
	inventory.setup(9, true)
	inventory.set_slot(0, &"iron_sword", 1)

	if not system.equip_from_inventory(inventory, 0, EquipmentSlot.Type.MAINHAND):
		print("FAIL: CANNOT EQUIP SWORD")
		problems += 1
	else:
		var totals: Dictionary = system.get_totals()
		if not is_equal_approx(float(totals.get("poise_damage", 0.0)), 8.0):
			print("FAIL: TOTAL POISE WRONG: ", totals.get("poise_damage"))
			problems += 1
		if not is_equal_approx(float(holder.poise_damage), 8.0):
			print("FAIL: PLAYER POISE NOT APPLIED: ", holder.poise_damage)
			problems += 1

	if not system.unequip_to_inventory(inventory, EquipmentSlot.Type.MAINHAND):
		print("FAIL: CANNOT UNEQUIP SWORD")
		problems += 1
	elif not is_equal_approx(float(holder.poise_damage), 0.0):
		print("FAIL: PLAYER POISE NOT RESTORED: ", holder.poise_damage)
		problems += 1

	system.free()
	# inventory и holder — Resource/RefCounted, их нельзя free() через Node.free().

	print("  EQUIPMENT_POISE: OK" if problems == 0 else "  EQUIPMENT_POISE: FAIL")
	return problems


## Нагрузка: вес брони делится на грузоподъёмность,
## множитель скорости = 1 − encumbrance × 0.4.
func _test_encumbrance_calculation() -> int:
	var problems := 0

	var chest: EquipmentComponent = (
		load("res://data/items/iron_chestplate_item.tres") as EquipmentComponent
	)
	if chest == null or chest.unit_weight_kg != 8.0:
		print("FAIL: IRON CHESTPLATE WEIGHT")
		return 1

	ItemRegistry.register_item(chest)

	var holder = preload("res://tests/poise_stat_holder.gd").new()
	holder.equip_load_capacity_kg = 10.0

	var system = EquipmentSystem.new()
	holder.add_child(system)
	system.setup(holder)

	var inventory := InventoryData.new()
	inventory.setup(9, true)
	inventory.set_slot(0, &"iron_chestplate", 1)

	if not system.equip_from_inventory(inventory, 0, EquipmentSlot.Type.CHEST):
		print("FAIL: CANNOT EQUIP CHESTPLATE")
		problems += 1
	else:
		var totals: Dictionary = system.get_totals()
		var encumbrance: float = float(totals.get("encumbrance", -1.0))
		if not is_equal_approx(encumbrance, 0.8):
			print("FAIL: ENCUMBRANCE WRONG: ", encumbrance, " (expected 0.8)")
			problems += 1
		var speed_mult: float = float(totals.get("encumbrance_speed_multiplier", -1.0))
		# 1.0 - 0.8 * 0.4 = 0.68
		if not is_equal_approx(speed_mult, 0.68):
			print("FAIL: SPEED MULT WRONG: ", speed_mult, " (expected 0.68)")
			problems += 1
		var regen_mult: float = float(totals.get("encumbrance_regen_multiplier", -1.0))
		# 1.0 - 0.8 * 0.5 = 0.6
		if not is_equal_approx(regen_mult, 0.6):
			print("FAIL: REGEN MULT WRONG: ", regen_mult, " (expected 0.6)")
			problems += 1

	if not system.unequip_to_inventory(inventory, EquipmentSlot.Type.CHEST):
		print("FAIL: CANNOT UNEQUIP")
		problems += 1
	else:
		if not is_equal_approx(float(holder.encumbrance), 0.0):
			print("FAIL: ENCUMBRANCE NOT RESET: ", holder.encumbrance)
			problems += 1
		if not is_equal_approx(float(holder.encumbrance_speed_multiplier), 1.0):
			print("FAIL: SPEED MULT NOT RESET: ", holder.encumbrance_speed_multiplier)
			problems += 1

	system.free()
	# inventory и holder — Resource/RefCounted-обёртки, их нельзя free().

	print("  ENCUMBRANCE_CALC: OK" if problems == 0 else "  ENCUMBRANCE_CALC: FAIL")
	return problems


## При encumbrance ≥ 1.0 включается is_overencumbered:
## множитель скорости не падает ниже MINIMUM_SPEED_MULTIPLIER,
## реген не падает ниже MINIMUM_REGEN_MULTIPLIER.
func _test_overencumbered_restrictions() -> int:
	var problems := 0

	var hat: EquipmentComponent = (
		load("res://data/items/cloth_hat_item.tres") as EquipmentComponent
	)
	var chest: EquipmentComponent = (
		load("res://data/items/cloth_chest_item.tres") as EquipmentComponent
	)
	var boots: EquipmentComponent = (
		load("res://data/items/iron_boots_item.tres") as EquipmentComponent
	)
	if hat == null or chest == null or boots == null:
		print("FAIL: ARMOR UNLOADABLE")
		return 1

	ItemRegistry.register_item(hat)
	ItemRegistry.register_item(chest)
	ItemRegistry.register_item(boots)

	var holder = preload("res://tests/poise_stat_holder.gd").new()
	# Маленькая грузоподъёмность: 8+5+5 = 18 / 1.0 = 18 → overencumbered.
	holder.equip_load_capacity_kg = 1.0

	var system = EquipmentSystem.new()
	holder.add_child(system)
	system.setup(holder)

	var inventory := InventoryData.new()
	inventory.setup(9, true)
	inventory.set_slot(0, &"cloth_hat", 1)
	inventory.set_slot(1, &"cloth_chest", 1)
	inventory.set_slot(2, &"iron_boots", 1)

	system.equip_from_inventory(inventory, 0, EquipmentSlot.Type.HEAD)
	system.equip_from_inventory(inventory, 1, EquipmentSlot.Type.CHEST)
	system.equip_from_inventory(inventory, 2, EquipmentSlot.Type.BOOTS)

	var totals: Dictionary = system.get_totals()
	var enc: float = float(totals.get("encumbrance", 0.0))
	if enc < 1.0:
		print("FAIL: ENCUMBRANCE NOT >= 1.0: ", enc)
		problems += 1
	if not bool(totals.get("is_overencumbered", false)):
		print("FAIL: NOT OVERENCUMBERED")
		problems += 1

	var speed_mult: float = float(totals.get("encumbrance_speed_multiplier", 1.0))
	if speed_mult >= 0.5:
		print("FAIL: SPEED MULT TOO HIGH FOR OVERENCUMBERED: ", speed_mult)
		problems += 1

	var regen_mult: float = float(totals.get("encumbrance_regen_multiplier", 1.0))
	if regen_mult >= 0.3:
		print("FAIL: REGEN MULT TOO HIGH FOR OVERENCUMBERED: ", regen_mult)
		problems += 1

	system.free()
	# inventory и holder — Resource/RefCounted-обёртки, их нельзя free().

	print("  OVERENCUMBERED: OK" if problems == 0 else "  OVERENCUMBERED: FAIL")
	return problems