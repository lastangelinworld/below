class_name StaminaComponent
extends Node

## Компонент выносливости: единственный владелец запаса стамины.
## Узел живёт внутри Player; Player хранит публичный API (spend_stamina,
## _update_stamina, сигнал stamina_changed), а данные и математика здесь.

## Отдаёт игровое время в секундах. Ставится из Player, чтобы задержки
## восстановления использовали ту же шкалу, что и остальная логика.
var time_source: Callable = Callable()

## Максимальный запас.
var max_stamina: float = 100.0

## Скорость восстановления в секунду.
var regeneration_per_second: float = 20.0

## Задержка восстановления после расхода (секунды).
var regeneration_delay: float = 0.8

## Множитель скорости восстановления (0..1): задаётся состоянием игрока.
var regeneration_multiplier: float = 1.0

## Множитель восстановления от нагрузки брони (Фаза 5): 0..1.
## Держится отдельно от regeneration_multiplier, потому что состояние
## и снаряжение влияют на реген независимо и перемножаются.
var encumbrance_multiplier: float = 1.0

## Текущий запас.
var current: float = 100.0

## Момент времени, раньше которого восстановление не начинается.
var regeneration_allowed_at: float = 0.0

## Флаг смерти: при true расход запрещён.
var is_dead_provider: Callable = Callable()


func _ready() -> void:
	current = clampf(max_stamina, 0.0, max_stamina)


## Применяет настройки из Player (экспорт-значения).
func configure(new_max: float, new_regen: float, new_delay: float) -> void:
	max_stamina = new_max
	regeneration_per_second = new_regen
	regeneration_delay = new_delay
	current = clampf(current, 0.0, max_stamina)


## Игровое время в секундах через time_source (или 0.0).
func _now() -> float:
	if time_source.is_valid():
		return float(time_source.call())
	return 0.0


## Запрещён ли расход (смерть).
func _is_dead() -> bool:
	if is_dead_provider.is_valid():
		return bool(is_dead_provider.call())
	return false


## Восстанавливать ли прямо сейчас.
func _can_regen() -> bool:
	return _now() >= regeneration_allowed_at


## Откладывает восстановление на regeneration_delay.
func _schedule_refill() -> void:
	regeneration_allowed_at = _now() + regeneration_delay


## Пытается потратить amount. true — успех.
func spend(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if _is_dead() or current < amount:
		return false
	current = clampf(current - amount, 0.0, max_stamina)
	_schedule_refill()
	return true


## Списывает столько, сколько есть (спринт, «пробитый» блок).
## Возвращает фактически списанное количество.
func drain(amount: float) -> float:
	if amount <= 0.0 or _is_dead():
		return 0.0

	var spent: float = minf(amount, current)
	if spent <= 0.0:
		return 0.0

	current = clampf(current - spent, 0.0, max_stamina)
	_schedule_refill()
	return spent


## Возвращает amount (например, отмена действия).
func refund(amount: float) -> void:
	if amount <= 0.0:
		return
	current = clampf(current + amount, 0.0, max_stamina)


## Тик восстановления. Возвращает true, если запас изменился.
func tick(delta: float) -> bool:
	if current >= max_stamina:
		return false
	if not _can_regen():
		return false
	var rate: float = (
		regeneration_per_second * regeneration_multiplier * encumbrance_multiplier
	)
	if rate <= 0.0:
		return false
	var previous: float = current
	current = move_toward(current, max_stamina, rate * delta)
	return not is_equal_approx(previous, current)


## Полный запас (респавн/начало).
func restore_full() -> void:
	current = clampf(max_stamina, 0.0, max_stamina)
	regeneration_allowed_at = 0.0


## Есть ли запас для условия (спринт).
func has_for_sprint() -> bool:
	return current > 0.0
