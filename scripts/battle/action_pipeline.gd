extends RefCounted
class_name ActionPipeline

## ActionPipeline - Handles action sequencing and side effects

var _battle_manager: BattleManager

const EVENT_PRE_ACTION := "pre_action"
const EVENT_TARGET_LOCK := "target_lock"
const EVENT_HIT_CHECK := "hit_check"
const EVENT_CRIT_CHECK := "crit_check"
const EVENT_DAMAGE := "damage"
const EVENT_HEAL := "heal"
const EVENT_STATUS := "status"
const EVENT_REACTION := "reaction"
const EVENT_POST_ACTION := "post_action"
const EVENT_KO := "ko"
const EVENT_LOG := "log"


func setup(battle_manager: BattleManager) -> void:
	_battle_manager = battle_manager


func execute(action: Dictionary, spec: Dictionary) -> Dictionary:
	var actor_id = spec.get("actor_id", action.get("actor_id", ""))
	var actor = _battle_manager.get_actor_by_id(actor_id)
	if actor == null:
		return ActionResult.new(false, "missing_actor").to_dict()

	var ctx = {
		"action": action,
		"actor": actor,
		"spec": spec,
		"target_ids": spec.get("targets", []),
		"targets": [],
		"events": [],
		"log_entries": [],
		"summary": {
			"damage": 0,
			"damage_total": 0,
			"damage_instances": [],
			"healed": 0,
			"healed_total": 0,
			"missed": false,
			"crit": false,
			"bonus_damage": 0,
			"statuses": []
		}
	}

	_add_event(ctx, EVENT_PRE_ACTION, {"actor_id": actor_id})
	_run_hooks(spec.get("pre_hooks", []), ctx)

	ctx.targets = _lock_targets({"targets": ctx.target_ids})
	if spec.get("requires_target", false) and ctx.targets.is_empty():
		return ActionResult.new(false, "missing_target").to_dict()

	_add_event(ctx, EVENT_TARGET_LOCK, {"targets": _collect_target_ids(ctx.targets)})
	var hit_success = _resolve_hit_check(spec)
	ctx.summary.missed = not hit_success
	_add_event(ctx, EVENT_HIT_CHECK, {"hit": hit_success, "chance": spec.get("hit_chance", 1.0)})

	if hit_success:
		var crit_success = _resolve_crit_check(spec)
		ctx.summary.crit = crit_success
		_add_event(ctx, EVENT_CRIT_CHECK, {"crit": crit_success, "chance": spec.get("crit_chance", DamageCalculator.BASE_CRIT_CHANCE)})
		_apply_damage(ctx, spec)
		_apply_heal(ctx, spec)
		_apply_statuses(ctx, spec)
		_handle_reaction_window(ctx, spec)

	_run_hooks(spec.get("post_hooks", []), ctx)
	_add_event(ctx, EVENT_POST_ACTION, {"actor_id": actor_id})

	_check_ko(ctx)
	_update_ui_logs(ctx, spec)

	return ActionResult.new(true, "", _build_payload(ctx, spec)).to_dict()


func _lock_targets(spec: Dictionary) -> Array:
	var targets: Array = []
	for target_id in spec.get("targets", []):
		var target = _battle_manager.get_actor_by_id(target_id)
		if target != null:
			targets.append(target)
	return targets


func _resolve_hit_check(spec: Dictionary) -> bool:
	var chance = spec.get("hit_chance", 1.0)
	if chance >= 1.0:
		return true
	return randf() <= chance


func _resolve_crit_check(spec: Dictionary) -> bool:
	if not spec.get("allow_crit", false):
		return false
	var chance = spec.get("crit_chance", DamageCalculator.BASE_CRIT_CHANCE)
	return randf() <= chance


