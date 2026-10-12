# Машина состояний игрока: единый источник правды для анимационно-боевых
# состояний. Блокирует недопустимые переходы (например, атака из стаггера).
class_name PlayerStateMachine
extends Node

# Все состояния, различаемые боевой логикой.
enum State {
    IDLE,
    RUN,
    SPRINT,
    ATTACK,
    BLOCK,
    PARRY,
    DODGE,
    STAGGER,
    DEAD,
}

signal state_changed(previous: State, current: State)

var current: State = State.IDLE

# Таблица разрешённых переходов: ключ — состояние, значение — допустимые цели.
# DEAD достижим из любого состояния (смерть прерывает всё).
const _TRANSITIONS := {
    State.IDLE: [State.RUN, State.SPRINT, State.ATTACK, State.BLOCK, State.PARRY, State.DODGE, State.STAGGER, State.DEAD],
    State.RUN: [State.IDLE, State.SPRINT, State.ATTACK, State.BLOCK, State.PARRY, State.DODGE, State.STAGGER, State.DEAD],
    State.SPRINT: [State.IDLE, State.RUN, State.ATTACK, State.BLOCK, State.PARRY, State.DODGE, State.STAGGER, State.DEAD],
    State.ATTACK: [State.IDLE, State.RUN, State.BLOCK, State.PARRY, State.DODGE, State.STAGGER, State.DEAD],
    State.BLOCK: [State.IDLE, State.RUN, State.PARRY, State.STAGGER, State.DEAD],
    State.PARRY: [State.IDLE, State.RUN, State.BLOCK, State.STAGGER, State.DEAD],
    State.DODGE: [State.IDLE, State.RUN, State.ATTACK, State.STAGGER, State.DEAD],
    State.STAGGER: [State.IDLE, State.RUN, State.DEAD],
    State.DEAD: [],
}

# Модификатор скорости восстановления стамины по состоянию: реализует
# требование «regen_rate модифицируется состоянием».
const _REGEN_MODIFIER := {
    State.IDLE: 1.0,
    State.RUN: 0.5,
    State.SPRINT: 0.0,
    State.ATTACK: 0.0,
    State.BLOCK: 0.25,
    State.PARRY: 0.5,
    State.DODGE: 0.0,
    State.STAGGER: 0.0,
    State.DEAD: 0.0,
}

# Можно ли перейти в target из текущего состояния.
func can_change_to(target: State) -> bool:
    if target == current:
        return false
    var allowed: Array = _TRANSITIONS.get(current, [])
    return target in allowed

# Пытается сменить состояние; возвращает true, если переход разрешён.
func change_to(target: State) -> bool:
    if not can_change_to(target):
        return false
    var previous: State = current
    current = target
    state_changed.emit(previous, current)
    return true

# Принудительный переход без проверки (смерть/внешние прерывания).
func force_change(target: State) -> void:
    if target == current:
        return
    var previous: State = current
    current = target
    state_changed.emit(previous, current)

func is_alive() -> bool:
    return current != State.DEAD

# Модификатор регена стамины для текущего состояния.
func regen_modifier() -> float:
    return _REGEN_MODIFIER.get(current, 0.0)
