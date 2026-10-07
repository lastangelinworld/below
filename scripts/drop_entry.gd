class_name DropEntry
extends Resource


@export var item_id: StringName = &""
@export_range(0.0, 1.0, 0.01) var probability: float = 1.0
@export_range(1, 999, 1) var minimum_amount: int = 1
@export_range(1, 999, 1) var maximum_amount: int = 1


func roll(random_generator: RandomNumberGenerator) -> int:
	if item_id == &"" or random_generator == null:
		return 0
	if random_generator.randf() > clampf(probability, 0.0, 1.0):
		return 0
	var minimum: int = mini(minimum_amount, maximum_amount)
	var maximum: int = maxi(minimum_amount, maximum_amount)
	return random_generator.randi_range(maxi(minimum, 1), maxi(maximum, 1))