func _apply_damage(ctx: Dictionary, spec: Dictionary) -> void:
	var actor: Character = ctx.actor
	var targets: Array = ctx.targets
	var summary = ctx.summary
	var damage_instances: Array = []
	var damage_components_by_hit: Array = []
	var damage_sources: Array = []
	var damage_total := 0

	if targets.is_empty():
		return

	var base_damage_instances: Array = []
	var physical_breakdowns: Array = []
	var bonus = _resolve_bonus_damage(ctx, spec)

	if spec.has("damage_by_target"):
		for target in targets:
			var target_damage = spec.damage_by_target.get(target.id, null)
			if target_damage == null:
				continue
			var per_target_instances: Array = []
			if target_damage is Array:
				per_target_instances = target_damage
			else:
				per_target_instances = [target_damage]
			for base_damage in per_target_instances:
				var base_amount = int(base_damage)
				var hit_components: Array = [{"type": "normal", "label": "BASE", "amount": base_amount}]
				var damage_value = base_amount + bonus
				if bonus > 0:
					hit_components.append({"type": "buff", "label": "BONUS", "amount": bonus})
				if ctx.summary.crit:
					var pre_crit = damage_value
					damage_value = int(round(damage_value * DamageCalculator.CRIT_MULTIPLIER))
					hit_components.append({"type": "crit", "label": "CRIT", "amount": damage_value - pre_crit})
				damage_instances.append(damage_value)
				damage_components_by_hit.append(hit_components)
				damage_total += damage_value
				_apply_damage_with_limit(actor, target, damage_value)
				_add_event(ctx, EVENT_DAMAGE, {
					"actor_id": actor.id,
					"target_id": target.id,
					"amount": damage_value,
					"crit": ctx.summary.crit,
					"components": hit_components
				})
	else:
		if spec.has("damage_instances"):
			base_damage_instances = spec.damage_instances
		elif spec.get("damage_mode", "") == "physical":
			var target: Character = targets[0]
			var multiplier = spec.get("multiplier", 1.0)
			var breakdown = DamageCalculator.calculate_physical_damage_breakdown(actor, target, multiplier)
			var base = int(breakdown.get("total", 0))
			base_damage_instances = [base]
			physical_breakdowns.append(breakdown)
		elif spec.has("damage"):
			base_damage_instances = [spec.damage]

		if base_damage_instances.is_empty():
			return

		for i in range(base_damage_instances.size()):
			var base_damage = int(base_damage_instances[i])
			var hit_components: Array = []
			if spec.get("damage_mode", "") == "physical" and i < physical_breakdowns.size():
				var breakdown = physical_breakdowns[i]
				base_damage = int(breakdown.get("total", base_damage))
				hit_components = breakdown.get("components", []).duplicate(true)
			else:
				hit_components.append({"type": "normal", "label": "BASE", "amount": base_damage})
			var damage_value = base_damage + bonus
			if bonus > 0:
				hit_components.append({"type": "buff", "label": "BONUS", "amount": bonus})
			if ctx.summary.crit:
				var pre_crit = damage_value
				damage_value = int(round(damage_value * DamageCalculator.CRIT_MULTIPLIER))
				hit_components.append({"type": "crit", "label": "CRIT", "amount": damage_value - pre_crit})
			damage_instances.append(damage_value)
			damage_components_by_hit.append(hit_components)
			damage_total += damage_value

		var target_to_hit = targets[0]
		for i in range(damage_instances.size()):
			var damage_value = damage_instances[i]
			var hit_components: Array = damage_components_by_hit[i] if i < damage_components_by_hit.size() else []
			_apply_damage_with_limit(actor, target_to_hit, damage_value)
			_add_event(ctx, EVENT_DAMAGE, {
				"actor_id": actor.id,
				"target_id": target_to_hit.id,
				"amount": damage_value,
				"crit": ctx.summary.crit,
				"components": hit_components
			})

	ctx.summary.bonus_damage = bonus
	ctx.summary.damage_instances = damage_instances
	ctx.summary.damage_components_by_hit = damage_components_by_hit
	ctx.summary.damage_components = damage_components_by_hit[0] if damage_components_by_hit.size() > 0 else []
	for comp in ctx.summary.damage_components:
		damage_sources.append(str(comp.get("type", "")))
	ctx.summary.damage_sources = damage_sources
	ctx.summary.damage_total = damage_total
	ctx.summary.damage = damage_instances[0] if damage_instances.size() > 0 else 0


func _resolve_bonus_damage(ctx: Dictionary, spec: Dictionary) -> int:
	var bonus := 0
	if spec.get("allow_inspire_bonus", false) and ctx.actor.has_status(StatusEffectIds.INSPIRE_ATTACK):
		bonus += randi_range(1, 8)
		ctx.actor.remove_status(StatusEffectIds.INSPIRE_ATTACK)
		ctx.log_entries.append(ctx.actor.display_name + " strikes with Inspiration! +" + str(bonus) + " dmg.")

	if spec.has("bonus_range"):
		bonus += randi_range(spec.bonus_range[0], spec.bonus_range[1])
	return bonus


