extends RefCounted
class_name AiController

func get_next_action(boss: Boss, battle_state: Dictionary) -> Dictionary:
	_update_phase(boss)
	if boss.phase == 1:
		return _phase_one_action(boss, battle_state)

	var target_id = _select_first_alive(battle_state.get("party", []))
	if target_id == "":
		return ActionFactory.skip_turn(boss.id)
	return ActionFactory.basic_attack(boss.id, target_id, 1.0)


func _select_first_alive(party: Array) -> String:
	for member in party:
		if member.hp_current > 0:
			return member.id
	return ""


func _phase_one_action(boss: Boss, battle_state: Dictionary) -> Dictionary:
	var party = battle_state.get("party", [])
	if battle_state.flags.get("marcus_pull_target", "") != "":
		var pulled_id = battle_state.flags.marcus_pull_target
		battle_state.flags.marcus_pull_target = ""
		_increment_marcus_turn(battle_state)
		return ActionFactory.marcus_greataxe_slam(boss.id, pulled_id)

	var index = battle_state.flags.get("marcus_turn_index", 0) % 4
	_increment_marcus_turn(battle_state)

	match index:
		0:
			var target = _select_highest_threat(party)
			return ActionFactory.marcus_greataxe_slam(boss.id, target)
		1:
			var rand_target = _select_random(party)
			return ActionFactory.marcus_tendril_lash(boss.id, rand_target)
		2:
			return ActionFactory.marcus_battle_roar(boss.id)
		3:
			var grasp_target = _select_grasp_target(party)
			return ActionFactory.marcus_collectors_grasp(boss.id, grasp_target)

	return ActionFactory.skip_turn(boss.id)


func _select_highest_threat(party: Array) -> String:
	var ludwig = _find_by_id(party, "ludwig")
	if ludwig != null and ludwig.has_status(StatusEffectIds.GUARD_STANCE):
		return "ludwig"
	var best_id = ""
	var best_atk = -1
	for member in party:
		if member.hp_current <= 0:
			continue
		var atk = member.stats.get("atk", 0)
		if atk > best_atk:
			best_atk = atk
			best_id = member.id
	return best_id


func _select_grasp_target(party: Array) -> String:
	var candidates: Array = []
	var ludwig = _find_by_id(party, "ludwig")
	for member in party:
		if member.hp_current <= 0:
			continue
		if member.id == "ludwig" and ludwig != null and ludwig.has_status(StatusEffectIds.GUARD_STANCE):
			continue
		candidates.append(member)
	if candidates.is_empty():
		return _select_first_alive(party)
	return candidates[randi_range(0, candidates.size() - 1)].id


func _select_random(party: Array) -> String:
	var candidates: Array = []
	for member in party:
		if member.hp_current > 0:
			candidates.append(member)
	if candidates.is_empty():
		return ""
	return candidates[randi_range(0, candidates.size() - 1)].id


func _find_by_id(party: Array, id: String) -> Character:
	for member in party:
		if member.id == id:
			return member
	return null


func _increment_marcus_turn(battle_state: Dictionary) -> void:
	battle_state.flags.marcus_turn_index = battle_state.flags.get("marcus_turn_index", 0) + 1


func _update_phase(boss: Boss) -> void:
	var hp_percent = float(boss.hp_current) / float(boss.stats.get("hp_max", 1)) * 100.0
	if boss.phase == 1 and hp_percent <= 60.0:
		boss.phase = 2
	if boss.phase == 2 and hp_percent <= 30.0:
		boss.phase = 3
