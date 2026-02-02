extends RefCounted
class_name ActionFactory

static func basic_attack(actor_id: String, target_id: String, multiplier: float = 1.0) -> Dictionary:
	return {
		"action_id": ActionIds.BASIC_ATTACK,
		"actor_id": actor_id,
		"targets": [target_id],
		"multiplier": multiplier,
		"tags": [ActionTags.PHYSICAL, ActionTags.SINGLE]
	}


static func skip_turn(actor_id: String) -> Dictionary:
	return {
		"action_id": ActionIds.SKIP_TURN,
		"actor_id": actor_id,
		"targets": []
	}


static func kairus_flurry(actor_id: String, target_id: String) -> Dictionary:
	return {
		"action_id": ActionIds.KAI_FLURRY,
		"actor_id": actor_id,
		"targets": [target_id],
		"multiplier": 1.0,
		"resource_type": "ki",
		"resource_cost": 2,
		"tags": [ActionTags.PHYSICAL, ActionTags.RESOURCE, ActionTags.SINGLE]
	}


static func kairus_stunning_strike(actor_id: String, target_id: String) -> Dictionary:
	return {
		"action_id": ActionIds.KAI_STUN_STRIKE,
		"actor_id": actor_id,
		"targets": [target_id],
		"multiplier": 1.0,
		"resource_type": "ki",
		"resource_cost": 1,
		"tags": [ActionTags.PHYSICAL, ActionTags.RESOURCE, ActionTags.SINGLE, ActionTags.STATUS]
	}


static func kairus_fire_imbue(actor_id: String) -> Dictionary:
	return {
		"action_id": ActionIds.KAI_FIRE_IMBUE,
		"actor_id": actor_id,
		"targets": [actor_id],
		"resource_type": "ki",
		"resource_cost": 0,
		"tags": [ActionTags.TOGGLE, ActionTags.ELEMENTAL, ActionTags.SELF]
	}


static func ludwig_guard_stance(actor_id: String) -> Dictionary:
	return {
		"action_id": ActionIds.LUD_GUARD_STANCE,
		"actor_id": actor_id,
		"targets": [actor_id],
		"tags": [ActionTags.TOGGLE, ActionTags.SELF]
	}


static func ludwig_lunging_attack(actor_id: String, target_id: String) -> Dictionary:
	return {
		"action_id": ActionIds.LUD_LUNGING,
		"actor_id": actor_id,
		"targets": [target_id],
		"multiplier": 1.2,
		"resource_type": "superiority_dice",
		"resource_cost": 1,
		"tags": [ActionTags.PHYSICAL, ActionTags.RESOURCE, ActionTags.SINGLE]
	}


static func ludwig_precision_strike(actor_id: String, target_id: String) -> Dictionary:
	return {
		"action_id": ActionIds.LUD_PRECISION,
		"actor_id": actor_id,
		"targets": [target_id],
		"multiplier": 1.2,
		"resource_type": "superiority_dice",
		"resource_cost": 1,
		"tags": [ActionTags.PHYSICAL, ActionTags.RESOURCE, ActionTags.SINGLE]
	}


static func ludwig_shield_bash(actor_id: String, target_id: String) -> Dictionary:
	return {
		"action_id": ActionIds.LUD_SHIELD_BASH,
		"actor_id": actor_id,
		"targets": [target_id],
		"multiplier": 1.0,
		"resource_type": "superiority_dice",
		"resource_cost": 1,
		"tags": [ActionTags.PHYSICAL, ActionTags.RESOURCE, ActionTags.SINGLE, ActionTags.STATUS]
	}


static func ludwig_rally(actor_id: String, target_id: String) -> Dictionary:
	return {
		"action_id": ActionIds.LUD_RALLY,
		"actor_id": actor_id,
		"targets": [target_id],
		"resource_type": "superiority_dice",
		"resource_cost": 1,
		"tags": [ActionTags.HEALING, ActionTags.RESOURCE, ActionTags.SINGLE]
	}


static func ninos_inspire_attack(actor_id: String, target_id: String) -> Dictionary:
	return {
		"action_id": ActionIds.NINOS_INSPIRE_ATTACK,
		"actor_id": actor_id,
		"targets": [target_id],
		"resource_type": "bardic_inspiration",
		"resource_cost": 1,
		"tags": [ActionTags.BUFF, ActionTags.RESOURCE, ActionTags.SINGLE]
	}


static func ninos_inspire_defense(actor_id: String, target_id: String) -> Dictionary:
	return {
		"action_id": ActionIds.NINOS_INSPIRE_DEFENSE,
		"actor_id": actor_id,
		"targets": [target_id],
		"resource_type": "bardic_inspiration",
		"resource_cost": 1,
		"tags": [ActionTags.BUFF, ActionTags.RESOURCE, ActionTags.SINGLE]
	}


static func ninos_vicious_mockery(actor_id: String, target_id: String) -> Dictionary:
	return {
		"action_id": ActionIds.NINOS_VICIOUS_MOCKERY,
		"actor_id": actor_id,
		"targets": [target_id],
		"mp_cost": 5,
		"tags": [ActionTags.MAGICAL, ActionTags.SINGLE, ActionTags.DEBUFF]
	}


static func ninos_healing_word(actor_id: String, target_id: String) -> Dictionary:
	return {
		"action_id": ActionIds.NINOS_HEALING_WORD,
		"actor_id": actor_id,
		"targets": [target_id],
		"mp_cost": 6,
		"tags": [ActionTags.MAGICAL, ActionTags.HEALING, ActionTags.SINGLE]
	}


static func ninos_bless(actor_id: String, target_ids: Array) -> Dictionary:
	return {
		"action_id": ActionIds.NINOS_BLESS,
		"actor_id": actor_id,
		"targets": target_ids,
		"mp_cost": 10,
		"tags": [ActionTags.MAGICAL, ActionTags.BUFF, ActionTags.ALL_ALLIES]
	}


static func catraca_fire_bolt(actor_id: String, target_id: String) -> Dictionary:
	return {
		"action_id": ActionIds.CAT_FIRE_BOLT,
		"actor_id": actor_id,
		"targets": [target_id],
		"mp_cost": 0,
		"tags": [ActionTags.MAGICAL, ActionTags.SINGLE, ActionTags.ELEMENTAL]
	}


static func catraca_fireball(actor_id: String, target_ids: Array) -> Dictionary:
	return {
		"action_id": ActionIds.CAT_FIREBALL,
		"actor_id": actor_id,
		"targets": target_ids,
		"mp_cost": 18,
		"tags": [ActionTags.MAGICAL, ActionTags.ALL_ENEMIES, ActionTags.ELEMENTAL]
		# Metamagic hooks would modify this dictionary before execution
	}


static func catraca_mage_armor(actor_id: String) -> Dictionary:
	return {
		"action_id": ActionIds.CAT_MAGE_ARMOR,
		"actor_id": actor_id,
		"targets": [actor_id], # Self only
		"mp_cost": 4,
		"tags": [ActionTags.MAGICAL, ActionTags.BUFF, ActionTags.SELF]
	}
