class_name PoiseComponent
extends Node

## Компонент поиза (устойчивости к стаггеру).
## Принимает урон, снижает current_poise; при ≤0 активирует
## состояние STAGGER на stagger_duration секунд. После окончания
## стаггера и 2 секунд покоя (без входящего урона) poise
## восстанавливается до max_poise.

signal poise_changed(current: float, maximum: float)
signal stagger_started(duration: float)
signal stagger_ended()

@export_group("Параметры поиза")
## Максимальный запас поиза.
@export_range(10, 500, 1) var max_poise: float = 100.0

## Скорость восстановления поиза (единиц в секунду) после
## окончания стаггера и 2 секунд покоя.
@export_range(0.0, 50.0, 0.5) var poise_regen_per_second: float = 50.0

@export_group("Стаггер")
## Длительность стаггера в секундах.
@export_range(0.5, 5.0, 0.1) var stagger_duration: float = 1.5

## Задержка покоя перед восстановлением поиза (секунды).
@export_range(0.0, 5.0, 0.1) var recovery_delay: float = 2.0

## Провайдер: «мертв ли владелец». Если null — проверка
## по is_staggered() (стаггер сам по себе не убивает).
var is_dead_provider: Callable = func() -> bool: return false

var current_poise: float = 100.0
var _stagger_timer: float = 0.0
var _last_hit_time: float = 0.0
var _time_source: Callable = func() -> float: return 0.0


## Установить источник времени (обычно _get_game_time_seconds).
func configure(time_source: Callable) -> void:
	_time_source = time_source


## Применить поиз-урон от удара. Если current_poise ≤ 0 —
## активируется стаггер. Возвращает true, если стаггер сработал.
func apply_damage(amount: float) -> bool:
	if amount <= 0 or is_dead_provider.call():
		return false

	current_poise = maxf(0.0, current_poise - amount)
	_last_hit_time = _time_source.call()
	poise_changed.emit(current_poise, max_poise)

	if current_poise <= 0.0 and _stagger_timer <= 0.0:
		_enter_stagger()
		return true

	return false


## Обновление каждый тик: стаггер-таймер, восстановление поиза.
func tick(delta: float) -> bool:
	if _stagger_timer > 0.0:
		_stagger_timer = maxf(0.0, _stagger_timer - delta)
		if _stagger_timer <= 0.0:
			stagger_ended.emit()
			return true
		return false

	# Восстановление поиза: только если прошло recovery_delay
	# секунд с последнего получения урона.
	var time_since_hit: float = _time_source.call() - _last_hit_time
	if time_since_hit >= recovery_delay:
		current_poise = minf(max_poise, current_poise + poise_regen_per_second * delta)
		poise_changed.emit(current_poise, max_poise)

	return false


## Принудительно активировать стаггер (например, от парирования).
func apply_stagger(duration: float) -> void:
	_enter_stagger(duration)


func _enter_stagger(duration: float = -1.0) -> void:
	var target_duration: float = duration if duration > 0.0 else stagger_duration
	_stagger_timer = maxf(_stagger_timer, target_duration)
	stagger_started.emit(_stagger_timer)


## Находится ли владелец в стаггере.
func is_staggered() -> bool:
	return _stagger_timer > 0.0


## Полностью восстановить поиз (возрождение и т.п.).
func restore_full() -> void:
	current_poise = max_poise
	_stagger_timer = 0.0
	_last_hit_time = 0.0
	poise_changed.emit(current_poise, max_poise)
