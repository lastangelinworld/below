extends Node

## Смоук-тест телеграфов атаки (Фаза 7).
## Проверяет фазы замах → удар → восстановление, выбор лёгкого/тяжёлого
## удара и флаги Hitbox (breaks_block, множители урона и поиза).
## Запуск: godot --headless --path . res://tests/smoke_telegraph.tscn


func _ready() -> void:
	var failures: int = 0
	failures += _test_light_attack_cycle()
	failures += _test_heavy_attack_cycle()
	failures += _test_no_restart_during_attack()
	print("SMOKE TELEGRAPH RESULT: ", "FAIL " if failures > 0 else "OK", " (", failures, " проблем)")
	get_tree().quit(1 if failures > 0 else 0)


## Готовит скелета с подставным клинком и хитбоксом: в тестовой сцене
## нет children из skeleton.tscn, а фазам нужны именно эти узлы.
func _make_skeleton(heavy_chance: float) -> Skeleton:
	var skeleton := Skeleton.new()
	skeleton.randomize_type = false
	skeleton.melee_unit = true
	skeleton.heavy_chance = heavy_chance
	add_child(skeleton)

	var hitbox := Hitbox.new()
	skeleton.add_child(hitbox)
	skeleton.weapon_hitbox = hitbox

	var sword := Sprite2D.new()
	skeleton.add_child(sword)
	skeleton.sword_visual = sword
	skeleton._sword_base_color = sword.modulate
	return skeleton


## Лёгкий удар: короткий замах, клинок подсвечен, удар НЕ ломает блок,
## после восстановления — обычный цвет и кулдаун.
func _test_light_attack_cycle() -> int:
	var problems := 0
	var skeleton := _make_skeleton(0.0)

	skeleton._begin_melee_attack()
	if skeleton._attack_phase != Skeleton.AttackPhase.WINDUP:
		print("FAIL: LIGHT WINDUP NOT STARTED")
		problems += 1
	if not is_equal_approx(skeleton._attack_timer, skeleton.light_windup_sec):
		print("FAIL: LIGHT WINDUP TIMER WRONG: ", skeleton._attack_timer)
		problems += 1
	if skeleton._is_heavy:
		print("FAIL: LIGHT CHANCE 0 SELECTED HEAVY")
		problems += 1
	if skeleton.sword_visual.modulate == skeleton._sword_base_color:
		print("FAIL: NO WINDUP TINT")
		problems += 1

	# Замах ещё идёт — фаза не меняется, пока таймер не истёк.
	skeleton._advance_attack_phase(skeleton.light_windup_sec * 0.5)
	if skeleton._attack_phase != Skeleton.AttackPhase.WINDUP:
		print("FAIL: WINDUP ENDED EARLY")
		problems += 1

	# Доудаём замах: фаза удара, хитбоксы выставлены под лёгкий.
	skeleton._advance_attack_phase(skeleton.light_windup_sec)
	if skeleton._attack_phase != Skeleton.AttackPhase.HIT:
		print("FAIL: WINDUP DID NOT BECOME HIT")
		problems += 1
	if skeleton.weapon_hitbox.breaks_block:
		print("FAIL: LIGHT BREAKS BLOCK")
		problems += 1
	if skeleton.weapon_hitbox.damage != skeleton.melee_damage:
		print("FAIL: LIGHT DAMAGE SCALED: ", skeleton.weapon_hitbox.damage)
		problems += 1
	if not is_equal_approx(
		skeleton.weapon_hitbox.poise_damage, skeleton.melee_poise_damage
	):
		print("FAIL: LIGHT POISE SCALED: ", skeleton.weapon_hitbox.poise_damage)
		problems += 1

	skeleton._advance_attack_phase(Skeleton.HIT_ACTIVE_SEC)
	if skeleton._attack_phase != Skeleton.AttackPhase.RECOVERY:
		print("FAIL: HIT DID NOT BECOME RECOVERY")
		problems += 1
	if skeleton.sword_visual.modulate != skeleton._sword_base_color:
		print("FAIL: SWORD TINT NOT RESET AFTER HIT")
		problems += 1
	if not is_equal_approx(skeleton._attack_timer, skeleton.light_recover_sec):
		print("FAIL: LIGHT RECOVERY TIMER WRONG: ", skeleton._attack_timer)
		problems += 1

	skeleton._advance_attack_phase(skeleton.light_recover_sec)
	if skeleton._attack_phase != Skeleton.AttackPhase.NONE:
		print("FAIL: RECOVERY DID NOT END")
		problems += 1
	if skeleton._attack_cooldown <= 0.0:
		print("FAIL: NO COOLDOWN AFTER ATTACK")
		problems += 1

	skeleton.free()
	print("  LIGHT_CYCLE: OK" if problems == 0 else "  LIGHT_CYCLE: FAIL")
	return problems


