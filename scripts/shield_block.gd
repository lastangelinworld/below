extends Area2D
class_name ShieldBlock

## Физическая защита щита (и скрещённых рук). Висит перед персонажем
## и перехватывает чужие Hitbox и стрелы, когда удерживается блок.
##
## Механика «фильтра»: касание щита помечает входящий Hitbox флагом
## _shield_blocked — Hitbox тогда не наносит урон, даже если его форма
## уже пересекла Hurtbox цели. Стрелы уничтожаются сразу, не долетая
## до тела. Логика урона (парирование, стамина, поиз) остаётся в
## take_damage() игрока: щит лишь даёт физическому объекту «упереться»
## в защиту, а не пройти сквозь неё.

## Радиус capsule-формы защиты и её вынос вперёд от центра тела.
const SHIELD_RADIUS: float = 26.0
const SHIELD_FORWARD: float = 22.0

var _player: CharacterBody2D = null
var _shape: CollisionShape2D = null


func _ready() -> void:
	# Слой SHIELDBLOCK: на него «смотрят» хитбоксы врагов, чтобы
	# заметить защиту раньше, чем тело. Слушаем активные удары и
	# снаряды.
	collision_layer = CombatLayers.SHIELDBLOCK
	collision_mask = CombatLayers.HITBOX | CombatLayers.ARROW
	monitoring = true
	monitorable = true
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

	# Высокая capsule перед грудью: закрывает торс и голову,
	# но не землю под ногами и не спину.
	var capsule := CapsuleShape2D.new()
	capsule.radius = SHIELD_RADIUS
	capsule.height = SHIELD_RADIUS * 3.4
	_shape = CollisionShape2D.new()
	_shape.shape = capsule
	_shape.rotation = PI * 0.5
	add_child(_shape)


func setup(player: CharacterBody2D) -> void:
	_player = player


## Форма защиты всегда смотрит туда же, куда и персонаж: узел живёт
## в корне тела, поэтому зеркалим позицию вручную по facing.
func _physics_process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player) or _shape == null:
		return
	var direction: float = float(_player.get("facing"))
	_shape.position = Vector2(SHIELD_FORWARD * direction, -8.0)


func _on_area_entered(area: Area2D) -> void:
	if not is_blocking():
		return

	var hit: Hitbox = area as Hitbox
	if hit != null and hit.source_owner != _player:
		hit.mark_shield_blocked()


func _on_body_entered(body: Node) -> void:
	if not is_blocking():
		return

	# Стрела упёрлась в щит: исчезает без урона и без отскока.
	if body is ArrowProjectile:
		body.queue_free()


## Публичная проверка: блок активен и персонаж жив.
func is_blocking() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	return bool(_player.get("is_blocking")) and not bool(_player.get("is_dead"))


## Принадлежит ли защита этому телу — нужно Hitbox, чтобы не гасить
## удары по чужим целям щитом постороннего персонажа.
func is_owner(candidate: Node) -> bool:
	return candidate != null and candidate == _player
