class_name SkillsComponent
extends Node

## Компонент навыков персонажа (Фаза 6).
## Уровни навыков растут за счёт опыта, полученного при ударах,
## блокировании и уклонении. Каждый навык влияет на определённый
## аспект боя: урон, скорость, эффективность блока.


## Навык поднял уровень: интерфейс показывает подсказку.
signal level_changed(skill: int, new_level: int)


## Названия навыков для сохранения.
enum Skill {
	SWORDS,      # Мечи и подобное (железный меч)
	AXES,         # Топоры и кирки
	BLUNT,        # Дубины, молоты, тяжёлое оружие
	BLOCKING,     # Эффективность блока и парирования
	DODGE,        # Стоимость и длительность уклонения
	RUN,          # Скорость спринта и дальность ролла
}


## Отображаемые имена навыков.
const SKILL_NAMES: Dictionary = {
	Skill.SWORDS: "Мечи",
	Skill.AXES: "Топоры",
	Skill.BLUNT: "Тяжёлое",
	Skill.BLOCKING: "Блок",
	Skill.DODGE: "Уклонение",
	Skill.RUN: "Бег",
}


## Базовая кривая опыта: level^2 × 50 — растёт квадратично.
const XP_BASE: float = 50.0
const XP_POWER: float = 2.0

## Множитель урона за уровень навыка.
const DAMAGE_PER_LEVEL: float = 0.04

## Множитель окна парирования за уровень (сек).
const PARRY_WINDOW_PER_LEVEL: float = 0.03

## Множитель экономии стамины при блоке за уровень.
const BLOCK_STAMINA_REDUCTION_PER_LEVEL: float = 0.03

## Множитель скорости спринта за уровень.
const SPRINT_SPEED_PER_LEVEL: float = 0.03

## Множитель дальности ролла за уровень.
const DODGE_RANGE_PER_LEVEL: float = 0.05

## Множитель снижения стоимости ролла за уровень.
const DODGE_COST_REDUCTION_PER_LEVEL: float = 0.03


var _current_level: Dictionary = {}
var _xp: Dictionary = {}
var _total_xp: float = 0.0
var _player: Node = null


## Инициализировать навыки с нулевыми уровнями.
func _init() -> void:
	for skill: int in Skill.values():
		_current_level[skill] = 0
		_xp[skill] = 0.0


## Подключиться к игроку для чтения базовых параметров.
func setup(player: Node) -> void:
	_player = player


## Получить текущий уровень навыка.
func get_level(skill: int) -> int:
	return _current_level.get(skill, 0)


## Получить текущий опыт в навыке.
func get_xp(skill: int) -> float:
	return _xp.get(skill, 0.0)


## Получить общий опыт по всем навыкам.
func get_total_xp() -> float:
	return _total_xp


## Добавить опыт в навык. Проверяет повышение уровня.
func add_xp(skill: int, amount: float) -> bool:
	if amount <= 0.0:
		return false

	_xp[skill] = _xp.get(skill, 0.0) + amount
	_total_xp += amount

	# Проверяем, не достигнут ли следующий уровень.
	_check_level_up(skill)
	return true


## Получить опыт, необходимый для следующего уровня.
func xp_to_next_level(skill: int) -> float:
	var level: int = _current_level.get(skill, 0)
	return _xp_required_for(level + 1) - _xp.get(skill, 0.0)


## Получить общий опыт, необходимый для следующего уровня любого навыка.
func total_xp_to_next_level() -> float:
	var min_xp: float = INF
	for skill: int in Skill.values():
		var needed: float = xp_to_next_level(skill)
		if needed < min_xp:
			min_xp = needed
	return maxf(min_xp, 0.0)


## Множитель урона для навыка: 1 + level × DAMAGE_PER_LEVEL.
func damage_multiplier(skill: int) -> float:
	var level: int = _current_level.get(skill, 0)
	return 1.0 + level * DAMAGE_PER_LEVEL


## Множитель окна парирования: base + level × PARRY_WINDOW_PER_LEVEL.
func parry_window_bonus(skill: int) -> float:
	var level: int = _current_level.get(skill, 0)
	return level * PARRY_WINDOW_PER_LEVEL


## Множитель экономии стамины при блоке: 1 − level × BLOCK_STAMINA_REDUCTION.
func block_stamina_multiplier(skill: int) -> float:
	var level: int = _current_level.get(skill, 0)
	return maxf(1.0 - level * BLOCK_STAMINA_REDUCTION_PER_LEVEL, 0.3)


## Множитель скорости спринта: 1 + level × SPRINT_SPEED_PER_LEVEL.
func sprint_speed_multiplier(skill: int) -> float:
	var level: int = _current_level.get(skill, 0)
	return 1.0 + level * SPRINT_SPEED_PER_LEVEL


## Множитель дальности ролла: 1 + level × DODGE_RANGE_PER_LEVEL.
func dodge_range_multiplier(skill: int) -> float:
	var level: int = _current_level.get(skill, 0)
	return 1.0 + level * DODGE_RANGE_PER_LEVEL


## Множитель снижения стоимости ролла: 1 − level × DODGE_COST_REDUCTION.
func dodge_cost_multiplier(skill: int) -> float:
	var level: int = _current_level.get(skill, 0)
	return maxf(1.0 - level * DODGE_COST_REDUCTION_PER_LEVEL, 0.3)


## Получить опыт, необходимый для достижения заданного уровня.
func _xp_required_for(level: int) -> float:
	return pow(float(level), XP_POWER) * XP_BASE


## Проверить и применить повышение уровня. Цикл, а не разовая
## проверка: одна крупная выдача опыта может перекинуть сразу через
## несколько порогов (200 XP за раз поднимает с 0-го на 2-й уровень).
## Сигнал шлётся один раз итоговым уровнем: интерфейс показывает
## финальную строку, а не каскад всплывашек.
func _check_level_up(skill: int) -> void:
	var previous: int = _current_level.get(skill, 0)
	var target: int = previous
	while _xp.get(skill, 0.0) >= _xp_required_for(target + 1):
		target += 1

	if target == previous:
		return

	_current_level[skill] = target
	level_changed.emit(skill, target)


## Сохранить состояние в словарь.
func save_state() -> Dictionary:
	var data := {}
	for skill: int in Skill.values():
		data[str(skill)] = {
			"level": _current_level.get(skill, 0),
			"xp": _xp.get(skill, 0.0),
		}
	data["total_xp"] = _total_xp
	return data


## Загрузить состояние из словаря.
func load_state(state: Dictionary) -> void:
	_total_xp = float(state.get("total_xp", 0.0))
	for raw_key: String in state.keys():
		if raw_key == "total_xp":
			continue
		var raw_index: int = raw_key.to_int()
		if not Skill.values().has(raw_index):
			continue
		var entry: Dictionary = state[raw_key]
		_current_level[raw_index] = int(entry.get("level", 0))
		_xp[raw_index] = float(entry.get("xp", 0.0))
