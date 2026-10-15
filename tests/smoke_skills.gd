extends Node

## Смоук-тест навыков оружия и боя (Фаза 6).
## Запуск: godot --headless --path . res://tests/smoke_skills.tscn


func _ready() -> void:
	var failures: int = 0
	failures += _test_xp_curve_and_level_up()
	failures += _test_multipliers()
	failures += _test_save_load()
	failures += _test_weapons_skill_mapping()
	print("SMOKE SKILLS RESULT: ", "FAIL " if failures > 0 else "OK", " (", failures, " проблем)")
	get_tree().quit(1 if failures > 0 else 0)


## Квадратичная кривая: 1-й уровень стоит 50 XP, 2-й — ещё 150
## (всего 200). Уровень растёт ровно на пороге, не раньше.
func _test_xp_curve_and_level_up() -> int:
	var problems := 0
	var skills := SkillsComponent.new()

	if not is_equal_approx(skills.xp_to_next_level(SkillsComponent.Skill.SWORDS), 50.0):
		print("FAIL: FIRST LEVEL COST ", skills.xp_to_next_level(SkillsComponent.Skill.SWORDS))
		problems += 1

	skills.add_xp(SkillsComponent.Skill.SWORDS, 49.0)
	if skills.get_level(SkillsComponent.Skill.SWORDS) != 0:
		print("FAIL: LEVEL UP TOO EARLY AT 49 XP")
		problems += 1

	skills.add_xp(SkillsComponent.Skill.SWORDS, 1.0)
	if skills.get_level(SkillsComponent.Skill.SWORDS) != 1:
		print("FAIL: NO LEVEL UP AT 50 XP")
		problems += 1

	# Второй уровень требует 200 суммарно: осталось 150.
	if not is_equal_approx(skills.xp_to_next_level(SkillsComponent.Skill.SWORDS), 150.0):
		print("FAIL: SECOND LEVEL COST ", skills.xp_to_next_level(SkillsComponent.Skill.SWORDS))
		problems += 1

	# Прокачка одного навыка не трогает другие.
	if skills.get_level(SkillsComponent.Skill.AXES) != 0:
		print("FAIL: OTHER SKILL LEVELED")
		problems += 1
	if not is_equal_approx(skills.get_total_xp(), 50.0):
		print("FAIL: TOTAL XP ", skills.get_total_xp())
		problems += 1

	skills.free()
	print("  XP_CURVE: OK" if problems == 0 else "  XP_CURVE: FAIL")
	return problems


## Все боевые множители: урон +4%/уровень, окно парирования +0.03 с,
## стоимость блока и ролла снижаются с полом, спринт и дальность растут.
func _test_multipliers() -> int:
	var problems := 0
	var skills := SkillsComponent.new()

	# Уровень 5: 5 × 0.04 = 0.2 → множитель урона 1.2.
	skills.add_xp(SkillsComponent.Skill.SWORDS, 200.0)
	if skills.get_level(SkillsComponent.Skill.SWORDS) != 2:
		print("FAIL: EXPECTED LEVEL 2, GOT ", skills.get_level(SkillsComponent.Skill.SWORDS))
		problems += 1
	if not is_equal_approx(skills.damage_multiplier(SkillsComponent.Skill.SWORDS), 1.08):
		print("FAIL: DAMAGE MULT ", skills.damage_multiplier(SkillsComponent.Skill.SWORDS))
		problems += 1

	# Нулевой уровень не меняет ничего.
	if not is_equal_approx(skills.damage_multiplier(SkillsComponent.Skill.AXES), 1.0):
		print("FAIL: LEVEL 0 DAMAGE MULT != 1.0")
		problems += 1
	if not is_equal_approx(skills.parry_window_bonus(SkillsComponent.Skill.BLOCKING), 0.0):
		print("FAIL: LEVEL 0 PARRY BONUS != 0")
		problems += 1

	# Окно парирования: +0.03 с за уровень.
	skills.add_xp(SkillsComponent.Skill.BLOCKING, 450.0)
	var blocking_level: int = skills.get_level(SkillsComponent.Skill.BLOCKING)
	if not is_equal_approx(
		skills.parry_window_bonus(SkillsComponent.Skill.BLOCKING),
		float(blocking_level) * 0.03
	):
		print("FAIL: PARRY BONUS AT LEVEL ", blocking_level)
		problems += 1

	# Пол стоимости: 100 уровней подряд множитель не провалится под 0.3.
	for step: int in range(100):
		skills.add_xp(SkillsComponent.Skill.DODGE, 100000.0)
	if skills.dodge_cost_multiplier(SkillsComponent.Skill.DODGE) < 0.3:
		print("FAIL: DODGE COST MULT BELOW FLOOR")
		problems += 1
	if skills.block_stamina_multiplier(SkillsComponent.Skill.BLOCKING) < 0.3:
		print("FAIL: BLOCK COST MULT BELOW FLOOR")
		problems += 1
	# А рост без пола: дальность ролла обязана расти.
	if skills.dodge_range_multiplier(SkillsComponent.Skill.DODGE) <= 1.0:
		print("FAIL: DODGE RANGE DID NOT GROW")
		problems += 1

	skills.free()
	print("  MULTIPLIERS: OK" if problems == 0 else "  MULTIPLIERS: FAIL")
	return problems


