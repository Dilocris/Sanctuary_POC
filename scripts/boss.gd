extends Character
class_name Boss

var phase: int = 1
var ability_cooldowns: Dictionary = {}
var last_action_id: String = ""


func setup(data: Dictionary) -> void:
	super.setup(data)
	phase = data.get("phase", phase)
	ability_cooldowns = data.get("ability_cooldowns", ability_cooldowns)
	last_action_id = data.get("last_action_id", last_action_id)
