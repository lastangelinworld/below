extends Area2D
class_name ShieldBlock

## Физическая защита щита (и скрещённых рук). Перехватывает чужие
## Hitbox и стрелы, когда удерживается блок.
##
## Механика «фильтра»: касание щита помечает входящий Hitbox флагом
## _shield_blocked — Hitbox тогда не наносит урон, даже если его форма
## уже пересекла Hurtbox цели. Стрелы уничтожаются сразу, не долетая
## до тела. Логика урона (парирование, стамина, поиз) остаётся в
## take_damage() игрока: щит лишь даёт физическому объекту «упереться»
## в защиту, а не пройти сквозь неё.
##
## Узел живёт в корне персонажа (без масштаба рига), но каждый кадр
## переезжает в мировую позицию ShieldSprite — спрайта щита в руке.
## Так коллизия точно совпадает с видимым щитом и двигается с анимацией,
## а размеры формы задаются в привычных мировых пикселях.

## Форма защиты: вертикальная capsule примерно с щит (спрайт ~45 px).
## Раньше capsule была 26×88 px и висела в воздухе перед игроком —
## теперь она ровно на спрайте.
const SHIELD_RADIUS: float = 15.0
const SHIELD_HEIGHT: float = 20.0

## Смещение формы назад к телу: спрайт щита чуть выставлен вперёд,
## а защита должна прикрывать ещё и край торса.
const SHIELD_INWARD: float = 4.0

const SHIELD_SPRITE_PATH: String = "Visuals/BodyBreath/FrontArmAim/FrontArmAttack/FrontElbow/FrontWrist/ShieldSocket/ShieldSprite"

var _player: CharacterBody2D = null
var _shield_anchor: Node2D = null
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

	var capsule := CapsuleShape2D.new()
	capsule.radius = SHIELD_RADIUS
	capsule.height = SHIELD_HEIGHT
	_shape = CollisionShape2D.new()
	_shape.shape = capsule
	add_child(_shape)


func setup(player: CharacterBody2D) -> void:
	_player = player
	if _player != null:
		_shield_anchor = _player.get_node_or_null(SHIELD_SPRITE_PATH) as Node2D


## Коллизия следует за видимым щитом: он живёт в анимированной руке
## (масштаб рига 0.1), поэтому координату берём в мире и переносим
## сюда, в немасштабированный корень персонажа.
func _physics_process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player) or _shape == null:
		return
	if _shield_anchor == null or not is_instance_valid(_shield_anchor):
		return

	var anchor: Vector2 = _shield_anchor.global_position
	var direction: float = float(_player.get("facing"))
	global_position = anchor + Vector2(SHIELD_INWARD * direction, 0.0)


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
