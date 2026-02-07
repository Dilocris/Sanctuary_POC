extends RefCounted
class_name ActionResolver

## ActionResolver - Resolves action dictionaries into combat outcomes

var _battle_manager: BattleManager
var _pipeline: ActionPipeline


func setup(battle_manager: BattleManager) -> void:
	_battle_manager = battle_manager
	if _pipeline == null:
		_pipeline = ActionPipeline.new()
		_pipeline.setup(battle_manager)


func execute_basic_attack(attacker_id: String, target_id: String, multiplier: float = 1.0) -> Dictionary:
	var action = {
		"action_id": ActionIds.BASIC_ATTACK,
		"actor_id": attacker_id,
		"targets": [target_id],
		"multiplier": multiplier
	}
	var spec = _build_physical_attack_spec(action, multiplier)
	return _pipeline.execute(action, spec)


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
			var spec = _build_physical_attack_spec(action, action.get("multiplier", 1.0))
			spec.pre_hooks = [Callable(self, "_hook_consume_resources")]
			spec.log_entries = ["{attacker} attacks {target} for {damage}!"]
			return _pipeline.execute(action, spec)
		ActionIds.SKIP_TURN:
			var spec = {
				"actor_id": actor_id,
				"targets": [],
				"requires_target": false,
				"log_entries": ["Action skipped."],
				"tags": ["skip"]
			}
			return _pipeline.execute(action, spec)
		ActionIds.KAI_FLURRY:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			var flurry_hits = _calculate_physical_hits(actor, targets[0], 2, action.get("multiplier", 1.0))
			var spec = _build_physical_attack_spec(action, action.get("multiplier", 1.0))
			spec.pre_hooks = [Callable(self, "_hook_consume_resources")]
			spec.damage_instances = flurry_hits
			spec.log_entries = ["{attacker} unleashes a flurry on {target} for {damage}!"]
			return _pipeline.execute(action, spec)
		ActionIds.KAI_STUN_STRIKE:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			var spec = _build_physical_attack_spec(action, action.get("multiplier", 1.0))
			spec.pre_hooks = [Callable(self, "_hook_consume_resources")]
			spec.status_effects = [{
				"target_id": targets[0],
				"status": StatusEffectFactory.stun(1),
				"status_id": StatusEffectIds.STUN,
				"chance": _battle_manager.STUNNING_STRIKE_PROC_CHANCE,
				"on_apply": Callable(self, "_on_apply_stun")
			}]
			spec.log_entries = ["{attacker} strikes {target} for {damage}!"]
			return _pipeline.execute(action, spec)
		ActionIds.KAI_FIRE_IMBUE:
			var spec = {
				"actor_id": actor_id,
				"targets": [],
				"requires_target": false,
				"pre_hooks": [Callable(self, "_hook_toggle_fire_imbue")]
			}
			return _pipeline.execute(action, spec)
		ActionIds.LUD_GUARD_STANCE:
			var spec = {
				"actor_id": actor_id,
				"targets": [],
				"requires_target": false,
				"pre_hooks": [Callable(self, "_hook_toggle_guard_stance")]
			}
			return _pipeline.execute(action, spec)
		ActionIds.LUD_LUNGING:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			var spec = _build_physical_attack_spec(action, action.get("multiplier", 1.2))
			spec.pre_hooks = [Callable(self, "_hook_consume_resources")]
			spec.bonus_range = [1, 8]
			spec.log_entries = [
				"{attacker} lunges at {target} for {damage}!",
				"{attacker} lunges! Bonus {bonus} damage!"
			]
			return _pipeline.execute(action, spec)
		ActionIds.LUD_PRECISION:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			var spec = _build_physical_attack_spec(action, action.get("multiplier", 1.2))
			spec.pre_hooks = [Callable(self, "_hook_consume_resources")]
			spec.bonus_range = [1, 8]
			spec.log_entries = [
				"{attacker} strikes {target} precisely for {damage}!",
				"{attacker} strikes precisely! Bonus {bonus} damage!"
			]
			return _pipeline.execute(action, spec)
		ActionIds.LUD_SHIELD_BASH:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			var spec = _build_physical_attack_spec(action, 1.0)
			spec.pre_hooks = [Callable(self, "_hook_consume_resources")]
			spec.status_effects = [{
				"target_id": targets[0],
				"status": StatusEffectFactory.stun(1),
				"status_id": StatusEffectIds.STUN,
				"chance": _battle_manager.SHIELD_BASH_STUN_CHANCE,
				"on_apply": Callable(self, "_on_apply_shield_bash")
			}]
			spec.log_entries = ["{attacker} bashes {target} for {damage}!"]
			return _pipeline.execute(action, spec)
		ActionIds.LUD_RALLY:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			var heal_amt = randi_range(1, 8) + 5
			var spec = {
				"actor_id": actor_id,
				"targets": targets,
				"requires_target": true,
				"heal": heal_amt,
				"pre_hooks": [Callable(self, "_hook_consume_resources")],
				"log_entries": ["{attacker} rallies {target} for {healed} HP!"]
			}
			return _pipeline.execute(action, spec)
		ActionIds.NINOS_HEALING_WORD:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			var heal_val = randi_range(2, 8) + 5
			var spec = {
				"actor_id": actor_id,
				"targets": targets,
				"requires_target": true,
				"heal": heal_val,
				"pre_hooks": [Callable(self, "_hook_consume_resources")],
				"log_entries": ["{attacker} heals {target} for {healed} HP!"]
			}
			return _pipeline.execute(action, spec)
		ActionIds.NINOS_VICIOUS_MOCKERY:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			var damage_vm = 15 + (int(actor.stats.mag * 0.3) if actor else 0)
			damage_vm = _battle_manager._apply_bless_bonus(actor, damage_vm)
			var spec = {
				"actor_id": actor_id,
				"targets": targets,
				"requires_target": true,
				"damage": damage_vm,
				"pre_hooks": [Callable(self, "_hook_consume_resources")],
				"status_effects": [{
					"target_id": targets[0],
					"status": StatusEffectFactory.atk_down(),
					"status_id": StatusEffectIds.ATK_DOWN
				}],
				"log_entries": ["{attacker} mocks {target}! {damage} dmg + ATK Down!"]
			}
			return _pipeline.execute(action, spec)
		ActionIds.NINOS_BLESS:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			var status_entries: Array = []
			for t_id in targets:
				status_entries.append({
					"target_id": t_id,
					"status": StatusEffectFactory.bless_buff(),
					"status_id": StatusEffectIds.BLESS
				})
			var spec = {
				"actor_id": actor_id,
				"targets": targets,
				"requires_target": true,
				"pre_hooks": [Callable(self, "_hook_consume_resources")],
				"status_effects": status_entries,
				"log_entries": ["{attacker} blesses the party!"]
			}
			return _pipeline.execute(action, spec)
		ActionIds.NINOS_INSPIRE_ATTACK:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			var spec = {
				"actor_id": actor_id,
				"targets": targets,
				"requires_target": true,
				"pre_hooks": [Callable(self, "_hook_consume_resources")],
				"status_effects": [{
					"target_id": targets[0],
					"status": StatusEffectFactory.inspire_attack(),
					"status_id": StatusEffectIds.INSPIRE_ATTACK
				}],
				"log_entries": ["{attacker} inspires {target} (Attack)!"]
			}
			return _pipeline.execute(action, spec)
		ActionIds.CAT_FIRE_BOLT:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			var dmg_fb = randi_range(1, 10) + (int(actor.stats.mag * 0.5) if actor else 0)
			dmg_fb = _battle_manager._apply_genies_wrath_bonus(actor, dmg_fb)
			dmg_fb = _battle_manager._apply_bless_bonus(actor, dmg_fb)
			var spec = {
				"actor_id": actor_id,
				"targets": targets,
				"requires_target": true,
				"damage_by_target": {targets[0]: dmg_fb},
				"pre_hooks": [
					Callable(self, "_hook_consume_resources"),
					Callable(self, "_hook_consume_genies_wrath"),
					Callable(self, "_hook_fire_bolt_metamagic")
				],
				"log_entries": ["{attacker} casts Fire Bolt at {target}! {damage} Fire dmg"]
			}
			return _pipeline.execute(action, spec)
		ActionIds.CAT_FIREBALL:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			var hit_targets = []
			var damage_by_target := {}
			for t_id in targets:
				var t_fireball = _battle_manager.get_actor_by_id(t_id)
				if t_fireball != null:
					var dmg_val = randi_range(8, 64) # 8d6 roughly
					# For poc, simple formula:
					dmg_val = randi_range(20, 50) + (actor.stats.mag if actor else 0)
					dmg_val = _battle_manager._apply_genies_wrath_bonus(actor, dmg_val)
					dmg_val = _battle_manager._apply_bless_bonus(actor, dmg_val)
					hit_targets.append(t_fireball.display_name)
					damage_by_target[t_id] = dmg_val
			var spec = {
				"actor_id": actor_id,
				"targets": targets,
				"requires_target": true,
				"damage_by_target": damage_by_target,
				"pre_hooks": [
					Callable(self, "_hook_consume_resources"),
					Callable(self, "_hook_consume_genies_wrath"),
					Callable(self, "_hook_fireball_metamagic")
				],
				"log_entries": ["{attacker} casts Fireball! Hits: " + ", ".join(hit_targets)]
			}
			return _pipeline.execute(action, spec)
		ActionIds.CAT_MAGE_ARMOR:
			if actor != null:
				if actor.has_status(StatusEffectIds.MAGE_ARMOR):
					return ActionResult.new(false, "already_active").to_dict()
				var spec = {
					"actor_id": actor_id,
					"targets": [actor_id],
					"requires_target": true,
					"pre_hooks": [
						Callable(self, "_hook_consume_resources"),
						Callable(self, "_hook_consume_genies_wrath"),
						Callable(self, "_hook_mage_armor_metamagic")
					],
					"status_effects": [{
						"target_id": actor_id,
						"status": StatusEffectFactory.mage_armor(),
						"status_id": StatusEffectIds.MAGE_ARMOR
					}],
					"log_entries": ["{attacker} casts Mage Armor!"]
				}
				return _pipeline.execute(action, spec)
			return ActionResult.new(false, "missing_actor").to_dict()
		ActionIds.KAI_LIMIT:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			var hit_list: Array = []
			var target = _battle_manager.get_actor_by_id(targets[0])
			for _i in range(4):
				var base = DamageCalculator.calculate_physical_damage(actor, target, 0.8)
				var bonus = randi_range(1, 6)
				var total = base + bonus
				hit_list.append(total)
			var last_base = DamageCalculator.calculate_physical_damage(actor, target, 2.0)
			var last_bonus = randi_range(4, 24)
			var last_total = (last_base * 2) + last_bonus
			hit_list.append(last_total)
			var spec = _build_physical_attack_spec(action, 1.0)
			spec.pre_hooks = [Callable(self, "_hook_reset_limit")]
			spec.damage_instances = hit_list
			spec.allow_crit = false
			spec.log_entries = ["{attacker} unleashes Inferno Fist!"]
			return _pipeline.execute(action, spec)
		ActionIds.LUD_LIMIT:
			var charm_entries: Array = []
			for enemy in _battle_manager.get_alive_enemies():
				charm_entries.append({
					"target_id": enemy.id,
					"status": StatusEffectFactory.charm(1),
					"status_id": StatusEffectIds.CHARM,
					"chance": _battle_manager.DRAGONFIRE_CHARM_CHANCE
				})
			var buff_entries: Array = []
			for ally in _battle_manager.get_alive_party():
				buff_entries.append({
					"target_id": ally.id,
					"status": StatusEffectFactory.atk_up(3, 0.25),
					"status_id": StatusEffectIds.ATK_UP
				})
			var spec = {
				"actor_id": actor_id,
				"targets": _collect_ids(_battle_manager.get_alive_party()),
				"requires_target": false,
				"pre_hooks": [Callable(self, "_hook_reset_limit")],
				"status_effects": charm_entries + buff_entries,
				"log_entries": ["{attacker} unleashes Dragonfire Roar!"]
			}
			return _pipeline.execute(action, spec)
		ActionIds.NINOS_LIMIT:
			var allies = _battle_manager.get_alive_party()
			var heal_targets: Array = []
			var heal_map := {}
			var status_entries: Array = []
			for ally in allies:
				heal_targets.append(ally.id)
				heal_map[ally.id] = 80
				status_entries.append({
					"target_id": ally.id,
					"status": StatusEffectFactory.regen(3, 15),
					"status_id": StatusEffectIds.REGEN
				})
			var spec = {
				"actor_id": actor_id,
				"targets": heal_targets,
				"requires_target": false,
				"heal_by_target": heal_map,
				"pre_hooks": [Callable(self, "_hook_reset_limit")],
				"post_hooks": [Callable(self, "_hook_remove_negative_statuses")],
				"status_effects": status_entries,
				"log_entries": ["{attacker} sings Siren's Call!"]
			}
			return _pipeline.execute(action, spec)
		ActionIds.CAT_LIMIT:
			if actor != null:
				var spec = {
					"actor_id": actor_id,
					"targets": [actor_id],
					"requires_target": false,
					"pre_hooks": [Callable(self, "_hook_reset_limit")],
					"status_effects": [{
						"target_id": actor_id,
						"status": StatusEffectFactory.genies_wrath(3),
						"status_id": StatusEffectIds.GENIES_WRATH
					}],
					"log_entries": ["{attacker} invokes Genie's Wrath!"]
				}
				return _pipeline.execute(action, spec)
			return ActionResult.new(false, "missing_actor").to_dict()
		ActionIds.CAT_METAMAGIC_QUICKEN:
			if actor != null:
				if _battle_manager.battle_state.flags.get("quicken_used_this_round", false):
					return ActionResult.new(false, "quicken_already_used").to_dict()
				var spec = {
					"actor_id": actor_id,
					"targets": [],
					"requires_target": false,
					"pre_hooks": [Callable(self, "_hook_prepare_quicken")],
					"log_entries": ["{attacker} prepares Quicken Spell."]
				}
				return _pipeline.execute(action, spec)
			return ActionResult.new(false, "missing_actor").to_dict()
		ActionIds.CAT_METAMAGIC_TWIN:
			if actor != null:
				var spec = {
					"actor_id": actor_id,
					"targets": [],
					"requires_target": false,
					"pre_hooks": [Callable(self, "_hook_prepare_twin")],
					"log_entries": ["{attacker} prepares Twin Spell."]
				}
				return _pipeline.execute(action, spec)
			return ActionResult.new(false, "missing_actor").to_dict()
		ActionIds.BOS_GREATAXE_SLAM:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			var spec = _build_physical_attack_spec(action, action.get("multiplier", 1.2))
			spec.pre_hooks = [Callable(self, "_hook_enemy_action_log")]
			return _pipeline.execute(action, spec)
		ActionIds.BOS_TENDRIL_LASH:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			var spec = _build_physical_attack_spec(action, action.get("multiplier", 0.8))
			spec.pre_hooks = [Callable(self, "_hook_enemy_action_log")]
			spec.status_effects = [{
				"target_id": targets[0],
				"status": StatusEffectFactory.poison(),
				"status_id": StatusEffectIds.POISON,
				"on_apply": Callable(self, "_on_apply_poison")
			}]
			return _pipeline.execute(action, spec)
		ActionIds.BOS_BATTLE_ROAR:
			if actor != null:
				var spec = {
					"actor_id": actor_id,
					"targets": [actor_id],
					"requires_target": false,
					"pre_hooks": [Callable(self, "_hook_battle_roar")],
					"log_entries": [_battle_manager._format_enemy_action(actor, action_id, [])]
				}
				return _pipeline.execute(action, spec)
			return ActionResult.new(false, "missing_actor").to_dict()
		ActionIds.BOS_COLLECTORS_GRASP:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			var spec = {
				"actor_id": actor_id,
				"targets": targets,
				"requires_target": true,
				"pre_hooks": [Callable(self, "_hook_collectors_grasp")],
				"log_entries": [_battle_manager._format_enemy_action(actor, action_id, targets)]
			}
			return _pipeline.execute(action, spec)
		ActionIds.BOS_DARK_REGEN:
			if actor != null:
				var heal = randi_range(80, 130)
				var spec = {
					"actor_id": actor_id,
					"targets": [actor_id],
					"requires_target": false,
					"heal": heal,
					"pre_hooks": [Callable(self, "_hook_enemy_action_log")],
					"log_entries": ["{attacker} regenerates {healed} HP!"]
				}
				return _pipeline.execute(action, spec)
			return ActionResult.new(false, "missing_actor").to_dict()
		ActionIds.BOS_SYMBIOTIC_RAGE:
			if targets.size() == 0:
				return ActionResult.new(false, "missing_target").to_dict()
			var rage_hits = _calculate_physical_hits(actor, targets[0], 2, 1.2)
			var spec = _build_physical_attack_spec(action, 1.2)
			spec.pre_hooks = [Callable(self, "_hook_enemy_action_log")]
			spec.damage_instances = rage_hits
			return _pipeline.execute(action, spec)
		ActionIds.BOS_VENOM_STRIKE:
			var damage_map := {}
			var poison_entries: Array = []
			for t_id in targets:
				var t = _battle_manager.get_actor_by_id(t_id)
				if t != null:
					var dmg = randi_range(110, 130)
					damage_map[t_id] = dmg
					poison_entries.append({
						"target_id": t_id,
						"status": StatusEffectFactory.poison(),
						"status_id": StatusEffectIds.POISON,
						"on_apply": Callable(self, "_on_apply_poison")
					})
			var spec = {
				"actor_id": actor_id,
				"targets": targets,
				"requires_target": true,
				"damage_by_target": damage_map,
				"status_effects": poison_entries,
				"pre_hooks": [Callable(self, "_hook_enemy_action_log")]
			}
			return _pipeline.execute(action, spec)

		_:
			return ActionResult.new(false, "unknown_action").to_dict()


