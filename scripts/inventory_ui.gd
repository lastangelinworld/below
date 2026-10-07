class_name InventoryUI
extends CanvasLayer

@export var player_path: NodePath = NodePath("../Player")
@export var slot_scene: PackedScene
@export var pickup_scene: PackedScene = preload("res://data/items/item_pickup.tscn")

@onready var overlay: Control = $Overlay
@onready var inventory_window: Control = $Overlay/Center/InventoryWindow
@onready var main_grid: GridContainer = $Overlay/Center/InventoryWindow/Margin/Main/Content/PlayerColumn/MainInventoryGrid
@onready var inventory_hotbar_grid: GridContainer = $Overlay/Center/InventoryWindow/Margin/Main/Content/PlayerColumn/InventoryHotbarGrid
@onready var craft_grid: GridContainer = $Overlay/Center/InventoryWindow/Margin/Main/Content/CraftColumn/CraftRow/CraftGrid
@onready var result_holder: Control = $Overlay/Center/InventoryWindow/Margin/Main/Content/CraftColumn/CraftRow/ResultHolder
@onready var weight_bar: ProgressBar = $Overlay/Center/InventoryWindow/Margin/Main/WeightBar
@onready var weight_label: Label = $Overlay/Center/InventoryWindow/Margin/Main/WeightLabel
@onready var hotbar_grid: GridContainer = $HotbarHUD/Margin/VBox/HotbarGrid
@onready var selected_label: Label = $HotbarHUD/Margin/VBox/SelectedLabel
@onready var carry_preview: Control = $CarryPreview
@onready var carry_icon: TextureRect = $CarryPreview/Panel/Icon
@onready var carry_amount: Label = $CarryPreview/Panel/Amount

var player: Node
var inventory: InventoryData
var carried := ItemStack.new()
var craft_slots: Array[ItemStack] = []
var inventory_views: Array[InventorySlotUI] = []
var hotbar_views: Array[InventorySlotUI] = []
var inventory_hotbar_views: Array[InventorySlotUI] = []
var craft_views: Array[InventorySlotUI] = []
var result_view: InventorySlotUI
var selected_hotbar := 0
var hovered_inventory_slot := -1
var hovered_craft_slot := -1
var _previous_pause := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    add_to_group("inventory_ui")
    overlay.visible = false
    carry_preview.visible = false
    for i in range(9):
        craft_slots.append(ItemStack.new())
    call_deferred("_connect_player")

func _process(_delta: float) -> void:
    if carry_preview.visible:
        carry_preview.position = get_viewport().get_mouse_position() + Vector2(18, 18)

func _input(event: InputEvent) -> void:
    if _is_player_dead():
        return
    if event.is_action_pressed("toggle_inventory"):
        if overlay.visible:
            close_inventory()
        else:
            open_inventory()
        get_viewport().set_input_as_handled()
        return
    if overlay.visible and event.is_action_pressed("ui_cancel"):
        close_inventory()
        get_viewport().set_input_as_handled()
        return
    if overlay.visible and event.is_action_pressed("drop_item"):
        _drop_requested()
        get_viewport().set_input_as_handled()
        return
    if not overlay.visible and event is InputEventKey and event.pressed and not event.echo:
        var key := event as InputEventKey
        if key.keycode >= KEY_1 and key.keycode <= KEY_9:
            set_selected_hotbar(key.keycode - KEY_1)

func _is_player_dead() -> bool:
    var player := get_tree().get_first_node_in_group("player")
    if player == null:
        return false
    return bool(player.get("is_dead"))

func is_inventory_open() -> bool:
    return overlay.visible

func open_inventory() -> void:
    if inventory == null:
        _connect_player()
    if inventory == null:
        return
    _previous_pause = get_tree().paused
    overlay.visible = true
    get_tree().paused = true
    _refresh_all()

func close_inventory() -> void:
    _return_loose_items()
    overlay.visible = false
    get_tree().paused = _previous_pause

func set_selected_hotbar(index: int) -> void:
    selected_hotbar = clampi(index, 0, 8)
    if player != null:
        player.set_meta("selected_hotbar_index", selected_hotbar)
    _refresh_all()

func _connect_player() -> void:
    player = get_node_or_null(player_path)
    if player == null:
        player = get_tree().get_first_node_in_group("player")
    if player == null:
        push_error("InventoryUI: Player не найден")
        return
    inventory = player.get("inventory") as InventoryData
    if inventory == null:
        push_error("InventoryUI: у Player нет InventoryData")
        return
    if not inventory.changed.is_connected(_refresh_all):
        inventory.changed.connect(_refresh_all)
    player.set_meta("selected_hotbar_index", selected_hotbar)
    _build_views()
    _refresh_all()

