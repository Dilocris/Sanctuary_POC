extends RefCounted
class_name AiController

func get_next_action(boss: Boss, battle_state: Dictionary) -> Dictionary:
	var target_id = _select_first_alive(battle_state.get("party", []))
	if target_id == "":
		return ActionFactory.skip_turn(boss.id)
	return ActionFactory.basic_attack(boss.id, target_id, 1.0)


func _select_first_alive(party: Array) -> String:
	for member in party:
		if member.hp_current > 0:
			return member.id
	return ""