func _apply_damage_with_limit(attacker: Character, target: Character, amount: int) -> void:
	if target == null:
		return
	target.apply_damage(amount)
	_battle_manager._update_limit_gauges(attacker, target, amount)
	_battle_manager._check_boss_phase_transition(target)


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


func _build_physical_attack_spec(action: Dictionary, multiplier: float) -> Dictionary:
	return {
		"actor_id": action.get("actor_id", ""),
		"targets": action.get("targets", []),
		"requires_target": true,
		"damage_mode": "physical",
		"multiplier": multiplier,
		"allow_crit": true,
		"allow_inspire_bonus": true,
		"allow_riposte": true
	}


func _calculate_physical_hits(attacker: Character, target_id: String, hits: int, multiplier: float) -> Array:
	var damages: Array = []
	var target = _battle_manager.get_actor_by_id(target_id)
	if attacker == null or target == null:
		return damages
	for _i in range(hits):
		damages.append(DamageCalculator.calculate_physical_damage(attacker, target, multiplier))
	return damages


func _hook_consume_resources(ctx: Dictionary) -> void:
	ctx.actor.consume_resources(ctx.action)


func _hook_consume_genies_wrath(ctx: Dictionary) -> void:
	_battle_manager._consume_genies_wrath_charge(ctx.actor)