func _new_view(index: int) -> InventorySlotUI:
    var view := slot_scene.instantiate() as InventorySlotUI
    view.setup(index)
    return view

func _clear(container: Node) -> void:
    for child in container.get_children():
        child.queue_free()

func _build_views() -> void:
    if slot_scene == null:
        push_error("InventoryUI: Slot Scene не назначена")
        return
    _clear(main_grid); _clear(inventory_hotbar_grid); _clear(hotbar_grid); _clear(craft_grid); _clear(result_holder)
    inventory_views.clear(); inventory_hotbar_views.clear(); hotbar_views.clear(); craft_views.clear()
    for i in range(27):
        var v := _new_view(i)
        main_grid.add_child(v)
        v.slot_pressed.connect(_on_inventory_slot_pressed)
        v.slot_hovered.connect(_on_inventory_hover)
        inventory_views.append(v)
    for i in range(9):
        var slot_index := 27 + i
        var inside := _new_view(slot_index)
        inventory_hotbar_grid.add_child(inside)
        inside.slot_pressed.connect(_on_inventory_slot_pressed)
        inside.slot_hovered.connect(_on_inventory_hover)
        inventory_hotbar_views.append(inside)
        var hud := _new_view(slot_index)
        hotbar_grid.add_child(hud)
        hud.slot_pressed.connect(func(_idx: int, _button: MouseButton): set_selected_hotbar(i))
        hotbar_views.append(hud)
    for i in range(9):
        var v := _new_view(i)
        craft_grid.add_child(v)
        v.slot_pressed.connect(_on_craft_slot_pressed)
        v.slot_hovered.connect(_on_craft_hover)
        craft_views.append(v)
    result_view = _new_view(0)
    result_holder.add_child(result_view)
    result_view.slot_pressed.connect(_on_result_pressed)

func _refresh_all() -> void:
    if inventory == null or inventory_views.is_empty():
        return
    for i in range(27):
        inventory_views[i].display_stack(inventory.get_slot(i))
    for i in range(9):
        inventory_hotbar_views[i].display_stack(inventory.get_slot(27 + i))
        hotbar_views[i].display_stack(inventory.get_slot(27 + i))
        inventory_hotbar_views[i].set_selected(i == selected_hotbar)
        hotbar_views[i].set_selected(i == selected_hotbar)
    var current := inventory.get_total_weight_kg()
    weight_bar.max_value = inventory.max_weight_kg
    weight_bar.value = current
    weight_label.text = "Вес: %.2f / %.2f кг" % [current, inventory.max_weight_kg]
    weight_label.modulate = Color("ff5b5b") if current >= inventory.max_weight_kg else (Color("ffc24d") if current >= inventory.max_weight_kg * 0.8 else Color.WHITE)
    var selected := inventory.get_slot(27 + selected_hotbar)
    if selected == null or selected.is_empty():
        selected_label.text = "%d — пусто" % (selected_hotbar + 1)
    else:
        var item: ItemData = ItemRegistry.get_item(selected.item_id)
        selected_label.text = "%d — %s × %d" % [selected_hotbar + 1, item.display_name if item else str(selected.item_id), selected.amount]
    _refresh_craft()
    _refresh_carried()

func _on_inventory_hover(index: int, entered: bool) -> void:
    hovered_inventory_slot = index if entered else (-1 if hovered_inventory_slot == index else hovered_inventory_slot)

func _on_craft_hover(index: int, entered: bool) -> void:
    hovered_craft_slot = index if entered else (-1 if hovered_craft_slot == index else hovered_craft_slot)

func _on_inventory_slot_pressed(index: int, button: MouseButton) -> void:
    _handle_stack_click(inventory.get_slot(index), button, func(): inventory.notify_changed(), func(amount: int): carried = inventory.take_from_slot(index, amount))

func _on_craft_slot_pressed(index: int, button: MouseButton) -> void:
    var target := craft_slots[index]
    _handle_stack_click(target, button, _refresh_all, func(amount: int): carried = _take_from_local(target, amount))

