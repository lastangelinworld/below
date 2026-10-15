extends Node

## Смоук-тест кулачного боя, конуса защиты и физической защиты щита.
## Проверяет четыре вещи:
##   1. AttackPlayer получает клипы fist_right / fist_left / fist_block,
##      в том числе когда библиотека уже «запечена» в player.tscn
##      (ensure_fist_combat дозаполняет недостающие, не затирая ключи);
##   2. пустые руки распознаются как unarmed, а щит или оружие — нет;
##   3. конус защиты пускает удары спереди и не пускает сзади;
##   4. Hitbox гасит урон, когда помечен щитом, и ловит защиту напрямую.
## Запуск: godot --headless --path . res://tests/smoke_fist_combat.tscn


const FIST_CLIPS: Array[StringName] = [&"fist_right", &"fist_left", &"fist_block"]

var _problems: int = 0


func _ready() -> void:
	ItemRegistry.register_item(load("res://data/items/wood_club_item.tres") as ItemData)
	ItemRegistry.register_item(load("res://data/items/wood_shield_item.tres") as ItemData)

	var player: CharacterBody2D = (load("res://entities/player/player.tscn") as PackedScene).instantiate()
	add_child(player)

	_test_fist_clips(player)
	_test_unarmed(player)
	_test_shield_cone(player)
	_test_shield_block_node(player)
	_test_hitbox_shield_flag()
	_test_parry_sparks()

	player.free()
	print("SMOKE FIST COMBAT RESULT: ", "FAIL " if _problems > 0 else "OK", " (", _problems, " проблем)")
	get_tree().quit(1 if _problems > 0 else 0)


## Клипы кулачного боя обязаны появиться в AttackPlayer, иначе удар
## без оружия не сыграет анимацию и player.gd напечатает ошибку.
func _test_fist_clips(player: CharacterBody2D) -> void:
	var attack_player: AnimationPlayer = player.get_node("AttackPlayer")
	for clip_name: StringName in FIST_CLIPS:
		if not attack_player.has_animation(clip_name):
			_fail("MISSING FIST CLIP " + String(clip_name))
			continue

		var anim: Animation = attack_player.get_animation(clip_name)
		if anim.length <= 0.0:
			_fail("EMPTY FIST CLIP " + String(clip_name))
		if anim.loop_mode == Animation.LOOP_LINEAR:
			_fail("FIST CLIP MUST NOT LOOP " + String(clip_name))
		if anim.get_track_count() == 0:
			_fail("FIST CLIP WITHOUT TRACKS " + String(clip_name))

		# Последний кадр обязан возвращать руки в стойку: клипы ударов
		# нециклические, их хвост и есть возврат в стойку. fist_block —
		# исключение: его последняя поза удерживается, пока зажата
		# кнопка блока, поэтому обнуляться она не должна.
		if clip_name != &"fist_block":
			var last_key_value: Variant = _last_value_of_first_track(anim)
			if last_key_value is float and not is_zero_approx(float(last_key_value)):
				_fail("FIST CLIP DOES NOT RETURN TO REST " + String(clip_name))

	_report("FIST_CLIPS")


func _last_value_of_first_track(anim: Animation) -> Variant:
	if anim.get_track_count() == 0:
		return null
	var key_count: int = anim.track_get_key_count(0)
	if key_count == 0:
		return null
	return anim.track_get_key_value(0, key_count - 1)


## Пустые руки — кулаки. Любая вещь в руках — обычное оружие.
## Индекс ячейки ищем явно: unequip возвращает предмет в первый
## свободный слот, и наивный «всегда ноль» дал бы подмену предмета.
func _test_unarmed(player: CharacterBody2D) -> void:
	if not bool(player.call("_is_unarmed")):
		_fail("PLAYER WITH EMPTY HANDS MUST BE UNARMED")

	var inventory: InventoryData = player.get("inventory")

	inventory.add_item(&"wood_club", 1)
	var club_index: int = _index_of(inventory, &"wood_club")
	if club_index < 0:
		_fail("CLUB NOT ADDED TO INVENTORY")
	elif not bool(player.call("equip_from_inventory", club_index, EquipmentSlot.Type.MAINHAND)):
		_fail("CANNOT EQUIP CLUB IN TEST")
	elif bool(player.call("_is_unarmed")):
		_fail("PLAYER WITH CLUB MUST NOT BE UNARMED")

	player.call("unequip_to_inventory", EquipmentSlot.Type.MAINHAND)

	inventory.add_item(&"wood_shield", 1)
	var shield_index: int = _index_of(inventory, &"wood_shield")
	if shield_index < 0:
		_fail("SHIELD NOT ADDED TO INVENTORY")
	elif not bool(player.call("equip_from_inventory", shield_index, EquipmentSlot.Type.OFFHAND)):
		_fail("CANNOT EQUIP SHIELD IN TEST")
	elif bool(player.call("_is_unarmed")):
		_fail("PLAYER WITH SHIELD MUST NOT BE UNARMED")
	elif not bool(player.call("_has_shield_equipped")):
		_fail("SHIELD MUST COUNT AS EQUIPPED")

	player.call("unequip_to_inventory", EquipmentSlot.Type.OFFHAND)
	if not bool(player.call("_is_unarmed")):
		_fail("UNEQUIP DID NOT RETURN TO UNARMED")

	_report("UNARMED_DETECT")


