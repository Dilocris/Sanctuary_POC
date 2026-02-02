extends Node
class_name BattleManager

signal turn_order_updated(order: Array)
signal active_character_changed(actor_id: String)
signal phase_changed(phase: int)
signal message_added(text: String)
signal action_enqueued(action: Dictionary)
signal action_executed(result: Dictionary)
signal battle_ended(result: String)

var battle_state := {
	"phase": 1,
	"turn_count": 0,
	"active_character_id": "",
	"party": [],
	"enemies": [],
	"turn_order": [],
	"message_log": [],
	"action_queue": [],
	"action_log": [],
	"flags": {}
}

const TURN_ORDER_RANDOM_MIN := 0
const TURN_ORDER_RANDOM_MAX := 5
const MESSAGE_LOG_LIMIT := 12


func setup_state(party: Array, enemies: Array) -> void:
	battle_state.phase = 1
	battle_state.turn_count = 0
	battle_state.active_character_id = ""
	battle_state.party = party
	battle_state.enemies = enemies
	battle_state.turn_order = []
	battle_state.message_log = []
	battle_state.action_queue = []
	battle_state.action_log = []
	battle_state.flags = {
		"ludwig_second_wind_used": false,
		"ninos_counterspell_used": false,
		"metamagic": {}
	}


func calculate_turn_order() -> Array:
	var turn_queue: Array = []

	for actor in battle_state.party:
		if actor.hp_current > 0 and not actor.has_status("STUN"):
			turn_queue.append({
				"id": actor.id,
				"priority": actor.stats["spd"] + randi_range(TURN_ORDER_RANDOM_MIN, TURN_ORDER_RANDOM_MAX)
			})

	for enemy in battle_state.enemies:
		if enemy.hp_current > 0:
			turn_queue.append({
				"id": enemy.id,
				"priority": enemy.stats["spd"] + randi_range(TURN_ORDER_RANDOM_MIN, TURN_ORDER_RANDOM_MAX)
			})

	turn_queue.sort_custom(func(a, b): return a.priority > b.priority)

	var order: Array = []
	for entry in turn_queue:
		order.append(entry.id)

	battle_state.turn_order = order
	emit_signal("turn_order_updated", order)
	return order


func start_round() -> void:
	var order = calculate_turn_order()
	if order.is_empty():
		return
	_set_active_character(order[0])


func advance_turn() -> void:
	if battle_state.turn_order.is_empty():
		start_round()
		return
	var current_index = battle_state.turn_order.find(battle_state.active_character_id)
	if current_index == -1:
		start_round()
		return
	var next_index = current_index + 1
	if next_index >= battle_state.turn_order.size():
		battle_state.turn_count += 1
		start_round()
		return
	_set_active_character(battle_state.turn_order[next_index])


func add_message(text: String) -> void:
	if text.is_empty():
		return
	battle_state.message_log.append(text)
	while battle_state.message_log.size() > MESSAGE_LOG_LIMIT:
		battle_state.message_log.remove_at(0)
	emit_signal("message_added", text)


func execute_basic_attack(attacker_id: String, target_id: String, multiplier: float = 1.0) -> Dictionary:
	var attacker = get_actor_by_id(attacker_id)
	var target = get_actor_by_id(target_id)
	if attacker == null or target == null:
		return ActionResult.new(false, "invalid_actor").to_dict()
	if attacker.is_ko() or target.is_ko():
		return ActionResult.new(false, "target_ko").to_dict()

	var damage = DamageCalculator.calculate_physical_damage(attacker, target, multiplier)
	_apply_damage_with_limit(attacker, target, damage)
	add_message(attacker.display_name + " attacks " + target.display_name + " for " + str(damage) + "!")
	return ActionResult.new(true, "", {
		"damage": damage,
		"attacker_id": attacker_id,
		"target_id": target_id
	}).to_dict()


