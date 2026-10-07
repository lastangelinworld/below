class_name InventorySlotUI
extends PanelContainer

signal slot_pressed(slot_index: int, mouse_button: MouseButton)
signal slot_hovered(slot_index: int, entered: bool)

@onready var item_icon: TextureRect = $ItemMargin/ItemIcon
@onready var amount_label: Label = $AmountLabel
@onready var selection: Panel = $Selection
var slot_index := -1

func _ready() -> void:
    mouse_entered.connect(func(): slot_hovered.emit(slot_index, true))
    mouse_exited.connect(func(): slot_hovered.emit(slot_index, false))
    clear_display()

func setup(new_slot_index: int) -> void:
    slot_index = new_slot_index

func display_stack(stack: ItemStack) -> void:
    if stack == null or stack.is_empty():
        clear_display()
        return
    var item: ItemData = ItemRegistry.get_item(stack.item_id)
    item_icon.texture = item.icon if item != null else null
    amount_label.text = str(stack.amount) if stack.amount > 1 else ""
    if item == null:
        tooltip_text = "Неизвестный предмет: %s × %d" % [stack.item_id, stack.amount]
    else:
        tooltip_text = "%s\nКоличество: %d\nВес: %.2f кг" % [item.display_name, stack.amount, item.unit_weight_kg * stack.amount]

func clear_display() -> void:
    if not is_node_ready():
        return
    item_icon.texture = null
    amount_label.text = ""
    tooltip_text = "Пустая ячейка"

func set_selected(value: bool) -> void:
    if is_instance_valid(selection):
        selection.visible = value

func _gui_input(event: InputEvent) -> void:
    var mouse := event as InputEventMouseButton
    if mouse == null or not mouse.pressed:
        return
    if mouse.button_index == MOUSE_BUTTON_LEFT or mouse.button_index == MOUSE_BUTTON_RIGHT:
        slot_pressed.emit(slot_index, mouse.button_index)
        accept_event()
