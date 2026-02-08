extends RefCounted
class_name DamageCalculator

static var damage_multiplier: float = 1.0

const GUARD_STANCE_DEF_MULTIPLIER := 1.5
const MAGE_ARMOR_DEF_MULTIPLIER := 1.5
const GUARD_STANCE_DAMAGE_REDUCTION := 0.5
const DEFENSE_FACTOR := 0.5
const VARIANCE_MIN := 0.90
const VARIANCE_MAX := 1.10
const BASE_CRIT_CHANCE := 0.05
const CRIT_MULTIPLIER := 2.0

static func calculate_physical_damage(attacker: Node, defender: Node, multiplier: float) -> int:
	var breakdown = calculate_physical_damage_breakdown(attacker, defender, multiplier)
	return int(breakdown.get("total", 0))


static func calculate_physical_damage_breakdown(attacker: Node, defender: Node, multiplier: float) -> Dictionary:
	if attacker == null or defender == null:
		return {"total": 0, "components": []}
	var atk = float(attacker.stats.get("atk", 0))
	var atk_up_stacks = _count_status(attacker, StatusEffectIds.ATK_UP)
	if atk_up_stacks > 0:
		atk *= 1.0 + (0.25 * min(atk_up_stacks, 2))
	if attacker.has_status(StatusEffectIds.ATK_DOWN):
		var down_multiplier = _get_status_multiplier(attacker, StatusEffectIds.ATK_DOWN, 0.25)
		atk *= down_multiplier
	var defense = float(defender.stats.get("def", 0))
	if defender.has_status(StatusEffectIds.GUARD_STANCE):
		defense *= GUARD_STANCE_DEF_MULTIPLIER
	if defender.has_status(StatusEffectIds.MAGE_ARMOR):
		defense *= MAGE_ARMOR_DEF_MULTIPLIER
	var base_raw = (atk * multiplier) - (defense * DEFENSE_FACTOR)
	var base_after_clamp = max(1.0, base_raw)
	var variance_roll = randf_range(VARIANCE_MIN, VARIANCE_MAX)
	var variance = base_after_clamp * variance_roll
	var components: Array = [{
		"type": "normal",
		"label": "BASE",
		"amount": max(1, int(floor(variance)))
	}]
	if attacker.has_status(StatusEffectIds.FIRE_IMBUE):
		var fire_bonus = randi_range(1, 4)
		variance += fire_bonus
		components.append({"type": "buff", "label": "FIRE", "amount": fire_bonus})
	if attacker.has_status(StatusEffectIds.BLESS):
		var bless_bonus = randi_range(1, 4)
		variance += bless_bonus
		components.append({"type": "buff", "label": "BLESS", "amount": bless_bonus})

	if defender.has_status(StatusEffectIds.GUARD_STANCE):
		variance *= GUARD_STANCE_DAMAGE_REDUCTION

	variance *= damage_multiplier
	var total = max(1, int(floor(variance)))
	var sum_components := 0
	for entry in components:
		sum_components += int(entry.get("amount", 0))
	if sum_components != total:
		components[0]["amount"] = int(components[0]["amount"]) + (total - sum_components)
	return {
		"total": total,
		"components": components
	}


static func _count_status(actor: Node, status_id: String) -> int:
	if not actor.has_method("has_status"):
		return 0
	var count = 0

	if actor.get("status_effects") != null:
		for status in actor.status_effects:
			if status is StatusEffect and status.id == status_id:
				count += 1
			elif status is Dictionary and status.get("id", "") == status_id:
				count += 1
	return count

static func _get_status_multiplier(actor: Node, status_id: String, default_reduction: float) -> float:
	if actor.get("status_effects") == null:
		return 1.0 - default_reduction
	var reduction = default_reduction
	for status in actor.status_effects:
		if status is StatusEffect and status.id == status_id:
			reduction = max(reduction, float(status.value) / 100.0)
		elif status is Dictionary and status.get("id", "") == status_id:
			reduction = max(reduction, float(status.get("value", int(default_reduction * 100))) / 100.0)
	return clamp(1.0 - reduction, 0.1, 1.0)