func enqueue_action(action: Dictionary) -> void:
	battle_state.action_queue.append(action)
	battle_state.action_log.append({"type": "queued", "action": action})
	emit_signal("action_enqueued", action)
	add_message("Queued action: " + str(action.get("action_id", "")))


func process_next_action() -> Dictionary:
	if battle_state.action_queue.is_empty():
		return ActionResult.new(false, "empty_queue").to_dict()
	var action = battle_state.action_queue.pop_front()
	var validation = _validate_action(action)
	if not validation.ok:
		add_message("Invalid action: " + str(validation.error))
		var invalid_result = ActionResult.new(false, validation.error).to_dict()
		emit_signal("action_executed", invalid_result)
		return invalid_result
	var result = _resolve_action(action)
	battle_state.action_log.append({"type": "executed", "result": result})
	emit_signal("action_executed", result)
	if result.get("ok", false):
		add_message("Action executed.")
		_check_battle_end()
	return result


func _resolve_action(action: Dictionary) -> Dictionary:
	var action_id = action.get("action_id", "")
	var actor_id = action.get("actor_id", "")
	var targets = action.get("targets", [])
	var actor = get_actor_by_id(actor_id)
	if actor != null and not actor.can_use_action(action):
		return ActionResult.new(false, "insufficient_resources").to_dict()
	match action_id:
		ActionIds.BASIC_ATTACK:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			if actor != null:
				actor.consume_resources(action)
			return execute_basic_attack(actor_id, targets[0], action.get("multiplier", 1.0))
		ActionIds.SKIP_TURN:
			add_message("Action skipped.")
			return ActionResult.new(true, "", {"skipped": true}).to_dict()
		ActionIds.KAI_FLURRY:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			if actor != null:
				actor.consume_resources(action)
			var flurry_total = _apply_attack_hits(actor_id, targets[0], 2, action.get("multiplier", 1.0))
			return ActionResult.new(true, "", {
				"damage": flurry_total,
				"hits": 2,
				"attacker_id": actor_id,
				"target_id": targets[0]
			}).to_dict()
		ActionIds.KAI_STUN_STRIKE:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			if actor != null:
				actor.consume_resources(action)
			var stun_damage = execute_basic_attack(actor_id, targets[0], action.get("multiplier", 1.0))
			var applied = false
			if randf() <= 0.5:
				var target = get_actor_by_id(targets[0])
				if target != null:
					target.add_status(StatusEffectFactory.stun(1))
					applied = true
					add_message(target.display_name + " is stunned!")
			return ActionResult.new(true, "", {
				"damage": stun_damage.get("payload", {}).get("damage", 0),
				"stun_applied": applied,
				"attacker_id": actor_id,
				"target_id": targets[0]
			}).to_dict()
		ActionIds.KAI_FIRE_IMBUE:
			if actor != null:
				if actor.has_status(StatusEffectIds.FIRE_IMBUE):
					actor.remove_status(StatusEffectIds.FIRE_IMBUE)
					add_message("Fire Imbue toggled off.")
					return ActionResult.new(true, "", {"toggled": "off"}).to_dict()
				actor.add_status(StatusEffectFactory.fire_imbue())
				add_message("Fire Imbue toggled on.")
				return ActionResult.new(true, "", {"toggled": "on"}).to_dict()
			return ActionResult.new(false, "missing_actor").to_dict()
		ActionIds.LUD_GUARD_STANCE:
			if actor != null:
				if actor.has_status(StatusEffectIds.GUARD_STANCE):
					actor.remove_status(StatusEffectIds.GUARD_STANCE)
					add_message("Guard Stance toggled off.")
					return ActionResult.new(true, "", {"toggled": "off"}).to_dict()
				actor.add_status(StatusEffectFactory.guard_stance())
				add_message("Guard Stance toggled on.")
				return ActionResult.new(true, "", {"toggled": "on"}).to_dict()
			return ActionResult.new(false, "missing_actor").to_dict()
		ActionIds.LUD_LUNGING:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			if actor != null:
				actor.consume_resources(action)
			var base_result = execute_basic_attack(actor_id, targets[0], action.get("multiplier", 1.2))
			var bonus_dmg = randi_range(1, 8)
			var total_dmg = base_result.get("payload", {}).get("damage", 0) + bonus_dmg
			var target_lung = get_actor_by_id(targets[0])
			if target_lung != null:
				_apply_damage_with_limit(actor, target_lung, bonus_dmg)
				add_message(actor.display_name + " lunges! Bonus " + str(bonus_dmg) + " damage!")
			return ActionResult.new(true, "", {
				"damage": total_dmg,
				"bonus": bonus_dmg,
				"attacker_id": actor_id,
				"target_id": targets[0]
			}).to_dict()
		ActionIds.LUD_PRECISION:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			if actor != null:
				actor.consume_resources(action)
			# Precision ignores evasion (not implemented yet), so same as Lunging for now but explicit
			var base_prec = execute_basic_attack(actor_id, targets[0], action.get("multiplier", 1.2))
			var bonus_prec = randi_range(1, 8)
			var total_prec = base_prec.get("payload", {}).get("damage", 0) + bonus_prec
			var target_prec = get_actor_by_id(targets[0])
			if target_prec != null:
				_apply_damage_with_limit(actor, target_prec, bonus_prec)
				add_message(actor.display_name + " strikes precisely! Bonus " + str(bonus_prec) + " damage!")
			return ActionResult.new(true, "", {
				"damage": total_prec,
				"bonus": bonus_prec,
				"attacker_id": actor_id,
				"target_id": targets[0]
			}).to_dict()
		ActionIds.LUD_SHIELD_BASH:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			if actor != null:
				actor.consume_resources(action)
			var bash_result = execute_basic_attack(actor_id, targets[0], 1.0)
			var stunned = false
			if randf() <= 0.40:
				var target_bash = get_actor_by_id(targets[0])
				if target_bash != null:
					target_bash.add_status(StatusEffectFactory.stun(1))
					stunned = true
					add_message(target_bash.display_name + " is stunned by the shield bash!")
			return ActionResult.new(true, "", {
				"damage": bash_result.get("payload", {}).get("damage", 0),
				"stun_applied": stunned,
				"attacker_id": actor_id,
				"target_id": targets[0]
			}).to_dict()
		ActionIds.LUD_RALLY:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			if actor != null:
				actor.consume_resources(action)
			var target_rally = get_actor_by_id(targets[0])
			var heal_amt = randi_range(1, 8) + 5
			if target_rally != null:
				target_rally.heal(heal_amt)
				add_message(actor.display_name + " rallies " + target_rally.display_name + " for " + str(heal_amt) + " HP!")
			return ActionResult.new(true, "", {
				"healed": heal_amt,
				"attacker_id": actor_id,
				"target_id": targets[0]
			}).to_dict()
		ActionIds.NINOS_HEALING_WORD:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			if actor != null:
				actor.consume_resources(action)
			var target_hw = get_actor_by_id(targets[0])
			var heal_val = randi_range(2, 8) + 5
			if target_hw != null:
				target_hw.heal(heal_val)
				add_message(actor.display_name + " heals " + target_hw.display_name + " for " + str(heal_val) + " HP!")
			return ActionResult.new(true, "", {
				"healed": heal_val,
				"attacker_id": actor_id,
				"target_id": targets[0]
			}).to_dict()
		ActionIds.NINOS_VICIOUS_MOCKERY:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			if actor != null:
				actor.consume_resources(action)
			var target_vm = get_actor_by_id(targets[0])
			var damage_vm = 15 + (int(actor.stats.mag * 0.3) if actor else 0)
			if target_vm != null:
				_apply_damage_with_limit(actor, target_vm, damage_vm)
				target_vm.add_status(StatusEffectFactory.atk_down())
				add_message(actor.display_name + " mocks " + target_vm.display_name + "! " + str(damage_vm) + " dmg + ATK Down!")
			return ActionResult.new(true, "", {
				"damage": damage_vm,
				"debuff": "atk_down",
				"attacker_id": actor_id,
				"target_id": targets[0]
			}).to_dict()
		ActionIds.NINOS_BLESS:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			if actor != null:
				actor.consume_resources(action)
			for t_id in targets:
				var t_bless = get_actor_by_id(t_id)
				if t_bless != null:
					t_bless.add_status(StatusEffectFactory.bless_buff())
			add_message(actor.display_name + " blesses the party!")
			return ActionResult.new(true, "", {
				"buff": "bless",
				"targets": targets,
				"attacker_id": actor_id
			}).to_dict()
		ActionIds.NINOS_INSPIRE_ATTACK:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			if actor != null:
				actor.consume_resources(action)
			# For now, just a placeholder message for Inspiration as we don't have the 'next attack' logic fully hooked yet
			# We can simulate it by giving a temporary ATK_UP or similar if needed, or just logging it.
			# GDD says: "Target ally's next attack deals +1d8 damage". 
			# We will skip complex trigger logic for this pass and just show it consumed.
			add_message(actor.display_name + " inspired " + targets[0] + " (Attack)!")
			return ActionResult.new(true, "", {
				"inspired": "attack",
				"target_id": targets[0],
				"attacker_id": actor_id
			}).to_dict()

			return ActionResult.new(true, "", {
				"inspired": "attack",
				"target_id": targets[0],
				"attacker_id": actor_id
			}).to_dict()
		ActionIds.CAT_FIRE_BOLT:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			if actor != null:
				actor.consume_resources(action) # MP cost 0 but standard call
			var target_fb = get_actor_by_id(targets[0])
			var meta = consume_metamagic(actor_id)
			var dmg_fb = randi_range(1, 10) + (int(actor.stats.mag * 0.5) if actor else 0)
			if target_fb != null:
				_apply_damage_with_limit(actor, target_fb, dmg_fb)
				add_message(actor.display_name + " casts Fire Bolt at " + target_fb.display_name + "! " + str(dmg_fb) + " Fire dmg")
				if meta == "TWIN":
					var extra = _get_additional_enemy_target(targets[0])
					if extra != null:
						_apply_damage_with_limit(actor, extra, dmg_fb)
						add_message("Twin Spell hits " + extra.display_name + " for " + str(dmg_fb) + "!")
			return ActionResult.new(true, "", {
				"damage": dmg_fb,
				"element": "fire",
				"attacker_id": actor_id,
				"target_id": targets[0],
				"quicken": meta == "QUICKEN"
			}).to_dict()
		ActionIds.CAT_FIREBALL:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			if actor != null:
				actor.consume_resources(action)
			var meta_fb = consume_metamagic(actor_id)
			var total_dmg_fireball = 0
			var hit_targets = []
			for t_id in targets:
				var t_fireball = get_actor_by_id(t_id)
				if t_fireball != null:
					var dmg_val = randi_range(8, 64) # 8d6 roughly
					# For poc, simple formula:
					dmg_val = randi_range(20, 50) + (actor.stats.mag if actor else 0)
					_apply_damage_with_limit(actor, t_fireball, dmg_val)
					hit_targets.append(t_fireball.display_name)
					total_dmg_fireball += dmg_val
			add_message(actor.display_name + " casts Fireball! Hits: " + ", ".join(hit_targets))
			return ActionResult.new(true, "", {
				"damage_total": total_dmg_fireball,
				"targets_hit": hit_targets.size(),
				"attacker_id": actor_id,
				"quicken": meta_fb == "QUICKEN"
			}).to_dict()
		ActionIds.CAT_MAGE_ARMOR:
			if actor != null:
				var meta_ma = consume_metamagic(actor_id)
				if actor.has_status(StatusEffectIds.MAGE_ARMOR):
					add_message(actor.display_name + " already has Mage Armor.")
					return ActionResult.new(false, "already_active").to_dict()
				actor.consume_resources(action)
				actor.add_status(StatusEffectFactory.mage_armor())
				add_message(actor.display_name + " casts Mage Armor!")
				return ActionResult.new(true, "", {
					"buff": "mage_armor",
					"attacker_id": actor_id,
					"quicken": meta_ma == "QUICKEN"
				}).to_dict()
			return ActionResult.new(false, "missing_actor").to_dict()
		ActionIds.CAT_METAMAGIC_QUICKEN:
			if actor != null:
				actor.consume_resources(action)
				_set_metamagic(actor_id, "QUICKEN")
				add_message(actor.display_name + " prepares Quicken Spell.")
				return ActionResult.new(true, "", {"metamagic": "quicken"}).to_dict()
			return ActionResult.new(false, "missing_actor").to_dict()
		ActionIds.CAT_METAMAGIC_TWIN:
			if actor != null:
				actor.consume_resources(action)
				_set_metamagic(actor_id, "TWIN")
				add_message(actor.display_name + " prepares Twin Spell.")
				return ActionResult.new(true, "", {"metamagic": "twin"}).to_dict()
			return ActionResult.new(false, "missing_actor").to_dict()

		_:
			return ActionResult.new(false, "unknown_action").to_dict()


