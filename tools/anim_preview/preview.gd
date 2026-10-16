extends Node2D

## Стенд для снимков анимаций настоящим движком.
##
## Запуск:
##   Godot_v4.7.2-stable_win64.exe --path <проект> res://tools/anim_preview/preview.tscn
##
## Сцена поднимает игрока, выдаёт ему предмет и снимает кадры выбранной
## анимации в PNG. Нужен, потому что по одной геометрии не видно, как
## сцена выглядит на самом деле: слои отрисовки, спрайты экипировки и
## порядок работы нескольких AnimationPlayer проверяются только так.

const OUT_DIR := "C:/Users/Flatt/AppData/Local/Temp/claude/C--Users-Flatt-Desktop-below/e7647cb2-ba68-427f-b513-4c96ff44bc19/scratchpad/shots"

@export var item_id: StringName = &"bone_greatclub"
@export var clip: StringName = &"two_handed_1"
@export var times: PackedFloat32Array = PackedFloat32Array(
	[0.0, 0.06, 0.12, 0.18, 0.22, 0.26, 0.32, 0.40, 0.50]
)

var _player: Node2D


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	RenderingServer.set_default_clear_color(Color(0.08, 0.08, 0.10))

	_player = load("res://entities/player/player.tscn").instantiate()
	add_child(_player)
	await get_tree().process_frame
	await get_tree().process_frame

	# Пол под ногами: физику НЕ глушим, иначе стенд не воспроизводит
	# главное — одновременную работу LocomotionPlayer и AttackPlayer.
	var floor_body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(600.0, 40.0)
	shape.shape = rect
	shape.position = Vector2(0.0, 54.0)
	floor_body.add_child(shape)
	add_child(floor_body)
	# Взгляд задаётся курсором и пересчитывается каждый кадр в
	# _process, поэтому просто ставим мышь правее персонажа.
	Input.warp_mouse(Vector2(get_viewport().get_visible_rect().size.x - 20.0,
		get_viewport().get_visible_rect().size.y * 0.5))

	var camera := Camera2D.new()
	camera.zoom = Vector2(5.0, 5.0)
	camera.position = Vector2(8.0, -14.0)
	add_child(camera)
	camera.make_current()

	if item_id != &"":
		var stack := ItemStack.new()
		stack.set_item(item_id, 1)
		_player.equipment.swap_single(EquipmentSlot.Type.MAINHAND, stack)
	for i in 4:
		await get_tree().process_frame

	_dump("стойка")
	await _shot("00_stoyka")

	if clip != &"" and _player.locomotion_player.has_animation(clip):
		# Клипы локомоции (смерть, присед, перекат) крутим напрямую.
		_player.set_physics_process(false)
		_player.locomotion_player.play(clip)
		var elapsed_loc := 0.0
		var next_loc := 0
		while next_loc < times.size():
			await RenderingServer.frame_post_draw
			elapsed_loc += get_process_delta_time()
			if elapsed_loc >= times[next_loc]:
				var shot: Image = get_viewport().get_texture().get_image()
				shot.save_png("%s/%s_%03d.png" % [OUT_DIR, clip, int(round(times[next_loc] * 100.0))])
				next_loc += 1
		print("СНИМКИ ГОТОВЫ: ", OUT_DIR)
		get_tree().quit()
		return

	if clip != &"":
		_player._start_next_combo_attack()
		await get_tree().process_frame
		# Ждём по-настоящему: удар должен идти вместе с локомоцией,
		# как в игре, а не перематываться.
		var elapsed := 0.0
		var next := 0
		while next < times.size():
			await RenderingServer.frame_post_draw
			elapsed += get_process_delta_time()
			if elapsed >= times[next]:
				var image: Image = get_viewport().get_texture().get_image()
				image.save_png("%s/%s_%03d.png" % [OUT_DIR, clip, int(round(times[next] * 100.0))])
				next += 1

	print("СНИМКИ ГОТОВЫ: ", OUT_DIR)
	get_tree().quit()


