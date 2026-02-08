extends RefCounted
class_name StatusEffectFactory

static func poison(turns: int = 3, damage: int = 16) -> StatusEffect:
	return StatusEffect.new(StatusEffectIds.POISON, turns, damage, [StatusTags.NEGATIVE, StatusTags.DOT, StatusTags.CLEANSABLE])


static func burn(turns: int = 2, damage: int = 12) -> StatusEffect:
	return StatusEffect.new(StatusEffectIds.BURN, turns, damage, [StatusTags.NEGATIVE, StatusTags.DOT, StatusTags.ELEMENTAL, StatusTags.CLEANSABLE])


static func regen(turns: int = 4, heal: int = 15) -> StatusEffect:
	return StatusEffect.new(StatusEffectIds.REGEN, turns, heal, [StatusTags.POSITIVE, StatusTags.HOT])


static func stun(turns: int = 1) -> StatusEffect:
	return StatusEffect.new(StatusEffectIds.STUN, turns, 0, [StatusTags.NEGATIVE, StatusTags.CROWD_CONTROL, StatusTags.CLEANSABLE])


static func charm(turns: int = 1) -> StatusEffect:
	return StatusEffect.new(StatusEffectIds.CHARM, turns, 0, [StatusTags.NEGATIVE, StatusTags.CROWD_CONTROL, StatusTags.CLEANSABLE])


static func fire_imbue() -> StatusEffect:
	return StatusEffect.new(StatusEffectIds.FIRE_IMBUE, -1, 0, [StatusTags.POSITIVE, StatusTags.TOGGLE, StatusTags.ELEMENTAL])


static func guard_stance() -> StatusEffect:
	return StatusEffect.new(StatusEffectIds.GUARD_STANCE, -1, 0, [StatusTags.POSITIVE, StatusTags.TOGGLE])


static func atk_down(turns: int = 3, percent: float = 0.25) -> StatusEffect:
	# Note: Value here could be used as percentage or flat, logic in BattleManager decides. 
	# For now, let's store scaled int if needed, or handle in logic. 
	# Storing 25 as "value" for 25% reduction.
	return StatusEffect.new(StatusEffectIds.ATK_DOWN, turns, int(percent * 100), [StatusTags.NEGATIVE, StatusTags.STAT_DEBUFF])


static func atk_up(turns: int = 4, percent: float = 0.25) -> StatusEffect:
	return StatusEffect.new(StatusEffectIds.ATK_UP, turns, int(percent * 100), [StatusTags.POSITIVE, StatusTags.STAT_BUFF])


static func bless_buff(turns: int = 2, bonus: int = 2) -> StatusEffect:
	# Bonus 1d4 (avg 2-3). Let's use value=2 for flat view, or handle in damage calc
	return StatusEffect.new(StatusEffectIds.BLESS, turns, bonus, [StatusTags.POSITIVE, StatusTags.STAT_BUFF])


static func mage_armor() -> StatusEffect:
	# Lasts a few turns; not a toggle.
	# Effect: DEF * 1.5. Value could store the multiplier scaled (150).
	return StatusEffect.new(StatusEffectIds.MAGE_ARMOR, 3, 150, [StatusTags.POSITIVE, StatusTags.STAT_BUFF])


static func genies_wrath(charges: int = 3) -> StatusEffect:
	return StatusEffect.new(StatusEffectIds.GENIES_WRATH, charges, charges, [StatusTags.POSITIVE, StatusTags.STAT_BUFF])


static func inspire_attack(turns: int = 1) -> StatusEffect:
	# Next attack deals +1d8 damage, consume on use.
	return StatusEffect.new(StatusEffectIds.INSPIRE_ATTACK, turns, 0, [StatusTags.POSITIVE, StatusTags.STAT_BUFF])


static func patient_defense() -> StatusEffect:
	return StatusEffect.new(StatusEffectIds.PATIENT_DEFENSE, -1, 15, [StatusTags.POSITIVE, StatusTags.STAT_BUFF])


static func taunt(turns: int = 2) -> StatusEffect:
	return StatusEffect.new(StatusEffectIds.TAUNT, turns, 0, [StatusTags.POSITIVE, StatusTags.STAT_BUFF])
