extends Node
class_name BattleManager

@warning_ignore("unused_signal")
signal turn_order_updated(order: Array)
signal active_character_changed(actor_id: String)
signal phase_changed(phase: int)
signal message_added(text: String)
signal action_enqueued(action: Dictionary)
signal action_executed(result: Dictionary)
signal battle_ended(result: String)
@warning_ignore("unused_signal")
signal status_tick(actor_id: String, amount: int, kind: String)

var battle_state := {
	"phase": 1,
	"state": 0,
	"turn_count": 0,
	"active_character_id": "",
	"party": [],
	"enemies": [],
	"turn_order": [],
	"message_log": [],
	"action_queue": [],
	"reaction_queue": [],
	"action_log": [],
	"flags": {}
}

# O(1) actor lookup cache
var _actor_lookup: Dictionary = {}
var action_resolver: ActionResolver
var reaction_resolver: ReactionResolver
var turn_manager: TurnManager
var status_processor: StatusProcessor
var _reaction_sequence := 0

const TURN_ORDER_RANDOM_MIN := 0
const TURN_ORDER_RANDOM_MAX := 5
const MESSAGE_LOG_LIMIT := 12
const LIMIT_GAIN_DEALT_DIV := 10.0
const LIMIT_GAIN_TAKEN_DIV := 5.0
const LIMIT_GAIN_DOT_DIV := 8.0
const STUNNING_STRIKE_PROC_CHANCE := 0.5
const SHIELD_BASH_STUN_CHANCE := 0.4
const DRAGONFIRE_CHARM_CHANCE := 0.7
const RIPOSTE_PROC_CHANCE := 0.5
const ACTION_DISPLAY_NAMES := {
	ActionIds.BOS_GREATAXE_SLAM: "Greataxe Slam",
	ActionIds.BOS_TENDRIL_LASH: "Tendril Lash",
	ActionIds.BOS_BATTLE_ROAR: "Battle Roar",
	ActionIds.BOS_COLLECTORS_GRASP: "Collector's Grasp",
	ActionIds.BOS_DARK_REGEN: "Dark Regeneration",
	ActionIds.BOS_SYMBIOTIC_RAGE: "Symbiotic Rage",
	ActionIds.BOS_VENOM_STRIKE: "Venom Strike",
	ActionIds.BASIC_ATTACK: "Attack",
	ActionIds.KAI_FLURRY: "Flurry of Blows",
	ActionIds.KAI_STUN_STRIKE: "Stunning Strike",
	ActionIds.KAI_FIRE_IMBUE: "Fire Imbue",
	ActionIds.LUD_LUNGING: "Lunging Attack",
	ActionIds.LUD_PRECISION: "Precision Strike",
	ActionIds.LUD_SHIELD_BASH: "Shield Bash",
	ActionIds.LUD_RALLY: "Rally",
	ActionIds.NINOS_VICIOUS_MOCKERY: "Vicious Mockery",
	ActionIds.NINOS_HEALING_WORD: "Healing Word",
	ActionIds.NINOS_BLESS: "Bless",
	ActionIds.NINOS_INSPIRE_ATTACK: "Inspire (Atk)",
	ActionIds.CAT_FIRE_BOLT: "Fire Bolt",
	ActionIds.CAT_FIREBALL: "Fireball",
	ActionIds.CAT_MAGE_ARMOR: "Mage Armor",
	ActionIds.KAI_LIMIT: "Inferno Fist",
	ActionIds.LUD_LIMIT: "Dragonfire Roar",
	ActionIds.NINOS_LIMIT: "Siren's Call",
	ActionIds.CAT_LIMIT: "Genie's Wrath"
}

enum BattleState {
	BATTLE_INIT,
	ROUND_INIT,
	TURN_START,
	ACTION_SELECT,
	ACTION_VALIDATE,
	ACTION_COMMIT,
	ACTION_RESOLVE,
	TURN_END,
	ROUND_END,
	BATTLE_END
}

