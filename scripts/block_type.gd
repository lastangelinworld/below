class_name BlockType
extends Resource


@export_group("Identity")
@export var block_id: StringName = &""
@export var display_name: String = "Блок"

@export_group("Tile")
@export var source_id: int = 0
@export var atlas_coordinates: Vector2i = Vector2i.ZERO

@export_group("Physics")
@export var solid: bool = true
@export var affected_by_gravity: bool = false
@export_range(0.0, 10.0, 0.05) var movement_speed_multiplier: float = 1.0
@export_range(0.0, 10.0, 0.05) var vertical_speed_multiplier: float = 1.0
@export_range(0.0, 10.0, 0.05) var animation_speed_multiplier: float = 1.0

@export_group("Mining")
@export var breakable: bool = true
@export_range(1, 100000, 1) var max_health: int = 1
@export_range(0, 99, 1) var required_tool_level: int = 0
## Уровень шума от одного удара. Используется отладочным курсором и будущей системой ИИ.
@export_range(0, 1000, 1) var noise_per_hit: int = 0
@export var break_particle_color: Color = Color(0.65, 0.65, 0.65, 1.0)

@export_group("Drops")
@export var drops: Array[DropEntry] = []
## Устаревший одиночный дроп. Используется, только если Drops пуст.
@export var drop_item_id: StringName = &""
@export_range(0, 999, 1) var drop_amount: int = 0

@export_group("Hazard")
@export var is_hazard: bool = false
@export_range(0, 10000, 1) var contact_damage: int = 0
@export_range(0.05, 10.0, 0.05) var contact_damage_interval: float = 0.75