## Первый слот инвентаря с указанным предметом, или -1.
func _index_of(inventory: InventoryData, item_id: StringName) -> int:
	for slot: int in range(inventory.slot_count):
		var stack: ItemStack = inventory.get_slot(slot)
		if stack != null and not stack.is_empty() and stack.item_id == item_id:
			return slot
	return -1


## Конус защиты: спереди пускает, сзади не пускает.
## facing = 1 → взгляд вправо (угол 0).
func _test_shield_cone(player: CharacterBody2D) -> void:
	player.set("facing", 1)
	player.global_position = Vector2.ZERO

	if not bool(player.call("_is_in_shield_cone", Vector2(60.0, 0.0))):
		_fail("FRONTAL HIT MUST BE INSIDE CONE")
	if not bool(player.call("_is_in_shield_cone", Vector2(50.0, 40.0))):
		_fail("UPPER-FRONTAL HIT MUST BE INSIDE CONE")
	if bool(player.call("_is_in_shield_cone", Vector2(-60.0, 0.0))):
		_fail("BACK HIT MUST BE OUTSIDE CONE")
	if bool(player.call("_is_in_shield_cone", Vector2.ZERO)):
		_fail("ZERO SOURCE MUST BE OUTSIDE CONE")

	# Зеркало: взгляд влево — защита смотрит влево.
	player.set("facing", -1)
	if not bool(player.call("_is_in_shield_cone", Vector2(-60.0, 0.0))):
		_fail("FRONTAL HIT (LEFT) MUST BE INSIDE CONE")
	if bool(player.call("_is_in_shield_cone", Vector2(60.0, 0.0))):
		_fail("BACK HIT (LEFT) MUST BE OUTSIDE CONE")

	_report("SHIELD_CONE")


## Узел физической защиты существует, настроен и активен только в блоке.
func _test_shield_block_node(player: CharacterBody2D) -> void:
	var shield: Node = player.get_node_or_null("ShieldBlock")
	if shield == null:
		_fail("SHIELDBLOCK NODE MISSING")
		_report("SHIELD_BLOCK")
		return

	if not shield.has_method("is_blocking") or not shield.has_method("is_owner"):
		_fail("SHIELDBLOCK MISSING PUBLIC API")
		_report("SHIELD_BLOCK")
		return

	if bool(shield.call("is_blocking")):
		_fail("SHIELDBLOCK MUST BE INACTIVE WITHOUT BLOCK")

	player.set("is_blocking", true)
	if not bool(shield.call("is_blocking")):
		_fail("SHIELDBLOCK MUST BE ACTIVE WHILE BLOCKING")
	if not bool(shield.call("is_owner", player)):
		_fail("SHIELDBLOCK MUST RECOGNIZE ITS OWNER")
	if bool(shield.call("is_owner", self)):
		_fail("SHIELDBLOCK MUST REJECT FOREIGN OWNER")
	player.set("is_blocking", false)

	_report("SHIELD_BLOCK")


## Флаг блокировки: ставится и сбрасывается новым замахом, иначе
## один заблокированный удар навсегда «глушит» оружие.
func _test_hitbox_shield_flag() -> void:
	var hitbox := Hitbox.new()
	add_child(hitbox)

	hitbox.mark_shield_blocked()
	if not bool(hitbox.get("_shield_blocked")):
		_fail("mark_shield_blocked DID NOT SET FLAG")

	hitbox.activate(0.1)
	if bool(hitbox.get("_shield_blocked")):
		_fail("activate MUST CLEAR SHIELD FLAG")

	hitbox.free()
	_report("HITBOX_SHIELD_FLAG")


## Искры парирования: конструируются, ставятся в мир и удаляются сами.
func _test_parry_sparks() -> void:
	var before: int = get_child_count()
	ParrySparks.burst(self, Vector2.ZERO, Vector2.RIGHT)
	if get_child_count() <= before:
		_fail("PARRY SPARKS NOT ADDED TO WORLD")
		_report("PARRY_SPARKS")
		return

	var sparks: Node = get_child(get_child_count() - 1)
	if not bool(sparks.get("one_shot")):
		_fail("PARRY SPARKS MUST BE ONE SHOT")
	if int(sparks.get("amount")) <= 0:
		_fail("PARRY SPARKS WITHOUT PARTICLES")

	# burst() с нулевым направлением не должен ронять игру.
	ParrySparks.burst(self, Vector2.ZERO, Vector2.ZERO)
	if get_child_count() <= before + 1:
		_fail("PARRY SPARKS MUST SURVIVE ZERO DIRECTION")

	_report("PARRY_SPARKS")


func _fail(message: String) -> void:
	print("FAIL: ", message)
	_problems += 1


func _report(name: String) -> void:
	print("  ", name, ": OK")
