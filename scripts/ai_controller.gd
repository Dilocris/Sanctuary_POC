extends RefCounted
class_name AiController

func get_next_action(boss: Boss, battle_state: Dictionary) -> Dictionary:
	# Phase transitions are handled by BattleManager._check_boss_phase_transition()
	if boss.phase == 1:
		return _phase_one_action(boss, battle_state)
	if boss.phase == 2:
		return _phase_two_action(boss, battle_state)
	if boss.phase == 3:
		return _phase_three_action(boss, battle_state)

	return ActionFactory.skip_turn(boss.id)


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


func _phase_two_action(boss: Boss, battle_state: Dictionary) -> Dictionary:
	var party = battle_state.get("party", [])
	var cooldowns = battle_state.flags.get("boss_cooldowns", {})
	var dark_regen_cd = cooldowns.get("dark_regen", 0)
	if dark_regen_cd > 0:
		cooldowns["dark_regen"] = dark_regen_cd - 1
		battle_state.flags["boss_cooldowns"] = cooldowns

	if dark_regen_cd == 0 and battle_state.get("turn_count", 0) % 5 == 0:
		cooldowns["dark_regen"] = 4
		battle_state.flags["boss_cooldowns"] = cooldowns
		return ActionFactory.marcus_dark_regen(boss.id)

	if battle_state.flags.get("boss_last_action", "") != ActionIds.BOS_SYMBIOTIC_RAGE:
		var target_id = _select_highest_threat(party)
		battle_state.flags["boss_last_action"] = ActionIds.BOS_SYMBIOTIC_RAGE
		return ActionFactory.marcus_symbiotic_rage(boss.id, [target_id, target_id])

	battle_state.flags["boss_last_action"] = "basic"
	var target = _select_random(party)
	return ActionFactory.marcus_greataxe_slam(boss.id, target)


func _phase_three_action(boss: Boss, battle_state: Dictionary) -> Dictionary:
	var party = battle_state.get("party", [])
	var turn_count = battle_state.get("turn_count", 0)
	if turn_count % 4 == 0:
		var ids: Array = []
		for member in party:
			if member.hp_current > 0:
				ids.append(member.id)
		return ActionFactory.marcus_venom_strike(boss.id, ids)
	if turn_count % 4 == 2:
		var target_id = _select_highest_threat(party)
		return ActionFactory.marcus_symbiotic_rage(boss.id, [target_id, target_id])
	var target = _select_random(party)
	return ActionFactory.marcus_greataxe_slam(boss.id, target)


func _select_highest_threat(party: Array) -> String:
	var ludwig = _find_by_id(party, "ludwig")
	var ludwig_in_guard = ludwig != null and ludwig.has_status(StatusEffectIds.GUARD_STANCE)
	var best_id = ""
	var best_atk = -1
	for member in party:
		if member.hp_current <= 0:
			continue
		# Skip Ludwig when he's in Guard Stance (drawing aggro away from party)
		if member.id == "ludwig" and ludwig_in_guard:
			continue
		var atk = member.stats.get("atk", 0)
		if atk > best_atk:
			best_atk = atk
			best_id = member.id
	# Fallback to Ludwig if no other targets found
	if best_id == "" and ludwig != null and ludwig.hp_current > 0:
		return "ludwig"
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
