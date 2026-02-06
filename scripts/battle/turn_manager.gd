extends RefCounted
class_name TurnManager

## TurnManager - Manages turn order and round flow

var _battle_manager: BattleManager


func setup(battle_manager: BattleManager) -> void:
	_battle_manager = battle_manager


func calculate_turn_order() -> Array:
	var turn_queue: Array = []

	for actor in _battle_manager.battle_state.party:
		if actor.hp_current > 0 and not actor.has_status("STUN"):
			turn_queue.append({
				"id": actor.id,
				"priority": actor.stats["spd"] + randi_range(_battle_manager.TURN_ORDER_RANDOM_MIN, _battle_manager.TURN_ORDER_RANDOM_MAX)
			})

	for enemy in _battle_manager.battle_state.enemies:
		if enemy.hp_current > 0:
			turn_queue.append({
				"id": enemy.id,
				"priority": enemy.stats["spd"] + randi_range(_battle_manager.TURN_ORDER_RANDOM_MIN, _battle_manager.TURN_ORDER_RANDOM_MAX)
			})

	turn_queue.sort_custom(func(a, b): return a.priority > b.priority)

	var order: Array = []
	for entry in turn_queue:
		order.append(entry.id)

	_battle_manager.battle_state.turn_order = order
	_battle_manager.emit_signal("turn_order_updated", order)
	return order


func start_round() -> void:
	_battle_manager.battle_state.flags["quicken_used_this_round"] = false
	var order = calculate_turn_order()
	if order.is_empty():
		return
	_battle_manager._set_active_character(order[0])


func advance_turn() -> void:
	if _battle_manager.battle_state.turn_order.is_empty():
		start_round()
		return
	var current_index = _battle_manager.battle_state.turn_order.find(_battle_manager.battle_state.active_character_id)
	if current_index == -1:
		start_round()
		return
	var next_index = current_index + 1
	if next_index >= _battle_manager.battle_state.turn_order.size():
		_battle_manager.battle_state.turn_count += 1
		start_round()
		return
	_battle_manager._set_active_character(_battle_manager.battle_state.turn_order[next_index])
