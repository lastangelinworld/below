## Запекатель клипов кулачного боя и оглушения в player.tscn.
## Запускать как СЦЕНУ (autoloads доступны):
##   godot --headless --path . res://tests/bake_fist_combat.tscn
## Иначе скрипты с autoload-зависимостями не компилируются, и
## PackedScene.pack() теряет их при сериализации.
extends Node

const PATH := "res://entities/player/player.tscn"


func _ready() -> void:
	var scene: PackedScene = load(PATH)
	var player := scene.instantiate()

	var attack_player: AnimationPlayer = player.get_node("AttackPlayer")
	var loc_player: AnimationPlayer = player.get_node("LocomotionPlayer")

	var attack_lib: AnimationLibrary = attack_player.get_animation_library(&"")
	var loc_lib: AnimationLibrary = loc_player.get_animation_library(&"")

	for clip: StringName in [&"fist_right", &"fist_left", &"fist_block"]:
		if attack_lib.has_animation(clip):
			print("SKIP existing attack clip: ", clip)
			continue
		var tmp := AnimationLibrary.new()
		PlayerAnimations._add_fist_combat(tmp)
		attack_lib.add_animation(clip, tmp.get_animation(clip))
		print("BAKED attack clip: ", clip)

	if loc_lib.has_animation(&"stagger"):
		print("SKIP existing locomotion clip: stagger")
	else:
		var tmp2 := AnimationLibrary.new()
		PlayerAnimations._add_stagger(tmp2)
		loc_lib.add_animation(&"stagger", tmp2.get_animation(&"stagger"))
		print("BAKED locomotion clip: stagger")

	var rebuilt := PackedScene.new()
	var err := rebuilt.pack(player)
	if err != OK:
		print("PACK FAILED: ", err)
		get_tree().quit(1)
		return
	err = ResourceSaver.save(rebuilt, PATH)
	if err != OK:
		print("SAVE FAILED: ", err)
		get_tree().quit(1)
		return
	print("BAKE DONE")
	get_tree().quit(0)
