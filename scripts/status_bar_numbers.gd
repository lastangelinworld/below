class_name StatusBarNumbers
extends Node
var player: Node
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	call_deferred("_find_player")
func _find_player() -> void:
	player=get_tree().get_first_node_in_group("player")
	if player == null: player=get_tree().current_scene.find_child("Player",true,false)
func _process(_delta: float) -> void:
	if player == null: _find_player()
	_update_bars(get_tree().root)
func _update_bars(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Range:
			var n:=child.name.to_lower()
			if "health" in n or "stamina" in n or "здоров" in n or "выносл" in n: _set_number(child as Range)
		_update_bars(child)
func _set_number(bar: Range) -> void:
	var label:=bar.get_node_or_null("BelowValueLabel") as Label
	if label == null:
		label=Label.new(); label.name="BelowValueLabel"; label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_outline_color",Color.BLACK); label.add_theme_constant_override("outline_size",3); bar.add_child(label)
	label.text="%d/%d" % [roundi(bar.value),roundi(bar.max_value)]
