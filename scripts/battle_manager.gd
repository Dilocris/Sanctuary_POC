extends Node
class_name BattleManager

signal turn_order_updated(order: Array)
signal active_character_changed(actor_id: String)
signal phase_changed(phase: int)
signal message_added(text: String)
signal action_enqueued(action: Dictionary)
signal action_executed(result: Dictionary)
signal battle_ended(result: String)
signal status_tick(actor_id: String, amount: int, kind: String)

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
const LIMIT_GAIN_DEALT_DIV := 10.0
const LIMIT_GAIN_TAKEN_DIV := 5.0
const LIMIT_GAIN_DOT_DIV := 8.0
const ACTION_DISPLAY_NAMES := {
	ActionIds.BOS_GREAXE_SLAM: "Greataxe Slam",
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
		"metamagic": {},
		"marcus_pull_target": "",
		"marcus_turn_index": 0,
		"boss_cooldowns": {},
		"boss_phase_announced": 1
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
	var bonus_dmg = 0
	if attacker.has_status(StatusEffectIds.INSPIRE_ATTACK):
		bonus_dmg = randi_range(1, 8)
		attacker.remove_status(StatusEffectIds.INSPIRE_ATTACK)
		add_message(attacker.display_name + " strikes with Inspiration! +" + str(bonus_dmg) + " dmg.")
		damage += bonus_dmg
	_apply_damage_with_limit(attacker, target, damage)
	add_message(attacker.display_name + " attacks " + target.display_name + " for " + str(damage) + "!")
	_try_riposte(attacker, target)
	return ActionResult.new(true, "", {
		"damage": damage,
		"bonus": bonus_dmg,
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
	result["action_id"] = action.get("action_id", "")
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
	if actor != null and actor.has_status(StatusEffectIds.GENIES_WRATH) and action.get("mp_cost", 0) > 0:
		action["mp_cost"] = 0
		action["genies_wrath"] = true
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
			var flurry_hits = _apply_attack_hits(actor_id, targets[0], 2, action.get("multiplier", 1.0))
			var flurry_total = 0
			for hit in flurry_hits:
				flurry_total += int(hit)
			return ActionResult.new(true, "", {
				"damage": flurry_total,
				"damage_instances": flurry_hits,
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
					_remove_guard_on_stun(target)
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
					_remove_guard_on_stun(target_bash)
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
			damage_vm = _apply_bless_bonus(actor, damage_vm)
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
			var target_inspire = get_actor_by_id(targets[0])
			if target_inspire != null:
				target_inspire.add_status(StatusEffectFactory.inspire_attack())
				add_message(actor.display_name + " inspires " + target_inspire.display_name + " (Attack)!")
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
				_consume_genies_wrath_charge(actor)
			var target_fb = get_actor_by_id(targets[0])
			var meta = consume_metamagic(actor_id)
			var dmg_fb = randi_range(1, 10) + (int(actor.stats.mag * 0.5) if actor else 0)
			dmg_fb = _apply_genies_wrath_bonus(actor, dmg_fb)
			dmg_fb = _apply_bless_bonus(actor, dmg_fb)
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
				_consume_genies_wrath_charge(actor)
			var meta_fb = consume_metamagic(actor_id)
			var total_dmg_fireball = 0
			var hit_targets = []
			for t_id in targets:
				var t_fireball = get_actor_by_id(t_id)
				if t_fireball != null:
					var dmg_val = randi_range(8, 64) # 8d6 roughly
					# For poc, simple formula:
					dmg_val = randi_range(20, 50) + (actor.stats.mag if actor else 0)
					dmg_val = _apply_genies_wrath_bonus(actor, dmg_val)
					dmg_val = _apply_bless_bonus(actor, dmg_val)
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
				_consume_genies_wrath_charge(actor)
				actor.add_status(StatusEffectFactory.mage_armor())
				add_message(actor.display_name + " casts Mage Armor!")
				return ActionResult.new(true, "", {
					"buff": "mage_armor",
					"attacker_id": actor_id,
					"quicken": meta_ma == "QUICKEN"
				}).to_dict()
			return ActionResult.new(false, "missing_actor").to_dict()
		ActionIds.KAI_LIMIT:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			if actor != null:
				actor.reset_limit_gauge()
			var target = get_actor_by_id(targets[0])
			var hit_list: Array = []
			for _i in range(4):
				var base = DamageCalculator.calculate_physical_damage(actor, target, 0.8)
				var bonus = randi_range(1, 6)
				var total = base + bonus
				_apply_damage_with_limit(actor, target, total)
				hit_list.append(total)
			var last_base = DamageCalculator.calculate_physical_damage(actor, target, 2.0)
			var last_bonus = randi_range(4, 24)
			var last_total = (last_base * 2) + last_bonus
			_apply_damage_with_limit(actor, target, last_total)
			hit_list.append(last_total)
			var sum = 0
			for hit in hit_list:
				sum += int(hit)
			add_message(actor.display_name + " unleashes Inferno Fist!")
			return ActionResult.new(true, "", {
				"damage": sum,
				"damage_instances": hit_list,
				"attacker_id": actor_id,
				"target_id": targets[0]
			}).to_dict()
		ActionIds.LUD_LIMIT:
			if actor != null:
				actor.reset_limit_gauge()
			add_message(actor.display_name + " unleashes Dragonfire Roar!")
			for enemy in get_alive_enemies():
				if randf() <= 0.7:
					enemy.add_status(StatusEffectFactory.charm(1))
			for ally in get_alive_party():
				ally.add_status(StatusEffectFactory.atk_up(3, 0.25))
			return ActionResult.new(true, "", {
				"buff": "atk_up",
				"debuff": "charm",
				"attacker_id": actor_id
			}).to_dict()
		ActionIds.NINOS_LIMIT:
			if actor != null:
				actor.reset_limit_gauge()
			add_message(actor.display_name + " sings Siren's Call!")
			for ally in get_alive_party():
				ally.heal(80)
				_remove_negative_statuses(ally)
				ally.add_status(StatusEffectFactory.regen(3, 15))
			return ActionResult.new(true, "", {
				"healed": 80,
				"buff": "regen",
				"attacker_id": actor_id
			}).to_dict()
		ActionIds.CAT_LIMIT:
			if actor != null:
				actor.reset_limit_gauge()
				actor.add_status(StatusEffectFactory.genies_wrath(3))
				add_message(actor.display_name + " invokes Genie's Wrath!")
				return ActionResult.new(true, "", {"buff": "genies_wrath", "attacker_id": actor_id}).to_dict()
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
		ActionIds.BOS_GREAXE_SLAM:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			if actor != null:
				add_message(_format_enemy_action(actor, action_id, targets))
			return execute_basic_attack(actor_id, targets[0], action.get("multiplier", 1.2))
		ActionIds.BOS_TENDRIL_LASH:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			if actor != null:
				add_message(_format_enemy_action(actor, action_id, targets))
			var lash_result = execute_basic_attack(actor_id, targets[0], action.get("multiplier", 0.8))
			var target_lash = get_actor_by_id(targets[0])
			if target_lash != null:
				target_lash.add_status(StatusEffectFactory.poison())
				add_message(target_lash.display_name + " is poisoned!")
			return lash_result
		ActionIds.BOS_BATTLE_ROAR:
			if actor != null:
				add_message(_format_enemy_action(actor, action_id, []))
				var stacks = _count_status(actor, StatusEffectIds.ATK_UP)
				if stacks < 2:
					actor.add_status(StatusEffectFactory.atk_up(4, 0.25))
					add_message(actor.display_name + " roars and powers up!")
				else:
					add_message(actor.display_name + " roars, but can't stack more ATK.")
				return ActionResult.new(true, "", {"buff": "atk_up"}).to_dict()
			return ActionResult.new(false, "missing_actor").to_dict()
		ActionIds.BOS_COLLECTORS_GRASP:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			if actor != null:
				add_message(_format_enemy_action(actor, action_id, targets))
			battle_state.flags.marcus_pull_target = targets[0]
			var pulled = get_actor_by_id(targets[0])
			if pulled != null:
				add_message(pulled.display_name + " is dragged toward Marcus!")
			return ActionResult.new(true, "", {"pull": targets[0]}).to_dict()
		ActionIds.BOS_DARK_REGEN:
			if actor != null:
				add_message(_format_enemy_action(actor, action_id, []))
				var heal = randi_range(80, 130)
				actor.heal(heal)
				add_message(actor.display_name + " regenerates " + str(heal) + " HP!")
				return ActionResult.new(true, "", {"healed": heal, "attacker_id": actor_id, "target_id": actor_id}).to_dict()
			return ActionResult.new(false, "missing_actor").to_dict()
		ActionIds.BOS_SYMBIOTIC_RAGE:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			if actor != null:
				add_message(_format_enemy_action(actor, action_id, targets))
			var rage_hits = _apply_attack_hits(actor_id, targets[0], 2, 1.2)
			var total_rage = 0
			for hit in rage_hits:
				total_rage += int(hit)
			return ActionResult.new(true, "", {
				"damage": total_rage,
				"damage_instances": rage_hits,
				"attacker_id": actor_id,
				"target_id": targets[0]
			}).to_dict()
		ActionIds.BOS_VENOM_STRIKE:
			if actor != null:
				add_message(_format_enemy_action(actor, action_id, targets))
			var total = 0
			var hit_targets: Array = []
			for t_id in targets:
				var t = get_actor_by_id(t_id)
				if t != null:
					var dmg = randi_range(110, 130)
					_apply_damage_with_limit(actor, t, dmg)
					t.add_status(StatusEffectFactory.poison())
					hit_targets.append(t_id)
					total += dmg
			return ActionResult.new(true, "", {
				"damage_total": total,
				"targets_hit": hit_targets.size(),
				"attacker_id": actor_id
			}).to_dict()

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
	var removals: Array = []
	for status in actor.status_effects:
		var tags = _get_status_tags(status)
		var value = _get_status_value(status)
		if tags.has("DOT"):
			actor.apply_damage(value)
			_add_limit_on_damage_taken(actor, value, LIMIT_GAIN_DOT_DIV)
			add_message(actor.display_name + " takes " + str(value) + " damage.")
			emit_signal("status_tick", actor.id, value, "DOT")
		if tags.has("HOT"):
			actor.heal(value)
			add_message(actor.display_name + " recovers " + str(value) + " HP.")
			emit_signal("status_tick", actor.id, value, "HOT")

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


func _apply_attack_hits(attacker_id: String, target_id: String, hits: int, multiplier: float) -> Array:
	var damages: Array = []
	for _i in range(hits):
		var result = execute_basic_attack(attacker_id, target_id, multiplier)
		damages.append(result.get("payload", {}).get("damage", 0))
	return damages


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
	_check_boss_phase_transition(target)

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
	if attacker == null or defender == null:
		return
	if defender.id != "ludwig":
		return
	if not defender.has_status(StatusEffectIds.GUARD_STANCE):
		return
	if randf() > 0.5:
		return
	var riposte_dmg = DamageCalculator.calculate_physical_damage(defender, attacker, 0.6)
	_apply_damage_with_limit(defender, attacker, riposte_dmg)
	add_message("Riposte! " + defender.display_name + " counters for " + str(riposte_dmg) + " damage.")


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
	var name = actor.display_name if actor != null else actor_id
	var label = _display_action_name(action.get("action_id", ""))
	var targets = action.get("targets", [])
	if targets.is_empty():
		return name + " prepares " + label + "..."
	var target_names = []
	for target_id in targets:
		var target = get_actor_by_id(target_id)
		if target != null:
			target_names.append(target.display_name)
	return name + " prepares " + label + " on " + ", ".join(target_names) + "..."


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
