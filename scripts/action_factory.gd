extends RefCounted
class_name ActionFactory

static func create_action(action_id: String, actor_id: String, targets: Array) -> Dictionary:
	var t1 = targets[0] if targets.size() > 0 else ""
	match action_id:
		ActionIds.BASIC_ATTACK: return basic_attack(actor_id, t1)
		ActionIds.SKIP_TURN: return skip_turn(actor_id)
		# Kairus
		ActionIds.KAI_FLURRY: return kairus_flurry(actor_id, t1)
		ActionIds.KAI_STUN_STRIKE: return kairus_stunning_strike(actor_id, t1)
		ActionIds.KAI_FIRE_IMBUE: return kairus_fire_imbue(actor_id)
		# Ludwig
		ActionIds.LUD_GUARD_STANCE: return ludwig_guard_stance(actor_id)
		ActionIds.LUD_LUNGING: return ludwig_lunging_attack(actor_id, t1)
		ActionIds.LUD_PRECISION: return ludwig_precision_strike(actor_id, t1)
		ActionIds.LUD_SHIELD_BASH: return ludwig_shield_bash(actor_id, t1)
		ActionIds.LUD_RALLY: return ludwig_rally(actor_id, t1)
		# Ninos
		ActionIds.NINOS_BLESS: return ninos_bless(actor_id, targets)
		ActionIds.NINOS_HEALING_WORD: return ninos_healing_word(actor_id, t1)
		ActionIds.NINOS_VICIOUS_MOCKERY: return ninos_vicious_mockery(actor_id, t1)
		ActionIds.NINOS_INSPIRE_ATTACK: return ninos_inspire_attack(actor_id, t1)
		# Catraca
		ActionIds.CAT_MAGE_ARMOR: return catraca_mage_armor(actor_id)
		ActionIds.CAT_FIREBALL: return catraca_fireball(actor_id, targets)
		ActionIds.CAT_FIRE_BOLT: return catraca_fire_bolt(actor_id, t1)
		ActionIds.CAT_METAMAGIC_QUICKEN: return catraca_metamagic_quicken(actor_id)
		ActionIds.CAT_METAMAGIC_TWIN: return catraca_metamagic_twin(actor_id)
		ActionIds.BOS_GREAXE_SLAM: return marcus_greataxe_slam(actor_id, t1)
		ActionIds.BOS_TENDRIL_LASH: return marcus_tendril_lash(actor_id, t1)
		ActionIds.BOS_BATTLE_ROAR: return marcus_battle_roar(actor_id)
		ActionIds.BOS_COLLECTORS_GRASP: return marcus_collectors_grasp(actor_id, t1)
		_:
			return basic_attack(actor_id, t1)

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
		"targets": [],
		"tags": [ActionTags.SELF]
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


static func catraca_metamagic_quicken(actor_id: String) -> Dictionary:
	return {
		"action_id": ActionIds.CAT_METAMAGIC_QUICKEN,
		"actor_id": actor_id,
		"targets": [actor_id],
		"resource_type": "sorcery_points",
		"resource_cost": 2,
		"tags": [ActionTags.METAMAGIC, ActionTags.RESOURCE, ActionTags.SELF]
	}


static func catraca_metamagic_twin(actor_id: String) -> Dictionary:
	return {
		"action_id": ActionIds.CAT_METAMAGIC_TWIN,
		"actor_id": actor_id,
		"targets": [actor_id],
		"resource_type": "sorcery_points",
		"resource_cost": 1,
		"tags": [ActionTags.METAMAGIC, ActionTags.RESOURCE, ActionTags.SELF]
	}


static func marcus_greataxe_slam(actor_id: String, target_id: String) -> Dictionary:
	return {
		"action_id": ActionIds.BOS_GREAXE_SLAM,
		"actor_id": actor_id,
		"targets": [target_id],
		"multiplier": 1.2,
		"tags": [ActionTags.PHYSICAL, ActionTags.SINGLE]
	}


static func marcus_tendril_lash(actor_id: String, target_id: String) -> Dictionary:
	return {
		"action_id": ActionIds.BOS_TENDRIL_LASH,
		"actor_id": actor_id,
		"targets": [target_id],
		"multiplier": 0.8,
		"tags": [ActionTags.PHYSICAL, ActionTags.STATUS, ActionTags.SINGLE]
	}


static func marcus_battle_roar(actor_id: String) -> Dictionary:
	return {
		"action_id": ActionIds.BOS_BATTLE_ROAR,
		"actor_id": actor_id,
		"targets": [actor_id],
		"tags": [ActionTags.SELF, ActionTags.BUFF]
	}


static func marcus_collectors_grasp(actor_id: String, target_id: String) -> Dictionary:
	return {
		"action_id": ActionIds.BOS_COLLECTORS_GRASP,
		"actor_id": actor_id,
		"targets": [target_id],
		"tags": [ActionTags.SINGLE]
	}