func _validate_action(action: Dictionary) -> Dictionary:
	var schema_result = ActionSchemaValidator.validate(action)
	if not schema_result.ok:
		return schema_result
	var actor = get_actor_by_id(action.get("actor_id", ""))
	if actor == null:
		return ActionResult.new(false, "missing_actor").to_dict()
	if actor.is_ko():
		return ActionResult.new(false, "actor_ko").to_dict()
	if not can_act(actor):
		return ActionResult.new(false, "actor_stunned").to_dict()
	if action.get("action_id", "") == ActionIds.BASIC_ATTACK:
		var targets = action.get("targets", [])
		if targets.size() == 0:
			return ActionResult.new(false, "missing_target").to_dict()
		var target = get_actor_by_id(targets[0])
		if target == null:
			return ActionResult.new(false, "missing_target").to_dict()
		if target.is_ko():
			return ActionResult.new(false, "target_ko").to_dict()
	if action.get("resource_type", "") != "":
		if actor is Character:
			var cost = action.get("resource_cost", 0)
			if actor.get_resource_current(action.resource_type) < cost:
				return ActionResult.new(false, "insufficient_resources").to_dict()
	return ActionResult.new(true).to_dict()


func can_act(actor: Character) -> bool:
	return not actor.has_status("STUN") and not actor.has_status("CHARM")


