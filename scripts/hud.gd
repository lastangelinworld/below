extends CanvasLayer


@export_group("Player")

## Путь до узла игрока.
## Если HUD и Player находятся рядом в Main,
## обычно это ../Player.
@export var player_path: NodePath = NodePath("../Player")


@export_group("Appearance")

@export var bar_width: float = 360.0
@export var health_bar_height: float = 20.0
@export var stamina_bar_height: float = 12.0
@export_range(0.0, 2.0, 0.05) var damage_hold_duration: float = 0.45
@export_range(0.05, 2.0, 0.05) var damage_fall_duration: float = 0.35


@export_group("Подбор предметов")

## Сколько секунд держится сообщение о подобранном предмете.
@export_range(0.5, 10.0, 0.1) var pickup_message_duration: float = 2.5

## Сколько сообщений показывать одновременно.
@export_range(1, 10, 1) var pickup_message_limit: int = 5


@onready var health_stack: Control = (
	$MarginContainer/VBoxContainer/HealthStack
)

@onready var delayed_health_bar: ProgressBar = (
	$MarginContainer/VBoxContainer/HealthStack/DelayedHealthBar
)

@onready var health_bar: ProgressBar = (
	$MarginContainer/VBoxContainer/HealthStack/HealthBar
)

@onready var stamina_bar: ProgressBar = (
	$MarginContainer/VBoxContainer/StaminaBar
)


var _health_tween: Tween

## Колонка всплывающих сообщений о подобранных предметах.
var _pickup_messages: VBoxContainer

## Затемнение с надписью и кнопкой возрождения.
var _death_screen: ColorRect

var _player: Node


func _ready() -> void:
	# HUD обязан работать на паузе, иначе кнопка возрождения не нажмётся.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_configure_interface()
	_create_pickup_messages()
	_create_death_screen()

	var player: Node = get_node_or_null(
		player_path
	)

	if player == null:
		push_error(
			"HUD: игрок не найден по пути: "
			+ str(player_path)
		)

		return

	_player = player

	if player.has_signal("health_changed"):
		player.health_changed.connect(
			_on_health_changed
		)

	if player.has_signal("stamina_changed"):
		player.stamina_changed.connect(
			_on_stamina_changed
		)

	if player.has_signal("died"):
		player.died.connect(
			_on_player_died
		)

	if player.has_signal("item_picked_up"):
		player.item_picked_up.connect(
			_on_item_picked_up
		)

	_sync_from_player(
		player
	)


## Создаёт колонку сообщений в правом нижнем углу.
func _create_pickup_messages() -> void:
	_pickup_messages = VBoxContainer.new()
	_pickup_messages.name = "PickupMessages"

	_pickup_messages.set_anchors_preset(
		Control.PRESET_BOTTOM_RIGHT
	)

	_pickup_messages.grow_horizontal = (
		Control.GROW_DIRECTION_BEGIN
	)

	_pickup_messages.grow_vertical = (
		Control.GROW_DIRECTION_BEGIN
	)

	_pickup_messages.offset_right = -24.0
	_pickup_messages.offset_bottom = -24.0

	_pickup_messages.alignment = (
		BoxContainer.ALIGNMENT_END
	)

	_pickup_messages.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	_pickup_messages.add_theme_constant_override(
		"separation",
		2
	)

	add_child(_pickup_messages)


## Показывает строку вида «Получено: 2 камня».
func _on_item_picked_up(
	item_id: StringName,
	amount: int
) -> void:
	if amount <= 0 or _pickup_messages == null:
		return

	var item: ItemData = ItemRegistry.get_item(item_id)

	var item_name: String = (
		item.get_counted_name(amount)
		if item != null
		else str(item_id)
	)

	_show_pickup_message(
		"Получено: %d %s" % [amount, item_name]
	)


func _show_pickup_message(text: String) -> void:
	var label := Label.new()

	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_RIGHT
	)

	label.add_theme_color_override(
		"font_color",
		Color("#e8e2d2")
	)

	label.add_theme_color_override(
		"font_outline_color",
		Color(0.0, 0.0, 0.0, 1.0)
	)

	label.add_theme_constant_override(
		"outline_size",
		4
	)

	label.add_theme_font_size_override(
		"font_size",
		15
	)

	_pickup_messages.add_child(label)

	# Лишние старые сообщения убираем сверху.
	while (
		_pickup_messages.get_child_count()
		> pickup_message_limit
	):
		var oldest: Node = _pickup_messages.get_child(0)
		_pickup_messages.remove_child(oldest)
		oldest.queue_free()

	var fade_tween := label.create_tween()

	fade_tween.tween_interval(
		pickup_message_duration
	)

	fade_tween.tween_property(
		label,
		"modulate:a",
		0.0,
		0.4
	)

	fade_tween.tween_callback(label.queue_free)


