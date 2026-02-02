extends RefCounted
class_name StatusEffectFactory

static func poison(turns: int = 3, damage: int = 10) -> StatusEffect:
	return StatusEffect.new(StatusEffectIds.POISON, turns, damage, [StatusTags.NEGATIVE, StatusTags.DOT, StatusTags.CLEANSABLE])


static func regen(turns: int = 4, heal: int = 15) -> StatusEffect:
	return StatusEffect.new(StatusEffectIds.REGEN, turns, heal, [StatusTags.POSITIVE, StatusTags.HOT])


static func stun(turns: int = 1) -> StatusEffect:
	return StatusEffect.new(StatusEffectIds.STUN, turns, 0, [StatusTags.NEGATIVE, StatusTags.CROWD_CONTROL, StatusTags.CLEANSABLE])


static func fire_imbue() -> StatusEffect:
	return StatusEffect.new(StatusEffectIds.FIRE_IMBUE, -1, 0, [StatusTags.POSITIVE, StatusTags.TOGGLE, StatusTags.ELEMENTAL])