func process_end_of_turn_effects(actor: Character) -> void:
	var removals: Array = []
	for status in actor.status_effects:
		var tags = _get_status_tags(status)
		var value = _get_status_value(status)
		if tags.has("DOT"):
			actor.apply_damage(value)
			_update_limit_gauges(null, actor, value)
			add_message(actor.display_name + " takes " + str(value) + " damage.")
		if tags.has("HOT"):
			actor.heal(value)
			add_message(actor.display_name + " recovers " + str(value) + " HP.")

		_tick_status(status)
		if _is_status_expired(status):
			removals.append(_get_status_id(status))

	for status_id in removals:
		actor.remove_status(status_id)
		add_message(status_id + " wears off!")
	if actor.id == "kairus" and actor.has_status(StatusEffectIds.FIRE_IMBUE):
		actor.consume_resource("ki", 1)
		if actor.get_resource_current("ki") <= 0:
			actor.remove_status(StatusEffectIds.FIRE_IMBUE)
			add_message("Kairus's Fire Imbue fades (out of Ki)!")
	_check_battle_end()


func _apply_attack_hits(attacker_id: String, target_id: String, hits: int, multiplier: float) -> int:
	var total = 0
	for _i in range(hits):
		var result = execute_basic_attack(attacker_id, target_id, multiplier)
		total += result.get("payload", {}).get("damage", 0)
	return total


