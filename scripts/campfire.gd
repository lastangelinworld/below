extends Node2D
## Сценарий костра. Изображение костра задаётся только в campfire.tscn.
## Рисование через _draw() намеренно не используется, чтобы не было двойного огня.

@export var light_base_energy: float = 0.85
@export var light_flicker_amount: float = 0.12
@export var light_flicker_speed: float = 7.0

var _time: float = 0.0
@onready var light: PointLight2D = get_node_or_null("PointLight2D") as PointLight2D

func _ready() -> void:
	add_to_group("campfire")
	add_to_group("interactable")
	if light != null:
		light.energy = light_base_energy

func _process(delta: float) -> void:
	_time += delta
	if light != null:
		light.energy = light_base_energy + sin(_time * light_flicker_speed) * light_flicker_amount + sin(_time * 11.0) * 0.06