## Настраивает внешний вид полос.
func _configure_interface() -> void:
	health_stack.custom_minimum_size = Vector2(
		bar_width,
		health_bar_height
	)

	health_bar.custom_minimum_size = Vector2(
		bar_width,
		health_bar_height
	)

	delayed_health_bar.custom_minimum_size = Vector2(
		bar_width,
		health_bar_height
	)

	stamina_bar.custom_minimum_size = Vector2(
		bar_width,
		stamina_bar_height
	)

	# Дополнительная полоса здоровья должна
	# находиться позади основной.
	delayed_health_bar.z_index = 0
	health_bar.z_index = 1

	delayed_health_bar.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	health_bar.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	stamina_bar.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	health_bar.show_percentage = false
	delayed_health_bar.show_percentage = false
	stamina_bar.show_percentage = false

	health_bar.min_value = 0.0
	delayed_health_bar.min_value = 0.0
	stamina_bar.min_value = 0.0

	# Фон передней красной полосы обязан быть прозрачным.
	# Иначе он полностью закрывает жёлтую отложенную полосу позади.
	health_bar.add_theme_stylebox_override(
		"background",
		_create_style(
			Color(0.0, 0.0, 0.0, 0.0),
			Color(0.0, 0.0, 0.0, 0.0),
			0
		)
	)

	health_bar.add_theme_stylebox_override(
		"fill",
		_create_style(
			Color("#b71924"),
			Color("#541017"),
			2
		)
	)

	delayed_health_bar.add_theme_stylebox_override(
		"background",
		_create_style(
			Color("#241518"),
			Color("#080507"),
			2
		)
	)

	delayed_health_bar.add_theme_stylebox_override(
		"fill",
		_create_style(
			Color("#e0aa55"),
			Color("#805b25"),
			2
		)
	)

	stamina_bar.add_theme_stylebox_override(
		"background",
		_create_style(
			Color("#152019"),
			Color("#080c09"),
			2
		)
	)

	stamina_bar.add_theme_stylebox_override(
		"fill",
		_create_style(
			Color("#56a947"),
			Color("#254d20"),
			2
		)
	)


## Создаёт стиль полосы с рамкой.
func _create_style(
	fill_color: Color,
	border_color: Color,
	border_width: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = fill_color

	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width

	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2

	return style


## Синхронизирует HUD с текущими значениями игрока.
func _sync_from_player(player: Node) -> void:
	var current_health_value: Variant = (
		player.get("current_health")
	)

	var max_health_value: Variant = (
		player.get("max_health")
	)

	var current_stamina_value: Variant = (
		player.get("current_stamina")
	)

	var max_stamina_value: Variant = (
		player.get("max_stamina")
	)

	if (
		current_health_value != null
		and max_health_value != null
	):
		_on_health_changed(
			int(current_health_value),
			int(max_health_value)
		)

	if (
		current_stamina_value != null
		and max_stamina_value != null
	):
		_on_stamina_changed(
			float(current_stamina_value),
			float(max_stamina_value)
		)


## Обновляет здоровье игрока.
func _on_health_changed(
	current_health: int,
	maximum_health: int
) -> void:
	if maximum_health <= 0:
		return

	health_bar.max_value = maximum_health
	delayed_health_bar.max_value = maximum_health

	var new_health: float = clampf(
		float(current_health),
		0.0,
		float(maximum_health)
	)
	var old_health: float = health_bar.value

	if _health_tween != null and _health_tween.is_valid():
		_health_tween.kill()

	# При первом заполнении и при лечении обе полосы обновляются сразу.
	if new_health >= old_health:
		health_bar.value = new_health
		delayed_health_bar.value = new_health
		return

	# Красная полоса падает сразу. Жёлтая сохраняет старое значение,
	# поэтому становится видна в освободившейся части, затем плавно догоняет.
	delayed_health_bar.value = maxf(delayed_health_bar.value, old_health)
	health_bar.value = new_health

	_health_tween = create_tween()
	_health_tween.tween_interval(damage_hold_duration)
	_health_tween.tween_property(
		delayed_health_bar,
		"value",
		new_health,
		damage_fall_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## Обновляет выносливость игрока.
func _on_stamina_changed(
	current_stamina: float,
	maximum_stamina: float
) -> void:
	if maximum_stamina <= 0.0:
		return

	stamina_bar.max_value = maximum_stamina

	stamina_bar.value = clampf(
		current_stamina,
		0.0,
		maximum_stamina
	)


## Собирает затемнение с надписью и кнопкой возрождения.
func _create_death_screen() -> void:
	_death_screen = ColorRect.new()
	_death_screen.name = "DeathScreen"
	_death_screen.color = Color(0.05, 0.02, 0.03, 0.78)

	_death_screen.set_anchors_preset(
		Control.PRESET_FULL_RECT
	)

	# Перехватываем клики, чтобы нельзя было копать мёртвым.
	_death_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	_death_screen.visible = false

	add_child(_death_screen)

	var centerer := CenterContainer.new()

	centerer.set_anchors_preset(
		Control.PRESET_FULL_RECT
	)

	centerer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death_screen.add_child(centerer)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER

	column.add_theme_constant_override(
		"separation",
		20
	)

	centerer.add_child(column)

	var title := Label.new()
	title.text = "ВЫ ПОГИБЛИ"

	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	title.add_theme_color_override(
		"font_color",
		Color("#b71924")
	)

	title.add_theme_color_override(
		"font_outline_color",
		Color(0.0, 0.0, 0.0, 1.0)
	)

	title.add_theme_constant_override(
		"outline_size",
		6
	)

	title.add_theme_font_size_override(
		"font_size",
		46
	)

	column.add_child(title)

	var respawn_button := Button.new()
	respawn_button.text = "Возродиться"

	respawn_button.custom_minimum_size = Vector2(
		240.0,
		52.0
	)

	respawn_button.add_theme_font_size_override(
		"font_size",
		18
	)

	respawn_button.pressed.connect(
		_on_respawn_pressed
	)

	column.add_child(respawn_button)


## Показывает экран смерти.
func _on_player_died() -> void:
	if _death_screen == null:
		return

	_death_screen.modulate.a = 0.0
	_death_screen.visible = true

	var fade_tween := _death_screen.create_tween()

	fade_tween.tween_property(
		_death_screen,
		"modulate:a",
		1.0,
		0.5
	)


func _on_respawn_pressed() -> void:
	if _death_screen != null:
		_death_screen.visible = false

	if _player != null and _player.has_method("respawn"):
		_player.respawn()