func _apply_heal(ctx: Dictionary, spec: Dictionary) -> void:
	var targets: Array = ctx.targets
	if targets.is_empty():
		return
	if spec.has("heal_by_target"):
		for target in targets:
			var heal_value = int(spec.heal_by_target.get(target.id, 0))
			if heal_value <= 0:
				continue
			target.heal(heal_value)
			ctx.summary.healed_total += heal_value
			ctx.summary.healed = heal_value
			_add_event(ctx, EVENT_HEAL, {
				"actor_id": ctx.actor.id,
				"target_id": target.id,
				"amount": heal_value
			})
		return
	if not spec.has("heal"):
		return
	var heal_value = int(spec.heal)
	var target: Character = targets[0]
	target.heal(heal_value)
	ctx.summary.healed = heal_value
	ctx.summary.healed_total = heal_value
	_add_event(ctx, EVENT_HEAL, {
		"actor_id": ctx.actor.id,
		"target_id": target.id,
		"amount": heal_value
	})


func _apply_statuses(ctx: Dictionary, spec: Dictionary) -> void:
	for status_entry in spec.get("status_effects", []):
		var target_id = status_entry.get("target_id", "")
		var target = _battle_manager.get_actor_by_id(target_id)
		if target == null:
			continue
		var chance = status_entry.get("chance", 1.0)
		if randf() > chance:
			continue
		var status = status_entry.get("status", null)
		if status != null:
			target.add_status(status)
			var status_id = status_entry.get("status_id", status.id)
			ctx.summary.statuses.append({"target_id": target_id, "status": status_id})
			_add_event(ctx, EVENT_STATUS, {
				"actor_id": ctx.actor.id,
				"target_id": target_id,
				"status": status_id
			})
		var on_apply = status_entry.get("on_apply", null)
		if on_apply is Callable:
			on_apply.call(ctx, target)


func _handle_reaction_window(ctx: Dictionary, spec: Dictionary) -> void:
	if not spec.get("allow_riposte", false):
		return
	if ctx.targets.is_empty():
		return
	var defender: Character = ctx.targets[0]
	var attacker: Character = ctx.actor
	if defender.id != "ludwig":
		return
	if not defender.has_status(StatusEffectIds.GUARD_STANCE):
		return
	if randf() > _battle_manager.RIPOSTE_PROC_CHANCE:
		return
	var riposte_dmg = DamageCalculator.calculate_physical_damage(defender, attacker, 0.6)
	_apply_damage_with_limit(defender, attacker, riposte_dmg)
	ctx.log_entries.append("Riposte! " + defender.display_name + " counters for " + str(riposte_dmg) + " damage.")
	_add_event(ctx, EVENT_REACTION, {
		"actor_id": defender.id,
		"target_id": attacker.id,
		"amount": riposte_dmg
	})


func _check_ko(ctx: Dictionary) -> void:
	for target in ctx.targets:
		if target != null and target.is_ko():
			_add_event(ctx, EVENT_KO, {"target_id": target.id})


func _update_ui_logs(ctx: Dictionary, spec: Dictionary) -> void:
	for entry in spec.get("log_entries", []):
		var text = _format_log(entry, ctx)
		if not text.is_empty():
			_battle_manager.add_message(text)
			_add_event(ctx, EVENT_LOG, {"text": text})
	for entry in ctx.log_entries:
		_battle_manager.add_message(entry)
		_add_event(ctx, EVENT_LOG, {"text": entry})


func _format_log(template: String, ctx: Dictionary) -> String:
	if template.is_empty():
		return ""
	var actor: Character = ctx.actor
	var target: Character = ctx.targets[0] if ctx.targets.size() > 0 else null
	var summary = ctx.summary
	var result = template
	result = result.replace("{attacker}", actor.display_name)
	result = result.replace("{target}", target.display_name if target != null else "")
	result = result.replace("{damage}", str(summary.damage_total))
	result = result.replace("{healed}", str(summary.healed_total))
	result = result.replace("{bonus}", str(summary.bonus_damage))
	return result


func _build_payload(ctx: Dictionary, spec: Dictionary) -> Dictionary:
	return {
		"action_id": ctx.action.get("action_id", ""),
		"actor_id": ctx.actor.id,
		"target_ids": _collect_target_ids(ctx.targets),
		"summary": ctx.summary,
		"events": ctx.events,
		"tags": spec.get("tags", [])
	}


func _run_hooks(hooks: Array, ctx: Dictionary) -> void:
	for hook in hooks:
		if hook is Callable:
			hook.call(ctx)


func _apply_damage_with_limit(attacker: Character, target: Character, amount: int) -> void:
	if target == null:
		return
	target.apply_damage(amount)
	_battle_manager._update_limit_gauges(attacker, target, amount)
	_battle_manager._check_boss_phase_transition(target)


func _collect_target_ids(targets: Array) -> Array:
	var ids: Array = []
	for target in targets:
		if target != null:
			ids.append(target.id)
	return ids


func _add_event(ctx: Dictionary, event_type: String, data: Dictionary) -> void:
	ctx.events.append({
		"type": event_type,
		"data": data
	})
