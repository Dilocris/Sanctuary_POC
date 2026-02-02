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
