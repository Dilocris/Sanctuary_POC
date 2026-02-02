extends RefCounted
class_name StatusEffect

var id: String
var duration: int
var value: int
var tags: Array


func _init(effect_id: String, turns: int = 0, effect_value: int = 0, effect_tags: Array = []) -> void:
	id = effect_id
	duration = turns
	value = effect_value
	tags = effect_tags.duplicate()


func is_expired() -> bool:
	return duration <= 0


func tick() -> void:
	duration -= 1