func _hook_reset_limit(ctx: Dictionary) -> void:
	ctx.actor.reset_limit_gauge()


func _hook_enemy_action_log(ctx: Dictionary) -> void:
	ctx.log_entries.append(_battle_manager._format_enemy_action(ctx.actor, ctx.action.get("action_id", ""), ctx.target_ids))


func _hook_toggle_fire_imbue(ctx: Dictionary) -> void:
	if ctx.actor.has_status(StatusEffectIds.FIRE_IMBUE):
		ctx.actor.remove_status(StatusEffectIds.FIRE_IMBUE)
		ctx.summary.toggled = "off"
		ctx.log_entries.append("Fire Imbue toggled off.")
		return
	ctx.actor.add_status(StatusEffectFactory.fire_imbue())
	ctx.summary.toggled = "on"
	ctx.log_entries.append("Fire Imbue toggled on.")


func _hook_toggle_guard_stance(ctx: Dictionary) -> void:
	if ctx.actor.has_status(StatusEffectIds.GUARD_STANCE):
		ctx.actor.remove_status(StatusEffectIds.GUARD_STANCE)
		ctx.summary.toggled = "off"
		ctx.log_entries.append("Guard Stance toggled off.")
		return
	ctx.actor.add_status(StatusEffectFactory.guard_stance())
	ctx.summary.toggled = "on"
	ctx.log_entries.append("Guard Stance toggled on.")


