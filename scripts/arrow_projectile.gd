class_name ArrowProjectile
extends RigidBody2D

## Костяной снаряд, выпущенный луком скелета-лучника.
## Только физическое тело: у RigidBody2D нет monitoring/area_entered,
## они есть у Area2D — отсюда прежняя парсер-ошибка.

const SPEED: float = 300.0
const DAMAGE: int = 3
const LIFETIME: float = 3.0
const TOOL_LEVEL: int = 2
const POISE_DAMAGE: float = 3.0

var _direction: Vector2 = Vector2.RIGHT
var _lifetime: float = LIFETIME
var _damage: int = DAMAGE
var _poise_damage: float = POISE_DAMAGE
var _terrain: TerrainLayer = null


func setup(
	start_pos: Vector2,
	dir: Vector2,
	damage: int,
	poise_dmg: float = POISE_DAMAGE
) -> void:
	_direction = dir.normalized()
	_damage = damage
	_poise_damage = poise_dmg
	_lifetime = LIFETIME
	_terrain = CombatLayers.find_terrain()

	global_position = start_pos

	# Скорость задаётся напрямую: apply_central_impulse к телу
	# с выключенной гравитацией нестабилен на первом кадре.
	linear_velocity = _direction * SPEED

	# Локальная «вперёд» снаряда — ось -Y (остриё смотрит вверх).
	rotation = _direction.angle() + PI * 0.5


func _ready() -> void:
	# Без contact_monitor сигнал body_entered не приходит.
	contact_monitor = true
	max_contacts_reported = 4

	collision_layer = 4
	collision_mask = 3

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()
		return
	_check_terrain_hit()


## Проверяет клетку тайлмапа под стрелой и, если там блок,
## наносит урон через существующий механизм мира.
func _check_terrain_hit() -> void:
	if _terrain == null or _terrain.tile_set == null:
		return
	var local_pos: Vector2 = _terrain.to_local(global_position)
	var cell: Vector2i = _terrain.local_to_map(local_pos)
	if _terrain.get_block_type_at_cell(cell) == null:
		return
	# Блок есть — наносим урон и останавливаем снаряд.
	_terrain.request_damage_block(cell, global_position, TOOL_LEVEL, _damage)
	queue_free()


func _on_body_entered(body: Node) -> void:
	if body is ArrowProjectile:
		return

	if body.is_in_group("enemy"):
		return

	if body.has_method("take_damage"):
		body.call("take_damage", _damage, global_position, self, false, _poise_damage)

	queue_free()
