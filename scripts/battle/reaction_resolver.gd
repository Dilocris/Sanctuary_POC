extends RefCounted
class_name ReactionResolver

## ReactionResolver - Evaluates reaction windows after actions resolve

const PRIORITY_COUNTERSPELL_SENSE := 100
const PRIORITY_RIPOSTE := 50

var _battle_manager: BattleManager


func setup(battle_manager: BattleManager) -> void:
	_battle_manager = battle_manager


func queue_reactions(action: Dictionary, result: Dictionary) -> void:
	if not result.get("ok", false):
		return
	_queue_counterspell_sense(action)
	_queue_riposte(action)


func _queue_counterspell_sense(action: Dictionary) -> void:
	var tags: Array = action.get("tags", [])
	var mp_cost = int(action.get("mp_cost", 0))
	if mp_cost <= 0 and not tags.has(ActionTags.MAGICAL):
		return
	var actor_id = action.get("actor_id", "")
	if not _is_enemy_actor(actor_id):
		return
	var ninos = _battle_manager.get_actor_by_id("ninos")
	if ninos == null or ninos.is_ko():
		return
	if _battle_manager.battle_state.flags.get("ninos_counterspell_used", false):
		return
	_battle_manager.battle_state.flags["ninos_counterspell_used"] = true
	_battle_manager.enqueue_reaction({
		"reaction_id": "counterspell_sense",
		"priority": PRIORITY_COUNTERSPELL_SENSE,
		"log_message": "Counterspell Sense triggers!"
	})


func _queue_riposte(action: Dictionary) -> void:
	var tags: Array = action.get("tags", [])
	if not tags.has(ActionTags.PHYSICAL):
		return
	var targets: Array = action.get("targets", [])
	if targets.is_empty():
		return
	var defender = _battle_manager.get_actor_by_id(targets[0])
	if defender == null:
		return
	if defender.id != "ludwig":
		return
	if defender.is_ko():
		return
	if not defender.has_status(StatusEffectIds.GUARD_STANCE):
		return
	if randf() > _battle_manager.RIPOSTE_PROC_CHANCE:
		return
	_battle_manager.enqueue_reaction({
		"reaction_id": "riposte",
		"priority": PRIORITY_RIPOSTE,
		"actor_id": defender.id,
		"target_id": action.get("actor_id", ""),
		"multiplier": _battle_manager.RIPOSTE_DAMAGE_MULTIPLIER
	})


func _is_enemy_actor(actor_id: String) -> bool:
	for enemy in _battle_manager.battle_state.enemies:
		if enemy.id == actor_id:
			return true
	return false
