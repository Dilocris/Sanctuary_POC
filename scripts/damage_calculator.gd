extends RefCounted
class_name DamageCalculator

const BASE_CRIT_CHANCE := 0.05

static func calculate_physical_damage(attacker: Node, defender: Node, multiplier: float) -> int:
	var atk = attacker.stats.get("atk", 0)
	var defense = defender.stats.get("def", 0)
	var base = (atk * multiplier) - (defense * 0.5)
	var variance = base * randf_range(0.90, 1.10)

	var crit = randf() <= BASE_CRIT_CHANCE
	if crit:
		variance *= 2.0

	if attacker.has_status(StatusEffectIds.FIRE_IMBUE):
		variance += randi_range(1, 4)

	return max(1, int(floor(variance)))