func _get_additional_enemy_target(exclude_id: String) -> Character:
	for enemy in get_alive_enemies():
		if enemy.id != exclude_id:
			return enemy
	return null


func _apply_damage_with_limit(attacker: Character, target: Character, amount: int) -> void:
	if target == null:
		return
	target.apply_damage(amount)
	_update_limit_gauges(attacker, target, amount)


func _update_limit_gauges(attacker: Character, target: Character, amount: int) -> void:
	if amount <= 0:
		return
	if attacker != null:
		attacker.add_limit_gauge(int(floor(amount / 10.0)))
	if target != null:
		target.add_limit_gauge(int(floor(amount / 5.0)))


func _set_metamagic(actor_id: String, meta: String) -> void:
	battle_state.flags.metamagic[actor_id] = meta


func consume_metamagic(actor_id: String) -> String:
	if not battle_state.flags.has("metamagic"):
		return ""
	if not battle_state.flags.metamagic.has(actor_id):
		return ""
	var meta = battle_state.flags.metamagic[actor_id]
	battle_state.flags.metamagic.erase(actor_id)
	return meta


func peek_metamagic(actor_id: String) -> String:
	if not battle_state.flags.has("metamagic"):
		return ""
	if not battle_state.flags.metamagic.has(actor_id):
		return ""
	return battle_state.flags.metamagic[actor_id]