const BATTLE_STATE_LABELS := {
	BattleState.BATTLE_INIT: "BATTLE_INIT",
	BattleState.ROUND_INIT: "ROUND_INIT",
	BattleState.TURN_START: "TURN_START",
	BattleState.ACTION_SELECT: "ACTION_SELECT",
	BattleState.ACTION_VALIDATE: "ACTION_VALIDATE",
	BattleState.ACTION_COMMIT: "ACTION_COMMIT",
	BattleState.ACTION_RESOLVE: "ACTION_RESOLVE",
	BattleState.TURN_END: "TURN_END",
	BattleState.ROUND_END: "ROUND_END",
	BattleState.BATTLE_END: "BATTLE_END"
}


func setup_state(party: Array, enemies: Array) -> void:
	battle_state.phase = 1
	battle_state.state = BattleState.BATTLE_INIT
	battle_state.turn_count = 0
	battle_state.active_character_id = ""
	battle_state.party = party
	battle_state.enemies = enemies
	battle_state.turn_order = []
	battle_state.message_log = []
	battle_state.action_queue = []
	battle_state.reaction_queue = []
	battle_state.action_log = []
	_reaction_sequence = 0
	battle_state.flags = {
		"ludwig_second_wind_used": false,
		"ninos_counterspell_used": false,
		"quicken_used_this_round": false,
		"ai_disabled": false,
		"metamagic": {},
		"marcus_pull_target": "",
		"marcus_turn_index": 0,
		"boss_cooldowns": {},
		"boss_phase_announced": 1
	}
	_build_actor_lookup()
	_ensure_action_resolver()
	_ensure_reaction_resolver()
	_ensure_turn_manager()
	_ensure_status_processor()


func advance_state(next_state: int) -> void:
	if battle_state.state == next_state:
		return
	battle_state.state = next_state
	add_message("State -> " + _get_state_label(next_state))


func _get_state_label(state_id: int) -> String:
	if BATTLE_STATE_LABELS.has(state_id):
		return BATTLE_STATE_LABELS[state_id]
	return str(state_id)


func _ensure_action_resolver() -> void:
	if action_resolver == null:
		action_resolver = ActionResolver.new()
		action_resolver.setup(self)


func _ensure_turn_manager() -> void:
	if turn_manager == null:
		turn_manager = TurnManager.new()
		turn_manager.setup(self)


func _ensure_reaction_resolver() -> void:
	if reaction_resolver == null:
		reaction_resolver = ReactionResolver.new()
		reaction_resolver.setup(self)


func _ensure_status_processor() -> void:
	if status_processor == null:
		status_processor = StatusProcessor.new()
		status_processor.setup(self)


func _build_actor_lookup() -> void:
	_actor_lookup.clear()
	for actor in battle_state.party:
		_actor_lookup[actor.id] = actor
	for enemy in battle_state.enemies:
		_actor_lookup[enemy.id] = enemy


func calculate_turn_order() -> Array:
	_ensure_turn_manager()
	return turn_manager.calculate_turn_order()


func start_round() -> void:
	_ensure_turn_manager()
	turn_manager.start_round()


func advance_turn() -> void:
	_ensure_turn_manager()
	turn_manager.advance_turn()


func add_message(text: String) -> void:
	if text.is_empty():
		return
	battle_state.message_log.append(text)
	while battle_state.message_log.size() > MESSAGE_LOG_LIMIT:
		battle_state.message_log.remove_at(0)
	emit_signal("message_added", text)


func execute_basic_attack(attacker_id: String, target_id: String, multiplier: float = 1.0, action_tags: Array = []) -> Dictionary:
	_ensure_action_resolver()
	return action_resolver.execute_basic_attack(attacker_id, target_id, multiplier, action_tags)


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
	result["action_id"] = action.get("action_id", "")
	_trigger_reaction_window(action, result)
	_execute_reaction_queue()
	battle_state.action_log.append({"type": "executed", "result": result})
	emit_signal("action_executed", result)
	if result.get("ok", false):
		add_message("Action executed.")
		_check_battle_end()
	return result


func _resolve_action(action: Dictionary) -> Dictionary:
	_ensure_action_resolver()
	return action_resolver._resolve_action(action)


func _trigger_reaction_window(action: Dictionary, result: Dictionary) -> void:
	_ensure_reaction_resolver()
	battle_state.reaction_queue.clear()
	reaction_resolver.queue_reactions(action, result)


func enqueue_reaction(reaction: Dictionary) -> void:
	reaction["sequence"] = _reaction_sequence
	_reaction_sequence += 1
	battle_state.reaction_queue.append(reaction)