func _on_apply_stun(ctx: Dictionary, target: Character) -> void:
	_battle_manager._remove_guard_on_stun(target)
	ctx.log_entries.append(target.display_name + " is stunned!")


func _on_apply_shield_bash(ctx: Dictionary, target: Character) -> void:
	_battle_manager._remove_guard_on_stun(target)
	ctx.log_entries.append(target.display_name + " is stunned by the shield bash!")


func _on_apply_poison(ctx: Dictionary, target: Character) -> void:
	ctx.log_entries.append(target.display_name + " is poisoned!")


func _hook_fire_bolt_metamagic(ctx: Dictionary) -> void:
	var meta = _battle_manager.consume_metamagic(ctx.actor.id)
	if meta.is_empty():
		return
	ctx.summary.metamagic = meta.to_lower()
	if meta == "QUICKEN":
		ctx.summary.quicken = true
	if meta == "TWIN" and ctx.target_ids.size() > 0:
		var primary = ctx.target_ids[0]
		var extra = _battle_manager._get_additional_enemy_target(primary)
		if extra != null:
			ctx.target_ids.append(extra.id)
			var base_damage = ctx.spec.damage_by_target.get(primary, 0)
			ctx.spec.damage_by_target[extra.id] = base_damage
			ctx.log_entries.append("Twin Spell hits " + extra.display_name + " for " + str(base_damage) + "!")