func set_phase(new_phase: int) -> void:
	if battle_state.phase == new_phase:
		return
	battle_state.phase = new_phase
	emit_signal("phase_changed", new_phase)


func get_actor_by_id(actor_id: String) -> Node:
	for actor in battle_state.party:
		if actor.id == actor_id:
			return actor
	for enemy in battle_state.enemies:
		if enemy.id == actor_id:
			return enemy
	return null


func apply_status_to_actor(actor_id: String, status: Variant) -> bool:
	var actor = get_actor_by_id(actor_id)
	if actor == null:
		return false
	actor.add_status(status)
	return true


func get_alive_party() -> Array:
	var alive: Array = []
	for member in battle_state.party:
		if member.hp_current > 0:
			alive.append(member)
	return alive


func get_alive_enemies() -> Array:
	var alive: Array = []
	for enemy in battle_state.enemies:
		if enemy.hp_current > 0:
			alive.append(enemy)
	return alive


func _check_battle_end() -> void:
	if get_alive_enemies().is_empty():
		emit_signal("battle_ended", "victory")
		return
	if get_alive_party().is_empty():
		emit_signal("battle_ended", "defeat")


func _set_active_character(actor_id: String) -> void:
	battle_state.active_character_id = actor_id
	emit_signal("active_character_changed", actor_id)


func _get_status_id(status: Variant) -> String:
	if status is StatusEffect:
		return status.id
	if status is Dictionary:
		return status.get("id", "")
	return ""


func _get_status_value(status: Variant) -> int:
	if status is StatusEffect:
		return status.value
	if status is Dictionary:
		return status.get("value", 0)
	return 0


func _get_status_tags(status: Variant) -> Array:
	if status is StatusEffect:
		return status.tags
	if status is Dictionary:
		return status.get("tags", [])
	return []


func _tick_status(status: Variant) -> void:
	if status is StatusEffect:
		status.tick()
	elif status is Dictionary:
		status["duration"] = status.get("duration", 0) - 1


func _is_status_expired(status: Variant) -> bool:
	if status is StatusEffect:
		return status.is_expired()
	if status is Dictionary:
		return status.get("duration", 0) <= 0
	return false
