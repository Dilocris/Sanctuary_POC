extends RefCounted
class_name ActionResolver

## ActionResolver - Resolves action dictionaries into combat outcomes

var _battle_manager: BattleManager
var _pipeline: ActionPipeline


func setup(battle_manager: BattleManager) -> void:
	_battle_manager = battle_manager
	_pipeline = ActionPipeline.new()
	_pipeline.setup(battle_manager)


func execute_basic_attack(attacker_id: String, target_id: String, multiplier: float = 1.0, action_tags: Array = []) -> Dictionary:
	if _pipeline == null:
		_pipeline = ActionPipeline.new()
		_pipeline.setup(_battle_manager)
	var attacker = _battle_manager.get_actor_by_id(attacker_id)
	var target = _battle_manager.get_actor_by_id(target_id)
	if attacker == null or target == null:
		return ActionResult.new(false, "invalid_actor").to_dict()
	if attacker.is_ko() or target.is_ko():
		return ActionResult.new(false, "target_ko").to_dict()

	if not _ignores_evasion(action_tags) and _is_attack_evaded(attacker, target):
		_battle_manager.add_message(attacker.display_name + " misses " + target.display_name + "!")
		return ActionResult.new(true, "", {
			"hit": false,
			"damage": 0,
			"attacker_id": attacker_id,
			"target_id": target_id
		}).to_dict()

	var action = {
		"action_id": ActionIds.BASIC_ATTACK,
		"actor_id": attacker_id,
		"targets": [target_id],
		"tags": action_tags
	}
	var spec = {
		"actor_id": attacker_id,
		"targets": [target_id],
		"requires_target": true,
		"damage_mode": "physical",
		"multiplier": multiplier,
		"allow_crit": false,
		"allow_inspire_bonus": true,
		"log_entries": ["{attacker} attacks {target} for {damage}!"]
	}
	var pipeline_result = _pipeline.execute(action, spec)
	if not pipeline_result.get("ok", false):
		return pipeline_result
	var summary = pipeline_result.get("payload", {}).get("summary", {})
	var damage = int(summary.get("damage_total", 0))
	var bonus_dmg = int(summary.get("bonus_damage", 0))
	_apply_fire_imbue_burn(attacker, target)
	return ActionResult.new(true, "", {
		"hit": true,
		"damage": damage,
		"bonus": bonus_dmg,
		"damage_components": summary.get("damage_components", []),
		"damage_components_by_hit": summary.get("damage_components_by_hit", []),
		"damage_sources": summary.get("damage_sources", []),
		"attacker_id": attacker_id,
		"target_id": target_id
	}).to_dict()