## Тяжёлый удар: длинный замах, удар ломает блок, урон и поиз умножены,
## восстановление дольше лёгкого.
func _test_heavy_attack_cycle() -> int:
	var problems := 0
	var skeleton := _make_skeleton(1.0)

	skeleton._begin_melee_attack()
	if not skeleton._is_heavy:
		print("FAIL: HEAVY CHANCE 1 SELECTED LIGHT")
		problems += 1
	if not is_equal_approx(skeleton._attack_timer, skeleton.heavy_windup_sec):
		print("FAIL: HEAVY WINDUP TIMER WRONG: ", skeleton._attack_timer)
		problems += 1
	if skeleton.heavy_windup_sec <= skeleton.light_windup_sec:
		print("FAIL: HEAVY WINDUP NOT LONGER THAN LIGHT")
		problems += 1

	skeleton._advance_attack_phase(skeleton.heavy_windup_sec)
	if skeleton._attack_phase != Skeleton.AttackPhase.HIT:
		print("FAIL: HEAVY WINDUP DID NOT BECOME HIT")
		problems += 1
	if not skeleton.weapon_hitbox.breaks_block:
		print("FAIL: HEAVY DOES NOT BREAK BLOCK")
		problems += 1
	var expected_damage: int = maxi(
		1, int(roundf(float(skeleton.melee_damage) * skeleton.heavy_damage_multiplier))
	)
	if skeleton.weapon_hitbox.damage != expected_damage:
		print("FAIL: HEAVY DAMAGE WRONG: ", skeleton.weapon_hitbox.damage)
		problems += 1
	if not is_equal_approx(
		skeleton.weapon_hitbox.poise_damage,
		skeleton.melee_poise_damage * skeleton.heavy_poise_multiplier
	):
		print("FAIL: HEAVY POISE WRONG: ", skeleton.weapon_hitbox.poise_damage)
		problems += 1

	skeleton._advance_attack_phase(Skeleton.HIT_ACTIVE_SEC)
	if not is_equal_approx(skeleton._attack_timer, skeleton.heavy_recover_sec):
		print("FAIL: HEAVY RECOVERY TIMER WRONG: ", skeleton._attack_timer)
		problems += 1
	if skeleton.heavy_recover_sec <= skeleton.light_recover_sec:
		print("FAIL: HEAVY RECOVERY NOT LONGER THAN LIGHT")
		problems += 1

	skeleton.free()
	print("  HEAVY_CYCLE: OK" if problems == 0 else "  HEAVY_CYCLE: FAIL")
	return problems


## Во время фазы атаки новая атака не начинается: телеграф не «накладывается».
func _test_no_restart_during_attack() -> int:
	var problems := 0
	var skeleton := _make_skeleton(0.0)
	var dummy := CharacterBody2D.new()
	add_child(dummy)
	skeleton._player = dummy

	skeleton._try_attack(skeleton.MELEE_RANGE)
	if skeleton._attack_phase != Skeleton.AttackPhase.WINDUP:
		print("FAIL: IN-RANGE ATTACK DID NOT START")
		problems += 1
	var windup_timer: float = skeleton._attack_timer

	skeleton._try_attack(skeleton.MELEE_RANGE)
	if not is_equal_approx(skeleton._attack_timer, windup_timer):
		print("FAIL: ATTACK RESTARTED MID-WINDUP")
		problems += 1

	skeleton.free()
	dummy.free()
	print("  NO_RESTART: OK" if problems == 0 else "  NO_RESTART: FAIL")
	return problems
