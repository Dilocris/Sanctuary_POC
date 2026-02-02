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
		"ninos_counterspell_used": false
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
	target.apply_damage(damage)
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