func _resolve_action(action: Dictionary) -> Dictionary:
	var action_id = action.get("action_id", "")
	var actor_id = action.get("actor_id", "")
	var targets = action.get("targets", [])
	var actor = _battle_manager.get_actor_by_id(actor_id)
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
			return execute_basic_attack(actor_id, targets[0], action.get("multiplier", 1.0), action.get("tags", []))
		ActionIds.SKIP_TURN:
			_battle_manager.add_message("Action skipped.")
			return ActionResult.new(true, "", {"skipped": true}).to_dict()
		ActionIds.KAI_FLURRY:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			if actor != null:
				actor.consume_resources(action)
			var flurry_hit_payloads = _battle_manager._apply_attack_hits(actor_id, targets[0], 2, action.get("multiplier", 1.0), action.get("tags", []))
			var flurry_hits: Array = []
			var flurry_components_by_hit: Array = []
			var flurry_total = 0
			for hit_payload in flurry_hit_payloads:
				var hit_damage = int(hit_payload.get("damage", 0))
				flurry_hits.append(hit_damage)
				flurry_total += hit_damage
				flurry_components_by_hit.append(hit_payload.get("damage_components", []))
			return ActionResult.new(true, "", {
				"damage": flurry_total,
				"damage_instances": flurry_hits,
				"damage_components_by_hit": flurry_components_by_hit,
				"hits": 2,
				"attacker_id": actor_id,
				"target_id": targets[0]
			}).to_dict()
		ActionIds.KAI_STUN_STRIKE:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			if actor != null:
				actor.consume_resources(action)
			var stun_damage = execute_basic_attack(actor_id, targets[0], action.get("multiplier", 1.0), action.get("tags", []))
			var applied = false
			if stun_damage.get("payload", {}).get("hit", false) and randf() <= _battle_manager.STUNNING_STRIKE_PROC_CHANCE:
				var target = _battle_manager.get_actor_by_id(targets[0])
				if target != null:
					target.add_status(StatusEffectFactory.stun(1))
					_battle_manager._remove_guard_on_stun(target)
					applied = true
					_battle_manager.add_message(target.display_name + " is stunned!")
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
					_battle_manager.battle_state.flags["fire_imbue_skip_drain"] = false
					_battle_manager.add_message("Fire Imbue toggled off.")
					return ActionResult.new(true, "", {"toggled": "off"}).to_dict()
				actor.add_status(StatusEffectFactory.fire_imbue())
				_battle_manager.battle_state.flags["fire_imbue_skip_drain"] = true
				_battle_manager.add_message("Fire Imbue toggled on.")
				return ActionResult.new(true, "", {"toggled": "on"}).to_dict()
			return ActionResult.new(false, "missing_actor").to_dict()
		ActionIds.LUD_GUARD_STANCE:
			if actor != null:
				if actor.has_status(StatusEffectIds.GUARD_STANCE):
					actor.remove_status(StatusEffectIds.GUARD_STANCE)
					_battle_manager.add_message("Guard Stance toggled off.")
					return ActionResult.new(true, "", {"toggled": "off"}).to_dict()
				actor.add_status(StatusEffectFactory.guard_stance())
				_battle_manager.add_message("Guard Stance toggled on.")
				return ActionResult.new(true, "", {"toggled": "on"}).to_dict()
			return ActionResult.new(false, "missing_actor").to_dict()
		ActionIds.LUD_LUNGING:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			if actor != null:
				actor.consume_resources(action)
			var base_result = execute_basic_attack(actor_id, targets[0], action.get("multiplier", 1.2), action.get("tags", []))
			var bonus_dmg = 0
			var total_dmg = base_result.get("payload", {}).get("damage", 0)
			var target_lung = _battle_manager.get_actor_by_id(targets[0])
			if target_lung != null and base_result.get("payload", {}).get("hit", false):
				bonus_dmg = randi_range(1, 8)
				_apply_damage_with_limit(actor, target_lung, bonus_dmg)
				_battle_manager.add_message(actor.display_name + " lunges! Bonus " + str(bonus_dmg) + " damage!")
				total_dmg += bonus_dmg
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
			# Precision ignores evasion through ActionTags.IGNORES_EVASION.
			var base_prec = execute_basic_attack(actor_id, targets[0], action.get("multiplier", 1.2), action.get("tags", []))
			var bonus_prec = 0
			var total_prec = base_prec.get("payload", {}).get("damage", 0)
			var target_prec = _battle_manager.get_actor_by_id(targets[0])
			if target_prec != null and base_prec.get("payload", {}).get("hit", false):
				bonus_prec = randi_range(1, 8)
				_apply_damage_with_limit(actor, target_prec, bonus_prec)
				_battle_manager.add_message(actor.display_name + " strikes precisely! Bonus " + str(bonus_prec) + " damage!")
				total_prec += bonus_prec
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
			var bash_result = execute_basic_attack(actor_id, targets[0], 1.0, action.get("tags", []))
			var stunned = false
			if bash_result.get("payload", {}).get("hit", false) and randf() <= _battle_manager.SHIELD_BASH_STUN_CHANCE:
				var target_bash = _battle_manager.get_actor_by_id(targets[0])
				if target_bash != null:
					target_bash.add_status(StatusEffectFactory.stun(1))
					_battle_manager._remove_guard_on_stun(target_bash)
					stunned = true
					_battle_manager.add_message(target_bash.display_name + " is stunned by the shield bash!")
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
			var target_rally = _battle_manager.get_actor_by_id(targets[0])
			var heal_amt = randi_range(1, 8) + 5
			if target_rally != null:
				target_rally.heal(heal_amt)
				_battle_manager.add_message(actor.display_name + " rallies " + target_rally.display_name + " for " + str(heal_amt) + " HP!")
			return ActionResult.new(true, "", {
				"healed": heal_amt,
				"attacker_id": actor_id,
				"target_id": targets[0]
			}).to_dict()
		ActionIds.LUD_TAUNT:
			if actor != null:
				actor.consume_resources(action)
				actor.add_status(StatusEffectFactory.taunt(2))
				_battle_manager.add_message(actor.display_name + " taunts the enemy and draws its focus!")
				return ActionResult.new(true, "", {
					"buff": "taunt",
					"attacker_id": actor_id,
					"target_id": actor_id
				}).to_dict()
			return ActionResult.new(false, "missing_actor").to_dict()
		ActionIds.NINOS_HEALING_WORD:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			if actor != null:
				actor.consume_resources(action)
			var target_hw = _battle_manager.get_actor_by_id(targets[0])
			var heal_val = randi_range(2, 8) + 5
			if target_hw != null:
				target_hw.heal(heal_val)
				_battle_manager.add_message(actor.display_name + " heals " + target_hw.display_name + " for " + str(heal_val) + " HP!")
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
			var target_vm = _battle_manager.get_actor_by_id(targets[0])
			var damage_vm = 15 + (int(actor.stats.mag * 0.3) if actor else 0)
			damage_vm = _battle_manager._apply_bless_bonus(actor, damage_vm)
			if target_vm != null:
				_apply_damage_with_limit(actor, target_vm, damage_vm)
				target_vm.add_status(StatusEffectFactory.atk_down())
				_battle_manager.add_message(actor.display_name + " mocks " + target_vm.display_name + "! " + str(damage_vm) + " dmg + ATK Down!")
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
				var t_bless = _battle_manager.get_actor_by_id(t_id)
				if t_bless != null:
					t_bless.add_status(StatusEffectFactory.bless_buff())
			_battle_manager.add_message(actor.display_name + " blesses the party!")
			return ActionResult.new(true, "", {
				"buff": "bless",
				"targets": targets,
				"attacker_id": actor_id
			}).to_dict()
		ActionIds.NINOS_CLEANSE:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			if actor != null:
				actor.consume_resources(action)
			var target_cleanse = _battle_manager.get_actor_by_id(targets[0])
			if target_cleanse == null:
				return ActionResult.new(false, "missing_target").to_dict()
			_battle_manager._remove_negative_statuses(target_cleanse)
			var cleanse_heal = 20
			target_cleanse.heal(cleanse_heal)
			_battle_manager.add_message(actor.display_name + " cleanses " + target_cleanse.display_name + "!")
			return ActionResult.new(true, "", {
				"healed": cleanse_heal,
				"buff": "cleanse",
				"attacker_id": actor_id,
				"target_id": targets[0]
			}).to_dict()
		ActionIds.NINOS_INSPIRE_ATTACK:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			if actor != null:
				actor.consume_resources(action)
			var target_inspire = _battle_manager.get_actor_by_id(targets[0])
			if target_inspire != null:
				target_inspire.add_status(StatusEffectFactory.inspire_attack())
				_battle_manager.add_message(actor.display_name + " inspires " + target_inspire.display_name + " (Attack)!")
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
				_battle_manager._consume_genies_wrath_charge(actor)
			var target_fb = _battle_manager.get_actor_by_id(targets[0])
			var meta = _battle_manager.consume_metamagic(actor_id)
			var dmg_fb = randi_range(1, 10) + (int(actor.stats.mag * 0.5) if actor else 0)
			dmg_fb = _battle_manager._apply_genies_wrath_bonus(actor, dmg_fb)
			dmg_fb = _battle_manager._apply_bless_bonus(actor, dmg_fb)
			if target_fb != null:
				_apply_damage_with_limit(actor, target_fb, dmg_fb)
				_battle_manager.add_message(actor.display_name + " casts Fire Bolt at " + target_fb.display_name + "! " + str(dmg_fb) + " Fire dmg")
				if meta == "TWIN":
					var extra = _battle_manager._get_additional_enemy_target(targets[0])
					if extra != null:
						_apply_damage_with_limit(actor, extra, dmg_fb)
						_battle_manager.add_message("Twin Spell hits " + extra.display_name + " for " + str(dmg_fb) + "!")
			return ActionResult.new(true, "", {
				"damage": dmg_fb,
				"damage_components": [{"type": "normal", "label": "BASE", "amount": dmg_fb}],
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
				_battle_manager._consume_genies_wrath_charge(actor)
			var meta_fb = _battle_manager.consume_metamagic(actor_id)
			var total_dmg_fireball = 0
			var hit_targets = []
			var multi_target_damage: Array = []
			for t_id in targets:
				var t_fireball = _battle_manager.get_actor_by_id(t_id)
				if t_fireball != null:
					var dmg_val = randi_range(8, 64) # 8d6 roughly
					# For poc, simple formula:
					dmg_val = randi_range(20, 50) + (actor.stats.mag if actor else 0)
					dmg_val = _battle_manager._apply_genies_wrath_bonus(actor, dmg_val)
					dmg_val = _battle_manager._apply_bless_bonus(actor, dmg_val)
					_apply_damage_with_limit(actor, t_fireball, dmg_val)
					hit_targets.append(t_fireball.display_name)
					multi_target_damage.append({
						"target_id": t_id,
						"damage": dmg_val,
						"components": [{"type": "normal", "label": "BASE", "amount": dmg_val}]
					})
					total_dmg_fireball += dmg_val
			_battle_manager.add_message(actor.display_name + " casts Fireball! Hits: " + ", ".join(hit_targets))
			return ActionResult.new(true, "", {
				"damage_total": total_dmg_fireball,
				"multi_target_damage": multi_target_damage,
				"targets_hit": hit_targets.size(),
				"attacker_id": actor_id,
				"quicken": meta_fb == "QUICKEN"
			}).to_dict()
		ActionIds.CAT_MAGE_ARMOR:
			if actor != null:
				var meta_ma = _battle_manager.consume_metamagic(actor_id)
				if actor.has_status(StatusEffectIds.MAGE_ARMOR):
					_battle_manager.add_message(actor.display_name + " already has Mage Armor.")
					return ActionResult.new(false, "already_active").to_dict()
				actor.consume_resources(action)
				_battle_manager._consume_genies_wrath_charge(actor)
				actor.add_status(StatusEffectFactory.mage_armor())
				_battle_manager.add_message(actor.display_name + " casts Mage Armor!")
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
			var target = _battle_manager.get_actor_by_id(targets[0])
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
			_battle_manager.add_message(actor.display_name + " unleashes Inferno Fist!")
			return ActionResult.new(true, "", {
				"damage": sum,
				"damage_instances": hit_list,
				"attacker_id": actor_id,
				"target_id": targets[0]
			}).to_dict()
		ActionIds.LUD_LIMIT:
			if actor != null:
				actor.reset_limit_gauge()
			_battle_manager.add_message(actor.display_name + " unleashes Dragonfire Roar!")
			for enemy in _battle_manager.get_alive_enemies():
				if randf() <= _battle_manager.DRAGONFIRE_CHARM_CHANCE:
					enemy.add_status(StatusEffectFactory.charm(1))
			for ally in _battle_manager.get_alive_party():
				ally.add_status(StatusEffectFactory.atk_up(3, 0.25))
			return ActionResult.new(true, "", {
				"buff": "atk_up",
				"debuff": "charm",
				"attacker_id": actor_id
			}).to_dict()
		ActionIds.NINOS_LIMIT:
			if actor != null:
				actor.reset_limit_gauge()
			_battle_manager.add_message(actor.display_name + " sings Siren's Call!")
			for ally in _battle_manager.get_alive_party():
				ally.heal(80)
				_battle_manager._remove_negative_statuses(ally)
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
				_battle_manager.add_message(actor.display_name + " invokes Genie's Wrath!")
				return ActionResult.new(true, "", {"buff": "genies_wrath", "attacker_id": actor_id}).to_dict()
			return ActionResult.new(false, "missing_actor").to_dict()
		ActionIds.CAT_METAMAGIC_QUICKEN:
			if actor != null:
				if _battle_manager.battle_state.flags.get("quicken_used_this_round", false):
					_battle_manager.add_message("Quicken Spell already used this round.")
					return ActionResult.new(false, "quicken_already_used").to_dict()
				actor.consume_resources(action)
				_battle_manager._set_metamagic(actor_id, "QUICKEN")
				_battle_manager.battle_state.flags["quicken_used_this_round"] = true
				_battle_manager.add_message(actor.display_name + " prepares Quicken Spell.")
				return ActionResult.new(true, "", {"metamagic": "quicken"}).to_dict()
			return ActionResult.new(false, "missing_actor").to_dict()
		ActionIds.CAT_METAMAGIC_TWIN:
			if actor != null:
				actor.consume_resources(action)
				_battle_manager._set_metamagic(actor_id, "TWIN")
				_battle_manager.add_message(actor.display_name + " prepares Twin Spell.")
				return ActionResult.new(true, "", {"metamagic": "twin"}).to_dict()
			return ActionResult.new(false, "missing_actor").to_dict()
		ActionIds.BOS_GREATAXE_SLAM:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			if actor != null:
				_battle_manager.add_message(_battle_manager._format_enemy_action(actor, action_id, targets))
			return execute_basic_attack(actor_id, targets[0], action.get("multiplier", 1.2), action.get("tags", []))
		ActionIds.BOS_TENDRIL_LASH:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			if actor != null:
				_battle_manager.add_message(_battle_manager._format_enemy_action(actor, action_id, targets))
			var lash_result = execute_basic_attack(actor_id, targets[0], action.get("multiplier", 0.8), action.get("tags", []))
			var target_lash = _battle_manager.get_actor_by_id(targets[0])
			if target_lash != null and lash_result.get("payload", {}).get("hit", false):
				target_lash.add_status(StatusEffectFactory.poison())
				_battle_manager.add_message(target_lash.display_name + " is poisoned!")
			return lash_result
		ActionIds.BOS_BATTLE_ROAR:
			if actor != null:
				_battle_manager.add_message(_battle_manager._format_enemy_action(actor, action_id, []))
				var stacks = _battle_manager._count_status(actor, StatusEffectIds.ATK_UP)
				if stacks < 2:
					actor.add_status(StatusEffectFactory.atk_up(4, 0.25))
					_battle_manager.add_message(actor.display_name + " roars and powers up!")
				else:
					_battle_manager.add_message(actor.display_name + " roars, but can't stack more ATK.")
				return ActionResult.new(true, "", {"buff": "atk_up"}).to_dict()
			return ActionResult.new(false, "missing_actor").to_dict()
		ActionIds.BOS_COLLECTORS_GRASP:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			if actor != null:
				_battle_manager.add_message(_battle_manager._format_enemy_action(actor, action_id, targets))
			_battle_manager.battle_state.flags.marcus_pull_target = targets[0]
			var pulled = _battle_manager.get_actor_by_id(targets[0])
			if pulled != null:
				var grasp_damage = randi_range(22, 34)
				_apply_damage_with_limit(actor, pulled, grasp_damage)
				pulled.add_status(StatusEffectFactory.atk_down(2, 0.2))
				_battle_manager.add_message(pulled.display_name + " is dragged toward Marcus!")
				_battle_manager.add_message(pulled.display_name + " is weakened by the grasp!")
				return ActionResult.new(true, "", {
					"pull": targets[0],
					"damage": grasp_damage,
					"debuff": "atk_down",
					"attacker_id": actor_id,
					"target_id": targets[0]
				}).to_dict()
			return ActionResult.new(true, "", {"pull": targets[0]}).to_dict()
		ActionIds.BOS_DARK_REGEN:
			if actor != null:
				_battle_manager.add_message(_battle_manager._format_enemy_action(actor, action_id, []))
				var heal = randi_range(80, 130)
				actor.heal(heal)
				_battle_manager.add_message(actor.display_name + " regenerates " + str(heal) + " HP!")
				return ActionResult.new(true, "", {"healed": heal, "attacker_id": actor_id, "target_id": actor_id}).to_dict()
			return ActionResult.new(false, "missing_actor").to_dict()
		ActionIds.BOS_SYMBIOTIC_RAGE:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			if actor != null:
				_battle_manager.add_message(_battle_manager._format_enemy_action(actor, action_id, targets))
			var rage_hit_payloads = _battle_manager._apply_attack_hits(actor_id, targets[0], 2, 1.2, action.get("tags", []))
			var rage_hits: Array = []
			var rage_components_by_hit: Array = []
			var total_rage = 0
			for hit_payload in rage_hit_payloads:
				var rage_damage = int(hit_payload.get("damage", 0))
				rage_hits.append(rage_damage)
				total_rage += rage_damage
				rage_components_by_hit.append(hit_payload.get("damage_components", []))
			return ActionResult.new(true, "", {
				"damage": total_rage,
				"damage_instances": rage_hits,
				"damage_components_by_hit": rage_components_by_hit,
				"attacker_id": actor_id,
				"target_id": targets[0]
			}).to_dict()
		ActionIds.BOS_VENOM_STRIKE:
			if actor != null:
				_battle_manager.add_message(_battle_manager._format_enemy_action(actor, action_id, targets))
			var total = 0
			var hit_targets: Array = []
			var venom_multi_dmg: Array = []
			for t_id in targets:
				var t = _battle_manager.get_actor_by_id(t_id)
				if t != null:
					var dmg = randi_range(110, 130)
					_apply_damage_with_limit(actor, t, dmg)
					t.add_status(StatusEffectFactory.poison())
					hit_targets.append(t_id)
					venom_multi_dmg.append({
						"target_id": t_id,
						"damage": dmg,
						"components": [{"type": "poison", "label": "VENOM", "amount": dmg}]
					})
					total += dmg
			return ActionResult.new(true, "", {
				"damage_total": total,
				"multi_target_damage": venom_multi_dmg,
				"targets_hit": hit_targets.size(),
				"attacker_id": actor_id
			}).to_dict()

		_:
			return ActionResult.new(false, "unknown_action").to_dict()


func _ignores_evasion(action_tags: Array) -> bool:
	return action_tags.has(ActionTags.IGNORES_EVASION)


func _is_attack_evaded(_attacker: Character, target: Character) -> bool:
	if target == null:
		return false
	if not target.has_method("get_evasion_chance"):
		return false
	var evasion = target.get_evasion_chance()
	if evasion <= 0.0:
		return false
	return randf() <= evasion


func _apply_damage_with_limit(attacker: Character, target: Character, amount: int) -> void:
	if target == null:
		return
	target.apply_damage(amount)
	_battle_manager._update_limit_gauges(attacker, target, amount)
	_battle_manager._check_boss_phase_transition(target)


func _apply_fire_imbue_burn(attacker: Character, target: Character) -> void:
	if attacker == null or target == null:
		return
	if not attacker.has_status(StatusEffectIds.FIRE_IMBUE):
		return
	if target.has_status(StatusEffectIds.BURN):
		return
	target.add_status(StatusEffectFactory.burn())
	_battle_manager.add_message(target.display_name + " is burning!")


func _try_riposte(attacker: Character, defender: Character) -> void:
	if attacker == null or defender == null:
		return
	if defender.id != "ludwig":
		return
	if not defender.has_status(StatusEffectIds.GUARD_STANCE):
		return
	if randf() > _battle_manager.RIPOSTE_PROC_CHANCE:
		return
	var riposte_dmg = DamageCalculator.calculate_physical_damage(defender, attacker, 0.6)
	_apply_damage_with_limit(defender, attacker, riposte_dmg)
	_battle_manager.add_message("Riposte! " + defender.display_name + " counters for " + str(riposte_dmg) + " damage.")
