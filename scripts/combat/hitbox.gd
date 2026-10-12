class_name Hitbox
extends Area2D

## Активная область удара оружия (меч, кирка, край щита).
## По умолчанию «молчит»: monitoring включается только на окно
## замаха через activate(), поэтому урон возможен ровно тогда,
## когда форма оружия реально движется в момент удара.

## Удар реально достиг цели (не своего владельца, не задетой ранее).
## Владелец оружия подключается к нему, чтобы начислить опыт навыка:
## махать оружием вхолостую — не тренировка.
signal hit_landed(target: Node)

## Урон, передаваемый цели при касании её Hurtbox.
@export var damage: int = 1

## Поиз-урон удара: насколько цель «теряет равновесие».
## 0 означает «не задано» — тогда Hurtbox снимает поиз, равный
## финальному урону. Тяжёлое оружие выставляет значение больше.
@export var poise_damage: float = 0.0

## Тяжёлый удар (Фаза 7): щит его не парирует, а попытка держать блок
## заканчивается пробитием. Такие удары читаются по длинному телеграфу
## и требуют уклонения, а не щита.
@export var breaks_block: bool = false

## Уровень инструмента — его проверяют блоки при уроне.
@export var tool_level: int = 1

## Длительность окна поражения в секундах (если не передана явно).
@export var activation_seconds: float = 0.12

## Владелец удара: собственный Hurtbox владельца не поражается.
var source_owner: Node

## Увеличивается при каждом замахе, чтобы отменять «деактивацию»
## от уже устаревшего окна.
var _activation_id: int = 0

## true только внутри окна поражения. monitoring при этом всегда
## включён: тогда get_overlapping_areas() в activate() видит цели,
## которые УЖЕ внутри формы в момент замаха, а area_entered ловит
## тех, кто вошёл позже.
var _active: bool = false

## Hurtbox, уже задетые текущим ударом: один замах — один урон
## в одну цель, даже если области пересекаются несколько кадров.
var _already_hit: Array[Hurtbox] = []


func _ready() -> void:
	collision_layer = CombatLayers.HITBOX
	collision_mask = CombatLayers.HURTBOX
	# Hitbox сам ничего не «слушает» и не нужен другим как цель:
	# только включённый на замах monitoring генерирует события.
	monitorable = false
	# monitoring включён постоянно: урон гейтит _active. Иначе при
	# включении monitoring в момент замаха area_entered НЕ приходит
	# для целей, которые уже внутри формы (Godot шлёт его только
	# при новом вхождении), и удар «промахивается» в упор.
	monitoring = true
	area_entered.connect(_on_area_entered)


## Открывает окно поражения: форма оружия активна seconds секунд.
## Новый замах сбрасывает список задетых целей.
func activate(seconds: float = -1.0) -> void:
	if seconds > 0.0:
		activation_seconds = seconds

	_already_hit.clear()
	_activation_id += 1
	_active = true

	# Цели, уже внутри формы в момент замаха: area_entered для них
	# не сработает (вхождения не было), поэтому поражаем сразу.
	# get_overlapping_areas() корректен, потому что monitoring
	# включён с самого _ready().
	for area: Area2D in get_overlapping_areas():
		_on_area_entered(area)

	var timer: SceneTreeTimer = get_tree().create_timer(activation_seconds)
	timer.timeout.connect(_deactivate.bind(_activation_id))


func _deactivate(own_id: int) -> void:
	if own_id == _activation_id:
		_active = false


## Принудительно закрыть окно поражения: нужно, когда владелец
## умирает в разгар замаха — «мёртвый» клинок бить не должен.
func deactivate() -> void:
	_activation_id += 1
	_active = false


func _on_area_entered(area: Area2D) -> void:
	if not _active:
		return

	var hurt: Hurtbox = area as Hurtbox
	if hurt == null:
		return
	if hurt.owner_body == null or hurt.owner_body == source_owner:
		return
	if _already_hit.has(hurt):
		return

	_already_hit.append(hurt)
	hurt.receive_hit(self)
	hit_landed.emit(hurt.owner_body)