func _handle_stack_click(target: ItemStack, button: MouseButton, changed: Callable, take_callable: Callable) -> void:
    if carried.is_empty():
        if target == null or target.is_empty():
            return
        var amount := target.amount if button == MOUSE_BUTTON_LEFT else ceili(target.amount / 2.0)
        take_callable.call(amount)
        changed.call()
        _refresh_all()
        return
    if target == null:
        return
    if target.is_empty():
        var put := carried.amount if button == MOUSE_BUTTON_LEFT else 1
        target.item_id = carried.item_id
        target.amount = put
        carried.amount -= put
        _clear_if_empty(carried)
    elif target.item_id == carried.item_id:
        var item: ItemData = ItemRegistry.get_item(carried.item_id)
        var room := maxi((item.max_stack if item else 64) - target.amount, 0)
        var put := mini(room, carried.amount if button == MOUSE_BUTTON_LEFT else 1)
        target.amount += put
        carried.amount -= put
        _clear_if_empty(carried)
    elif button == MOUSE_BUTTON_LEFT:
        var old_id := target.item_id
        var old_amount := target.amount
        target.item_id = carried.item_id
        target.amount = carried.amount
        carried.item_id = old_id
        carried.amount = old_amount
    changed.call()
    _refresh_all()

func _take_from_local(stack: ItemStack, amount: int) -> ItemStack:
    var result := ItemStack.new()
    result.item_id = stack.item_id
    result.amount = mini(amount, stack.amount)
    stack.amount -= result.amount
    _clear_if_empty(stack)
    return result

func _clear_if_empty(stack: ItemStack) -> void:
    if stack.amount <= 0:
        stack.item_id = &""
        stack.amount = 0

func _recipe_matches() -> bool:
    var pattern: Array[StringName] = [&"", &"flint", &"", &"plank_scraps", &"plank_scraps", &"plank_scraps", &"", &"flint", &""]
    for i in range(9):
        var actual: StringName = &"" if craft_slots[i].is_empty() else craft_slots[i].item_id
        if actual != pattern[i]:
            return false
    return true

func _refresh_craft() -> void:
    for i in range(craft_views.size()):
        craft_views[i].display_stack(craft_slots[i])
    var output := ItemStack.new()
    if _recipe_matches():
        output.item_id = &"campfire"
        output.amount = 1
    if result_view != null:
        result_view.display_stack(output)

func _on_result_pressed(_index: int, button: MouseButton) -> void:
    if button != MOUSE_BUTTON_LEFT or not _recipe_matches():
        return
    var item: ItemData = ItemRegistry.get_item(&"campfire")
    var max_stack := item.max_stack if item else 16
    if not carried.is_empty() and (carried.item_id != &"campfire" or carried.amount >= max_stack):
        return
    if carried.is_empty():
        carried.item_id = &"campfire"
        carried.amount = 1
    else:
        carried.amount += 1
    for i in [1, 3, 4, 5, 7]:
        craft_slots[i].amount -= 1
        _clear_if_empty(craft_slots[i])
    _refresh_all()

func _refresh_carried() -> void:
    if carried.is_empty():
        carry_preview.visible = false
        carry_icon.texture = null
        carry_amount.text = ""
        return
    carry_preview.visible = true
    var item: ItemData = ItemRegistry.get_item(carried.item_id)
    carry_icon.texture = item.icon if item else null
    carry_amount.text = str(carried.amount)

func _drop_requested() -> void:
    if not carried.is_empty():
        _spawn_dropped(carried.item_id, carried.amount)
        carried = ItemStack.new()
    elif hovered_inventory_slot >= 0:
        var stack := inventory.take_from_slot(hovered_inventory_slot)
        if stack != null and not stack.is_empty():
            _spawn_dropped(stack.item_id, stack.amount)
    elif hovered_craft_slot >= 0:
        var stack := _take_from_local(craft_slots[hovered_craft_slot], craft_slots[hovered_craft_slot].amount)
        if not stack.is_empty():
            _spawn_dropped(stack.item_id, stack.amount)
    _refresh_all()

func _spawn_dropped(item_id: StringName, amount: int) -> void:
    if amount <= 0 or player == null or pickup_scene == null:
        return
    var pickup := pickup_scene.instantiate()
    get_tree().current_scene.add_child(pickup)
    pickup.global_position = player.global_position + Vector2(randf_range(-22.0, 22.0), -12.0)
    if pickup.has_method("setup"):
        pickup.setup(item_id, amount)
    if pickup.has_method("block_automatic_pickup"):
        pickup.block_automatic_pickup(1800.0)

func _return_loose_items() -> void:
    var loose: Array[ItemStack] = []
    if not carried.is_empty():
        loose.append(carried)
        carried = ItemStack.new()
    for stack in craft_slots:
        if not stack.is_empty():
            loose.append(stack)
    for i in range(9):
        craft_slots[i] = ItemStack.new()
    for stack in loose:
        var accepted := inventory.add_item(stack.item_id, stack.amount)
        if accepted < stack.amount:
            _spawn_dropped(stack.item_id, stack.amount - accepted)
    _refresh_all()