func _execute_reaction_queue() -> void:
	if battle_state.reaction_queue.is_empty():
		return
	battle_state.reaction_queue.sort_custom(func(a, b):
		if a.priority == b.priority:
			return a.sequence < b.sequence
		return a.priority > b.priority
	)
	while not battle_state.reaction_queue.is_empty():
		var entry = battle_state.reaction_queue.pop_front()
		_resolve_reaction(entry)


func _resolve_reaction(entry: Dictionary) -> void:
	var reaction_id = entry.get("reaction_id", "")
	match reaction_id:
		"counterspell_sense":
			add_message(entry.get("log_message", ""))
		"riposte":
			var attacker = get_actor_by_id(entry.get("actor_id", ""))
			var target = get_actor_by_id(entry.get("target_id", ""))
			if attacker == null or target == null:
				return
			if attacker.is_ko() or target.is_ko():
				return
			var damage = DamageCalculator.calculate_physical_damage(attacker, target, entry.get("multiplier", 0.6))
			_apply_damage_with_limit(attacker, target, damage)
			add_message("Riposte! " + attacker.display_name + " counters for " + str(damage) + " damage.")
		_:
			var log_message = entry.get("log_message", "")
			if log_message != "":
				add_message(log_message)


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
	if action.get("action_id", "") in [ActionIds.KAI_LIMIT, ActionIds.LUD_LIMIT, ActionIds.NINOS_LIMIT, ActionIds.CAT_LIMIT]:
		if actor.limit_gauge < 100:
			return ActionResult.new(false, "limit_not_ready").to_dict()
	if actor.has_status(StatusEffectIds.GUARD_STANCE):
		if action.get("action_id", "") == ActionIds.BASIC_ATTACK:
			return ActionResult.new(false, "guard_stance_restricts").to_dict()
		if action.get("action_id", "") in [ActionIds.LUD_LUNGING, ActionIds.LUD_PRECISION, ActionIds.LUD_SHIELD_BASH]:
			return ActionResult.new(false, "guard_stance_restricts").to_dict()
	return ActionResult.new(true).to_dict()


func can_act(actor: Character) -> bool:
	return not actor.has_status("STUN") and not actor.has_status("CHARM")


func process_end_of_turn_effects(actor: Character) -> void:
	_ensure_status_processor()
	status_processor.process_end_of_turn_effects(actor)


func _apply_attack_hits(attacker_id: String, target_id: String, hits: int, multiplier: float, action_tags: Array = []) -> Array:
	var damages: Array = []
	for _i in range(hits):
		var result = execute_basic_attack(attacker_id, target_id, multiplier, action_tags)
		damages.append(result.get("payload", {}).get("damage", 0))
	return damages


func _get_additional_enemy_target(exclude_id: String) -> Character:
	for enemy in get_alive_enemies():
		if enemy.id != exclude_id:
			return enemy
	return null


func _apply_damage_with_limit(attacker: Character, target: Character, amount: int) -> void:
	_ensure_action_resolver()
	action_resolver._apply_damage_with_limit(attacker, target, amount)

func _check_boss_phase_transition(target: Character) -> void:
	if target == null:
		return
	if target.id != "marcus_gelt":
		return
	var hp_percent = float(target.hp_current) / float(target.stats.get("hp_max", 1)) * 100.0
	if target.phase == 1 and hp_percent <= 60.0:
		target.phase = 2
		add_message("The symbiote armor awakens fully!")
		emit_signal("phase_changed", 2)
		_reset_turn_order_after_phase()
	if target.phase == 2 and hp_percent <= 30.0:
		target.phase = 3
		add_message("The Collector's desperation takes hold!")
		emit_signal("phase_changed", 3)
		_reset_turn_order_after_phase()

func _reset_turn_order_after_phase() -> void:
	var order: Array = []
	for member in battle_state.party:
		if member.hp_current > 0:
			order.append(member.id)
	for enemy in battle_state.enemies:
		if enemy.hp_current > 0:
			order.append(enemy.id)
	battle_state.turn_order = order

func _apply_bless_bonus(attacker: Character, base_damage: int) -> int:
	if attacker == null:
		return base_damage
	if attacker.has_status(StatusEffectIds.BLESS):
		return base_damage + randi_range(1, 4)
	return base_damage

