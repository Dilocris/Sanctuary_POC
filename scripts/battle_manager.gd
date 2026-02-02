extends Node
class_name BattleManager

signal turn_order_updated(order: Array)
signal active_character_changed(actor_id: String)
signal phase_changed(phase: int)
signal message_added(text: String)

var battle_state := {
	"phase": 1,
	"turn_count": 0,
	"active_character_id": "",
	"party": [],
	"enemies": [],
	"turn_order": [],
	"message_log": [],
	"flags": {}
}

const TURN_ORDER_RANDOM_MIN := 0
const TURN_ORDER_RANDOM_MAX := 5
const MESSAGE_LOG_LIMIT := 4


func setup_state(party: Array, enemies: Array) -> void:
	battle_state.phase = 1
	battle_state.turn_count = 0
	battle_state.active_character_id = ""
	battle_state.party = party
	battle_state.enemies = enemies
	battle_state.turn_order = []
	battle_state.message_log = []
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
		return {"ok": false, "error": "invalid_actor"}
	if attacker.is_ko() or target.is_ko():
		return {"ok": false, "error": "target_ko"}

	var damage = DamageCalculator.calculate_physical_damage(attacker, target, multiplier)
	target.apply_damage(damage)
	add_message(attacker.display_name + " attacks " + target.display_name + " for " + str(damage) + "!")
	return {"ok": true, "damage": damage}


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


func _set_active_character(actor_id: String) -> void:
	battle_state.active_character_id = actor_id
	emit_signal("active_character_changed", actor_id)