## Печатает, где на самом деле оказались руки и оружие.
func _dump(label: String) -> void:
	var visuals: Node2D = _player.get_node("Visuals")
	var socket: Node2D = _player.get_node(
		"Visuals/BodyBreath/BackShoulder/BackElbow/BackWrist/HandSocket")
	var sprite: Node2D = _player.get_node(
		"Visuals/BodyBreath/BackShoulder/BackElbow/BackWrist/HandSocket/Pickaxe/PickaxeSprite")
	var shoulder: Node = null
	for child in socket.get_children():
		if child is Sprite2D and child.name != "Pickaxe":
			shoulder = child
	print("--- ", label)
	print("  attack=", _player.attack_player.current_animation,
		" t=", _player.attack_player.current_animation_position,
		" | locomotion=", _player.locomotion_player.current_animation,
		" t=", _player.locomotion_player.current_animation_position,
		" | pickaxe_swinging=", _player.pickaxe_swinging,
		" combo=", _player.combo_step, " carry=", _player._carry_pose_active)
	print("  visuals.scale=", visuals.scale, "  facing=", _player.facing)
	print("  BackShoulder=", _player.get_node("Visuals/BodyBreath/BackShoulder").rotation,
		"  BackElbow=", _player.get_node("Visuals/BodyBreath/BackShoulder/BackElbow").rotation,
		"  BackWrist=", _player.get_node("Visuals/BodyBreath/BackShoulder/BackElbow/BackWrist").rotation)
	print("  FrontArmAim=", _player.get_node("Visuals/BodyBreath/FrontArmAim").rotation,
		"  FrontArmAttack=", _player.get_node("Visuals/BodyBreath/FrontArmAim/FrontArmAttack").rotation,
		"  FrontElbow=", _player.get_node("Visuals/BodyBreath/FrontArmAim/FrontArmAttack/FrontElbow").rotation)
	_compare("Visuals/BodyBreath/BackShoulder:rotation")
	_compare("Visuals/BodyBreath/BackShoulder/BackElbow:rotation")
	_compare("Visuals/BodyBreath/FrontArmAim/FrontArmAttack:rotation")
	print("  Pickaxe.rotation=", _player.get_node(
		"Visuals/BodyBreath/BackShoulder/BackElbow/BackWrist/HandSocket/Pickaxe").rotation)
	print("  held visible=", _player.held_weapon_sprite.visible,
		" pos=", _player.held_weapon_sprite.position,
		" scale=", _player.held_weapon_sprite.scale,
		" z=", _player.held_weapon_sprite.z_index, " rel=", _player.held_weapon_sprite.z_as_relative)
	if shoulder != null:
		print("  плечевой спрайт: visible=", shoulder.visible, " pos=", shoulder.position,
			" rot=", shoulder.rotation, " scale=", shoulder.scale,
			" z=", shoulder.z_index, " rel=", shoulder.z_as_relative)
		var tip: Vector2 = _player.to_local(shoulder.global_transform * Vector2(251.0, 0.0))
		var butt: Vector2 = _player.to_local(shoulder.global_transform * Vector2(-251.0, 0.0))
		print("  дубина (плечевой): торец ", butt, "  головка ", tip)
	var tip2: Vector2 = _player.to_local(sprite.global_transform * Vector2(251.0, 0.0))
	var butt2: Vector2 = _player.to_local(sprite.global_transform * Vector2(-251.0, 0.0))
	print("  дубина (в руке):  торец ", butt2, "  головка ", tip2)


## Сверяет значение узла с тем, что должно давать клип удара.
func _compare(track_path: String) -> void:
	var anim: Animation = _player.attack_player.get_animation(
		_player.attack_player.current_animation)
	if anim == null:
		return
	var index: int = anim.find_track(NodePath(track_path), Animation.TYPE_VALUE)
	if index < 0:
		print("  ", track_path, ": дорожки в клипе нет")
		return
	var want = anim.value_track_interpolate(index, _player.attack_player.current_animation_position)
	var node_path: String = track_path.get_slice(":", 0)
	var got: float = _player.get_node(node_path).rotation
	var kinds := {}
	for k in anim.track_get_key_count(index):
		var v = anim.track_get_key_value(index, k)
		kinds[type_string(typeof(v))] = int(kinds.get(type_string(typeof(v)), 0)) + 1
	print("  %-22s клип %+.4f  узел %+.4f  типы ключей %s" % [
		node_path.get_file(), want, got, kinds])


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [OUT_DIR, name])