func _hook_fireball_metamagic(ctx: Dictionary) -> void:
	var meta = _battle_manager.consume_metamagic(ctx.actor.id)
	if meta.is_empty():
		return
	ctx.summary.metamagic = meta.to_lower()
	if meta == "QUICKEN":
		ctx.summary.quicken = true


func _hook_mage_armor_metamagic(ctx: Dictionary) -> void:
	var meta = _battle_manager.consume_metamagic(ctx.actor.id)
	if meta.is_empty():
		return
	ctx.summary.metamagic = meta.to_lower()
	if meta == "QUICKEN":
		ctx.summary.quicken = true


func _hook_prepare_quicken(ctx: Dictionary) -> void:
	ctx.actor.consume_resources(ctx.action)
	_battle_manager._set_metamagic(ctx.actor.id, "QUICKEN")
	_battle_manager.battle_state.flags["quicken_used_this_round"] = true
	ctx.summary.metamagic = "quicken"


func _hook_prepare_twin(ctx: Dictionary) -> void:
	ctx.actor.consume_resources(ctx.action)
	_battle_manager._set_metamagic(ctx.actor.id, "TWIN")
	ctx.summary.metamagic = "twin"


func _hook_collectors_grasp(ctx: Dictionary) -> void:
	if ctx.target_ids.is_empty():
		return
	_battle_manager.battle_state.flags.marcus_pull_target = ctx.target_ids[0]
	var pulled = _battle_manager.get_actor_by_id(ctx.target_ids[0])
	if pulled != null:
		ctx.log_entries.append(pulled.display_name + " is dragged toward Marcus!")


func _hook_battle_roar(ctx: Dictionary) -> void:
	var stacks = _battle_manager._count_status(ctx.actor, StatusEffectIds.ATK_UP)
	if stacks < 2:
		ctx.actor.add_status(StatusEffectFactory.atk_up(4, 0.25))
		ctx.log_entries.append(ctx.actor.display_name + " roars and powers up!")
		return
	ctx.log_entries.append(ctx.actor.display_name + " roars, but can't stack more ATK.")


func _hook_remove_negative_statuses(ctx: Dictionary) -> void:
	for target in ctx.targets:
		_battle_manager._remove_negative_statuses(target)


func _collect_ids(actors: Array) -> Array:
	var ids: Array = []
	for actor in actors:
		ids.append(actor.id)
	return ids
