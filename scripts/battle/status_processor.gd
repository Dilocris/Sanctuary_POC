extends RefCounted
class_name StatusProcessor

## StatusProcessor - Handles end-of-turn status ticking and expiration

var _battle_manager: BattleManager


func setup(battle_manager: BattleManager) -> void:
	_battle_manager = battle_manager


func process_end_of_turn_effects(actor: Character) -> void:
	var removals: Array = []
	var difficulty = _battle_manager._get_difficulty_settings()
	var dot_party_mult = float(difficulty.get("dot_party", 1.0))
	var dot_enemy_mult = float(difficulty.get("dot_enemy", 1.0))
	for status in actor.status_effects:
		var tags = _battle_manager._get_status_tags(status)
		var value = _battle_manager._get_status_value(status)
		if tags.has("DOT"):
			var mult = dot_party_mult if _battle_manager.is_party_member(actor.id) else dot_enemy_mult
			var dot_damage = max(1, int(round(float(value) * mult)))
			actor.apply_damage(dot_damage)
			_battle_manager._add_limit_on_damage_taken(actor, dot_damage, _battle_manager.LIMIT_GAIN_DOT_DIV)
			_battle_manager.add_message(actor.display_name + " takes " + str(dot_damage) + " damage.")
			_battle_manager.emit_signal("status_tick", actor.id, dot_damage, "DOT")
		if tags.has("HOT"):
			actor.heal(value)
			_battle_manager.add_message(actor.display_name + " recovers " + str(value) + " HP.")
			_battle_manager.emit_signal("status_tick", actor.id, value, "HOT")

		_battle_manager._tick_status(status)
		if _battle_manager._is_status_expired(status):
			removals.append(_battle_manager._get_status_id(status))

	for status_id in removals:
		actor.remove_status(status_id)
		_battle_manager.add_message(_format_status_name(status_id) + " wears off!")
	if actor.id == "kairus" and actor.has_status(StatusEffectIds.FIRE_IMBUE):
		if _battle_manager.battle_state.flags.get("fire_imbue_skip_drain", false):
			_battle_manager.battle_state.flags["fire_imbue_skip_drain"] = false
		else:
			actor.consume_resource("ki", 1)
			if actor.get_resource_current("ki") <= 0:
				actor.remove_status(StatusEffectIds.FIRE_IMBUE)
				_battle_manager.add_message("Kairus's Fire Imbue fades (out of Ki)!")
	_battle_manager._check_battle_end()


func _format_status_name(status_id: String) -> String:
	var words = status_id.to_lower().split("_", false)
	for i in range(words.size()):
		words[i] = words[i].capitalize()
	return " ".join(words)
