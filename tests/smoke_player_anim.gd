extends Node

## Смоук-тест кодовой анимации игрока (PlayerAnimations).
## Проверяет три вещи, без которых анимация «молчит»:
##   1. все нужные клипы построены;
##   2. каждый трек указывает на реальную ноду и реальное свойство
##      (пути собраны строками — опечатка в имени пивота иначе
##      проявилась бы только тишиной в игре);
##   3. ни один трек не спорит со скриптом: player.gd каждый кадр пишет
##      BodyBreath:rotation, HeadBreath:rotation, FrontArmAim:rotation и
##      Visuals:scale.x, и анимация эти пары трогать не должна.
## Запуск: godot --headless --path . res://tests/smoke_player_anim.tscn


const LOCOMOTION_REQUIRED: Array[StringName] = [
	&"RESET", &"idle", &"walk", &"run", &"sprint", &"walk_back",
	&"crouch", &"crouch_walk", &"jump", &"stagger", &"death",
]

const ATTACK_REQUIRED: Array[StringName] = [
	&"RESET", &"attack_1", &"attack_2", &"attack_3",
	&"two_handed_1", &"two_handed_2", &"two_handed_3",
	&"block", &"interact", &"inventory_loop",
]

const SECONDARY_REQUIRED: Array[StringName] = [&"RESET", &"life_loop"]

## Свойства, владельцем которых является скрипт, а не анимация.
const SCRIPT_OWNED: Array[StringName] = [
	&"Visuals/BodyBreath:rotation",
	&"Visuals/BodyBreath/NeckPivot/HeadBreath:rotation",
	&"Visuals/BodyBreath/FrontArmAim:rotation",
	&"Visuals:scale",
]


func _ready() -> void:
	var failures: int = 0
	failures += _test_all()
	print("SMOKE PLAYER ANIM RESULT: ", "FAIL " if failures > 0 else "OK", " (", failures, " проблем)")
	get_tree().quit(1 if failures > 0 else 0)


func _test_all() -> int:
	var problems := 0
	var player: CharacterBody2D = (load("res://entities/player/player.tscn") as PackedScene).instantiate()
	add_child(player)

	var players: Dictionary = {
		"LocomotionPlayer": [player.get_node("LocomotionPlayer"), LOCOMOTION_REQUIRED],
		"AttackPlayer": [player.get_node("AttackPlayer"), ATTACK_REQUIRED],
		"SecondaryMotionPlayer": [player.get_node("Visuals/SecondaryMotionPlayer"), SECONDARY_REQUIRED],
	}

	for player_name: String in players:
		var animation_player: AnimationPlayer = players[player_name][0]
		var required: Array = players[player_name][1]

		for clip_name: StringName in required:
			if not animation_player.has_animation(clip_name):
				print("FAIL: MISSING CLIP ", player_name, "/", clip_name)
				problems += 1

		problems += _check_tracks(player_name, animation_player)

	player.free()
	print("  ", "OK" if problems == 0 else "FAIL")
	return problems


## Каждый трек резолвится так же, как это делает движок: от root_node
## плеера, а не от самого AnimationPlayer.
func _check_tracks(player_name: String, animation_player: AnimationPlayer) -> int:
	var problems := 0
	var anim_root: Node = animation_player.get_node(animation_player.root_node)

	for clip_name: StringName in animation_player.get_animation_list():
		var anim: Animation = animation_player.get_animation(clip_name)
		for track: int in range(anim.get_track_count()):
			var path: NodePath = anim.track_get_path(track)
			var node_path := String(path.get_concatenated_names())
			var property := String(path.get_concatenated_subnames())
			var where := "%s/%s track %d -> %s" % [player_name, clip_name, track, path]

			if property.is_empty():
				print("FAIL: TRACK WITHOUT PROPERTY ", where)
				problems += 1
				continue

			var target: Node = anim_root.get_node_or_null(NodePath(node_path))
			if target == null:
				print("FAIL: BROKEN TRACK ", where)
				problems += 1
				continue

			if not _has_property(target, property):
				print("FAIL: MISSING PROPERTY ", where)
				problems += 1

			# Скрипт и анимация не должны владеть одним свойством.
			# SecondaryMotionPlayer пишет пути относительно Visuals,
			# поэтому сравниваем нормализованный путь от корня игрока.
			if _is_script_owned(animation_player, node_path, property):
				print("FAIL: SCRIPT-ANIM CONFLICT ", where)
				problems += 1

	return problems


func _is_script_owned(
	animation_player: AnimationPlayer,
	node_path: String,
	property: String
) -> bool:
	var absolute := node_path
	# Пути SecondaryMotionPlayer отсчитываются от Visuals.
	if String(animation_player.root_node) == ".." and animation_player.get_parent() != null:
		var owner_name: String = String(animation_player.get_parent().name)
		if not node_path.begins_with(owner_name + "/"):
			absolute = owner_name + "/" + node_path
	var full := StringName(absolute + ":" + property)
	return SCRIPT_OWNED.has(full)


func _has_property(node: Node, property: String) -> bool:
	for entry: Dictionary in node.get_property_list():
		if entry.name == property:
			return true
	return false