func _apply_genies_wrath_bonus(attacker: Character, base_damage: int) -> int:
	if attacker == null:
		return base_damage
	if not attacker.has_status(StatusEffectIds.GENIES_WRATH):
		return base_damage
	return int(floor(base_damage * 1.5))

func _consume_genies_wrath_charge(actor: Character) -> void:
	if actor == null:
		return
	if not actor.has_status(StatusEffectIds.GENIES_WRATH):
		return
	for status in actor.status_effects:
		if status is StatusEffect and status.id == StatusEffectIds.GENIES_WRATH:
			status.duration -= 1
			status.value -= 1
			if status.duration <= 0:
				actor.remove_status(StatusEffectIds.GENIES_WRATH)
			break
		elif status is Dictionary and status.get("id", "") == StatusEffectIds.GENIES_WRATH:
			status["duration"] = status.get("duration", 0) - 1
			status["value"] = status.get("value", 0) - 1
			if status["duration"] <= 0:
				actor.remove_status(StatusEffectIds.GENIES_WRATH)
			break

func _remove_negative_statuses(actor: Character) -> void:
	if actor == null:
		return
	var removals: Array = []
	for status in actor.status_effects:
		var tags = _get_status_tags(status)
		if tags.has(StatusTags.NEGATIVE):
			removals.append(_get_status_id(status))
	for status_id in removals:
		actor.remove_status(status_id)


func _try_riposte(attacker: Character, defender: Character) -> void:
	_ensure_action_resolver()
	action_resolver._try_riposte(attacker, defender)


func _remove_guard_on_stun(target: Character) -> void:
	if target != null and target.has_status(StatusEffectIds.GUARD_STANCE):
		target.remove_status(StatusEffectIds.GUARD_STANCE)
		add_message(target.display_name + "'s Guard Stance breaks!")


func _count_status(actor: Character, status_id: String) -> int:
	var count = 0
	if actor == null:
		return 0
	for status in actor.status_effects:
		if status is StatusEffect and status.id == status_id:
			count += 1
		elif status is Dictionary and status.get("id", "") == status_id:
			count += 1
	return count


func _update_limit_gauges(attacker: Character, target: Character, amount: int) -> void:
	if amount <= 0:
		return
	if attacker != null:
		attacker.add_limit_gauge(int(floor(amount / LIMIT_GAIN_DEALT_DIV)))
	if target != null:
		_add_limit_on_damage_taken(target, amount, LIMIT_GAIN_TAKEN_DIV)

func _add_limit_on_damage_taken(target: Character, amount: int, divisor: float) -> void:
	if target == null:
		return
	if amount <= 0:
		return
	target.add_limit_gauge(int(floor(amount / divisor)))


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
	return _actor_lookup.get(actor_id, null)


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


func _display_action_name(action_id: String) -> String:
	if ACTION_DISPLAY_NAMES.has(action_id):
		return ACTION_DISPLAY_NAMES[action_id]
	return action_id


func _format_enemy_action(actor: Character, action_id: String, targets: Array) -> String:
	var label = _display_action_name(action_id)
	if targets.is_empty():
		return "ENEMY: " + actor.display_name + " uses " + label + "!"
	var target_names = []
	for target_id in targets:
		var target = get_actor_by_id(target_id)
		if target != null:
			target_names.append(target.display_name)
	return "ENEMY: " + actor.display_name + " uses " + label + " on " + ", ".join(target_names) + "!"


func format_action_declaration(actor_id: String, action: Dictionary) -> String:
	var actor = get_actor_by_id(actor_id)
	var actor_name = actor.display_name if actor != null else actor_id
	var label = _display_action_name(action.get("action_id", ""))
	var targets = action.get("targets", [])
	if targets.is_empty():
		return actor_name + " prepares " + label + "..."
	var target_names = []
	for target_id in targets:
		var target = get_actor_by_id(target_id)
		if target != null:
			target_names.append(target.display_name)
	return actor_name + " prepares " + label + " on " + ", ".join(target_names) + "..."


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
		var duration = status.get("duration", 0)
		if duration >= 0:
			status["duration"] = duration - 1


func _is_status_expired(status: Variant) -> bool:
	if status is StatusEffect:
		return status.is_expired()
	if status is Dictionary:
		var duration = status.get("duration", 0)
		if duration < 0:
			return false
		return duration <= 0
	return false
