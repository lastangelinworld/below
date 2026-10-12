extends Node

## Смоук-тест анимаций скелета (Этап C/D плана
## docs/PLAN_SKELETON_ANIMATION.md).
## Инстанцирует настоящую сцену и проверяет, что библиотека клипов
## построена, а каждый трек указывает на существующую ноду и свойство.
## Запуск: godot --headless --path . res://tests/smoke_skeleton_anim.tscn


const REQUIRED: Array[StringName] = [
	&"idle", &"walk", &"light_windup", &"light_swing",
	&"heavy_windup", &"heavy_swing", &"block",
	&"bow_draw", &"bow_release", &"stagger", &"death", &"RESET",
]


func _ready() -> void:
	var failures: int = 0
	failures += _test_library_and_tracks()
	failures += _test_play_states()
	print("SMOKE SKELETON ANIM RESULT: ", "FAIL " if failures > 0 else "OK", " (", failures, " проблем)")
	get_tree().quit(1 if failures > 0 else 0)


func _test_library_and_tracks() -> int:
	var problems := 0
	var skeleton: Skeleton = (load("res://data/world/skeleton.tscn") as PackedScene).instantiate()
	add_child(skeleton)

	var player: AnimationPlayer = skeleton.animation_player
	if player == null:
		print("FAIL: NO ANIMATION PLAYER")
		skeleton.free()
		return 1

	for name: StringName in REQUIRED:
		if not player.has_animation(name):
			print("FAIL: MISSING ANIM ", name)
			problems += 1

	# Каждый трек обязан вести на реальную ноду: пути написаны руками,
	# опечатка в имени пивота проявилась бы только «молчаливой» анимацией.
	# Пути треков резолвятся от root_node плеера (по умолчанию «..»),
	# а не от самого AnimationPlayer — проверяем так же, как движок.
	var anim_root: Node = player.get_node(player.root_node)
	for anim_name: StringName in player.get_animation_list():
		var anim: Animation = player.get_animation(anim_name)
		for track: int in range(anim.get_track_count()):
			var path: NodePath = anim.track_get_path(track)
			var node: Node = anim_root.get_node_or_null(
				NodePath(String(path.get_concatenated_names()))
			)
			if node == null:
				print("FAIL: BROKEN TRACK ", anim_name, " -> ", path)
				problems += 1
			elif not node.has_method("set") or not path.get_concatenated_subnames():
				print("FAIL: TRACK WITHOUT PROPERTY ", anim_name, " -> ", path)
				problems += 1
			elif not _has_property(node, String(path.get_concatenated_subnames())):
				print("FAIL: MISSING PROPERTY ", anim_name, " -> ", path)
				problems += 1

	skeleton.free()
	print("  LIBRARY_AND_TRACKS: OK" if problems == 0 else "  LIBRARY_AND_TRACKS: FAIL")
	return problems


func _has_property(node: Node, property: String) -> bool:
	for entry: Dictionary in node.get_property_list():
		if entry.name == property:
			return true
	return false


## Скелет стартует в покое, стаггер переводит в соответствующий клип,
## конец стаггера возвращает покой — тот же путь, что в бою.
func _test_play_states() -> int:
	var problems := 0
	var skeleton: Skeleton = (load("res://data/world/skeleton.tscn") as PackedScene).instantiate()
	add_child(skeleton)

	if skeleton.animation_player.current_animation != &"idle":
		print("FAIL: NOT IDLE ON READY: ", skeleton.animation_player.current_animation)
		problems += 1

	skeleton.apply_stagger(1.0)
	if skeleton.animation_player.current_animation != &"stagger":
		print("FAIL: STAGGER ANIM NOT PLAYING: ", skeleton.animation_player.current_animation)
		problems += 1

	# Выход из стаггера: поиз восстанавливаем, таймер гасим через tick.
	skeleton.poise.tick(1.5)
	if skeleton.animation_player.current_animation != &"idle":
		print("FAIL: IDLE NOT RESTORED AFTER STAGGER: ", skeleton.animation_player.current_animation)
		problems += 1

	skeleton.free()
	print("  PLAY_STATES: OK" if problems == 0 else "  PLAY_STATES: FAIL")
	return problems
