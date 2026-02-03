extends RefCounted
class_name DamageCalculator

const BASE_CRIT_CHANCE := 0.05

static func calculate_physical_damage(attacker: Node, defender: Node, multiplier: float) -> int:
	var atk = attacker.stats.get("atk", 0)
	var atk_up_stacks = _count_status(attacker, StatusEffectIds.ATK_UP)
	if atk_up_stacks > 0:
		atk *= 1.0 + (0.25 * min(atk_up_stacks, 2))
	if attacker.has_status(StatusEffectIds.ATK_DOWN):
		var down_multiplier = _get_status_multiplier(attacker, StatusEffectIds.ATK_DOWN, 0.25)
		atk *= down_multiplier
	var defense = defender.stats.get("def", 0)
	if defender.has_status(StatusEffectIds.GUARD_STANCE):
		defense *= 1.5
	if defender.has_status(StatusEffectIds.MAGE_ARMOR):
		defense *= 1.5
	var base = (atk * multiplier) - (defense * 0.5)
	var variance = base * randf_range(0.90, 1.10)

	var crit = randf() <= BASE_CRIT_CHANCE
	if crit:
		variance *= 2.0

	if attacker.has_status(StatusEffectIds.FIRE_IMBUE):
		variance += randi_range(1, 4)

	if defender.has_status(StatusEffectIds.GUARD_STANCE):
		variance *= 0.5

	return max(1, int(floor(variance)))


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
