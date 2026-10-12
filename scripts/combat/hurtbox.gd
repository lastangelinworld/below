class_name Hurtbox
extends Area2D

## Получающая область существа или объекта. Висит поверх тела
## (или вместо него) и пробрасывает полученный от Hitbox урон
## владельцу через его take_damage(), поэтому источник урона
## может быть любым: меч, стрела, взрыв.

## Кто принимает урон: узел с методом take_damage(amount, source).
## Если не назначен в Inspector, берётся родительский узел.
@export var owner_body: Node

## Позиция последнего попадания — пригодается для отклика
## (цифры урона, частицы) точно в месте касания.
var last_hit_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	collision_layer = CombatLayers.HURTBOX
	# Целимся только в hitbox'ы: получать «вход» от чужих
	# получающих областей незачем.
	collision_mask = CombatLayers.HITBOX
	monitoring = false

	if owner_body == null:
		owner_body = get_parent()


func receive_hit(hitbox: Hitbox) -> void:
	if owner_body == null or not is_instance_valid(owner_body):
		return
	if not owner_body.has_method("take_damage"):
		return

	last_hit_position = hitbox.global_position

	# Бонусный урон Salt and Sanctuary считается здесь, а не в целях:
	# тогда удар «в спину» и казнь цели в стаггере работают одинаково
	# для любого оружия, бьющего через Hitbox (кирка, меч).
	# Позиция формы удара — точка отсчёта: она ближе всего к месту касания.
	var multiplier: float = BackstabRules.multiplier(
		hitbox.global_position, owner_body
	)
	var final_damage: int = maxi(1, int(roundf(float(hitbox.damage) * multiplier)))

	# Поиз-урон: 0 в hitbox означает «не задано» — тогда равновесие
	# цели трясётся пропорционально финальному урону удара.
	var poise_dmg: float = hitbox.poise_damage
	if poise_dmg <= 0.0:
		poise_dmg = float(final_damage)

	# Третьим аргументом передаём владельца удара: цели (игрок) нужен
	# сам атакующий, чтобы при парировании ввести его в стаггер.
	# Четвёртым — признак бонусного удара: цель показывает его
	# отдельной цифрой урона.
	# Пятым — поиз-урон: цель применяет его к своему PoiseComponent.
	# Шестым — «ломает блок»: тяжёлый удар нельзя парировать, и щит
	# под ним пробивается.
	owner_body.call(
		"take_damage",
		final_damage,
		hitbox.global_position,
		hitbox.source_owner,
		multiplier > 1.0,
		poise_dmg,
		hitbox.breaks_block
	)