## Сохранение и загрузка восстанавливают уровни, опыт и прогресс
## до следующего уровня.
func _test_save_load() -> int:
	var problems := 0
	var original := SkillsComponent.new()
	original.add_xp(SkillsComponent.Skill.BLUNT, 120.0)
	original.add_xp(SkillsComponent.Skill.RUN, 30.0)
	var state: Dictionary = original.save_state()

	var loaded := SkillsComponent.new()
	loaded.load_state(state)

	if loaded.get_level(SkillsComponent.Skill.BLUNT) != original.get_level(SkillsComponent.Skill.BLUNT):
		print("FAIL: LOADED BLUNT LEVEL")
		problems += 1
	if not is_equal_approx(
		loaded.get_xp(SkillsComponent.Skill.RUN),
		original.get_xp(SkillsComponent.Skill.RUN)
	):
		print("FAIL: LOADED RUN XP")
		problems += 1
	if not is_equal_approx(loaded.get_total_xp(), original.get_total_xp()):
		print("FAIL: LOADED TOTAL XP")
		problems += 1
	if not is_equal_approx(
		loaded.xp_to_next_level(SkillsComponent.Skill.BLUNT),
		original.xp_to_next_level(SkillsComponent.Skill.BLUNT)
	):
		print("FAIL: LOADED PROGRESS TO NEXT LEVEL")
		problems += 1

	original.free()
	loaded.free()
	print("  SAVE_LOAD: OK" if problems == 0 else "  SAVE_LOAD: FAIL")
	return problems


## Оружие размечено по классам: меч → Мечи, кирки → Топоры,
## дубины → Тяжёлое; броня опыт не приносит.
func _test_weapons_skill_mapping() -> int:
	var problems := 0
	var expected := {
		"iron_sword": SkillsComponent.Skill.SWORDS,
		"bone_pickaxe": SkillsComponent.Skill.AXES,
		"iron_pickaxe": SkillsComponent.Skill.AXES,
		"wood_club": SkillsComponent.Skill.BLUNT,
		"bone_greatclub": SkillsComponent.Skill.BLUNT,
	}
	for id: String in expected.keys():
		var component: EquipmentComponent = (
			load("res://data/items/%s_item.tres" % id) as EquipmentComponent
		)
		if component == null:
			print("FAIL: UNLOADABLE ", id)
			problems += 1
			continue
		if not component.trains_skill:
			print("FAIL: WEAPON DOES NOT TRAIN ", id)
			problems += 1
		elif component.weapon_skill != expected[id]:
			print("FAIL: SKILL MAPPING ", id, " = ", component.weapon_skill)
			problems += 1

	# Броня и щит — не оружие.
	for id: String in ["cloth_chest", "iron_chestplate", "wood_shield"]:
		var armor: EquipmentComponent = (
			load("res://data/items/%s_item.tres" % id) as EquipmentComponent
		)
		if armor == null:
			print("FAIL: UNLOADABLE ARMOR ", id)
			problems += 1
		elif armor.trains_skill:
			print("FAIL: ARMOR TRAINS SKILL ", id)
			problems += 1

	print("  SKILL_MAPPING: OK" if problems == 0 else "  SKILL_MAPPING: FAIL")
	return problems
