extends RefCounted
class_name ActionFactory

const ACTION_DATA_ROOT := "res://data/actions/"
const ActionDataScript = preload("res://scripts/resources/action_data.gd")
const DataCloneUtil = preload("res://scripts/utils/data_clone.gd")

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
		# Limit Breaks
		ActionIds.KAI_LIMIT: return kairus_limit(actor_id, t1)
		ActionIds.LUD_LIMIT: return ludwig_limit(actor_id)
		ActionIds.NINOS_LIMIT: return ninos_limit(actor_id)
		ActionIds.CAT_LIMIT: return catraca_limit(actor_id)
		ActionIds.BOS_GREATAXE_SLAM: return marcus_greataxe_slam(actor_id, t1)
		ActionIds.BOS_TENDRIL_LASH: return marcus_tendril_lash(actor_id, t1)
		ActionIds.BOS_BATTLE_ROAR: return marcus_battle_roar(actor_id)
		ActionIds.BOS_COLLECTORS_GRASP: return marcus_collectors_grasp(actor_id, t1)
		ActionIds.BOS_DARK_REGEN: return marcus_dark_regen(actor_id)
		ActionIds.BOS_SYMBIOTIC_RAGE: return marcus_symbiotic_rage(actor_id, targets)
		ActionIds.BOS_VENOM_STRIKE: return marcus_venom_strike(actor_id, targets)
		_:
			return basic_attack(actor_id, t1)


static func _load_action_data(action_id: String) -> ActionData:
	var path = ACTION_DATA_ROOT + action_id + ".tres"
	var data = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if data == null:
		return null
	if data.get_script() == ActionDataScript:
		return data
	var raw = DataCloneUtil.resource_to_dict(data)
	if _dict_get(raw, "action_id", "") != "":
		return data
	return null


static func _build_action(action_id: String, actor_id: String, targets: Array, override_multiplier: float = 0.0) -> Dictionary:
	var data = _load_action_data(action_id)
	if data == null:
		return _build_legacy_action(action_id, actor_id, targets, override_multiplier)
	var raw = DataCloneUtil.resource_to_dict(data)
	var action = {
		"action_id": _dict_get(raw, "action_id", action_id),
		"actor_id": actor_id,
		"targets": targets,
		"tags": DataCloneUtil.array(_dict_get(raw, "tags", []))
	}
	var mp_cost = _dict_get(raw, "mp_cost", 0)
	if mp_cost > 0:
		action["mp_cost"] = mp_cost
	var resource_type = _dict_get(raw, "resource_type", "")
	if resource_type != "":
		action["resource_type"] = resource_type
		action["resource_cost"] = _dict_get(raw, "resource_cost", 0)
	var multiplier = _dict_get(raw, "multiplier", 1.0)
	if override_multiplier > 0.0:
		multiplier = override_multiplier
	if multiplier != 1.0:
		action["multiplier"] = multiplier
	return action


static func _build_legacy_action(action_id: String, actor_id: String, targets: Array, override_multiplier: float = 0.0) -> Dictionary:
	var template = _legacy_template(action_id)
	if template.is_empty():
		return {
			"action_id": action_id,
			"actor_id": actor_id,
			"targets": targets,
			"tags": []
		}
	var action = template.duplicate(true)
	action["actor_id"] = actor_id
	action["targets"] = targets
	if override_multiplier > 0.0:
		action["multiplier"] = override_multiplier
	return action


static func _legacy_template(action_id: String) -> Dictionary:
	match action_id:
		ActionIds.BASIC_ATTACK:
			return {"action_id": ActionIds.BASIC_ATTACK, "multiplier": 1.0, "tags": [ActionTags.PHYSICAL, ActionTags.SINGLE]}
		ActionIds.SKIP_TURN:
			return {"action_id": ActionIds.SKIP_TURN, "tags": [ActionTags.SELF]}
		ActionIds.KAI_FLURRY:
			return {"action_id": ActionIds.KAI_FLURRY, "multiplier": 1.0, "resource_type": "ki", "resource_cost": 2, "tags": [ActionTags.PHYSICAL, ActionTags.RESOURCE, ActionTags.SINGLE]}
		ActionIds.KAI_STUN_STRIKE:
			return {"action_id": ActionIds.KAI_STUN_STRIKE, "multiplier": 1.0, "resource_type": "ki", "resource_cost": 1, "tags": [ActionTags.PHYSICAL, ActionTags.RESOURCE, ActionTags.SINGLE, ActionTags.STATUS]}
		ActionIds.KAI_FIRE_IMBUE:
			return {"action_id": ActionIds.KAI_FIRE_IMBUE, "resource_type": "ki", "resource_cost": 0, "tags": [ActionTags.TOGGLE, ActionTags.ELEMENTAL, ActionTags.SELF]}
		ActionIds.LUD_GUARD_STANCE:
			return {"action_id": ActionIds.LUD_GUARD_STANCE, "tags": [ActionTags.TOGGLE, ActionTags.SELF]}
		ActionIds.LUD_LUNGING:
			return {"action_id": ActionIds.LUD_LUNGING, "multiplier": 1.2, "resource_type": "superiority_dice", "resource_cost": 1, "tags": [ActionTags.PHYSICAL, ActionTags.RESOURCE, ActionTags.SINGLE]}
		ActionIds.LUD_PRECISION:
			return {"action_id": ActionIds.LUD_PRECISION, "multiplier": 1.2, "resource_type": "superiority_dice", "resource_cost": 1, "tags": [ActionTags.PHYSICAL, ActionTags.RESOURCE, ActionTags.SINGLE]}
		ActionIds.LUD_SHIELD_BASH:
			return {"action_id": ActionIds.LUD_SHIELD_BASH, "multiplier": 1.0, "resource_type": "superiority_dice", "resource_cost": 1, "tags": [ActionTags.PHYSICAL, ActionTags.RESOURCE, ActionTags.SINGLE, ActionTags.STATUS]}
		ActionIds.LUD_RALLY:
			return {"action_id": ActionIds.LUD_RALLY, "resource_type": "superiority_dice", "resource_cost": 1, "tags": [ActionTags.HEALING, ActionTags.RESOURCE, ActionTags.SINGLE]}
		ActionIds.NINOS_INSPIRE_ATTACK:
			return {"action_id": ActionIds.NINOS_INSPIRE_ATTACK, "resource_type": "bardic_inspiration", "resource_cost": 1, "tags": [ActionTags.BUFF, ActionTags.RESOURCE, ActionTags.SINGLE]}
		ActionIds.NINOS_VICIOUS_MOCKERY:
			return {"action_id": ActionIds.NINOS_VICIOUS_MOCKERY, "mp_cost": 5, "tags": [ActionTags.MAGICAL, ActionTags.SINGLE, ActionTags.DEBUFF]}
		ActionIds.NINOS_HEALING_WORD:
			return {"action_id": ActionIds.NINOS_HEALING_WORD, "mp_cost": 6, "tags": [ActionTags.MAGICAL, ActionTags.HEALING, ActionTags.SINGLE]}
		ActionIds.NINOS_BLESS:
			return {"action_id": ActionIds.NINOS_BLESS, "mp_cost": 10, "tags": [ActionTags.MAGICAL, ActionTags.BUFF, ActionTags.ALL_ALLIES]}
		ActionIds.CAT_FIRE_BOLT:
			return {"action_id": ActionIds.CAT_FIRE_BOLT, "mp_cost": 0, "tags": [ActionTags.MAGICAL, ActionTags.SINGLE, ActionTags.ELEMENTAL]}
		ActionIds.CAT_FIREBALL:
			return {"action_id": ActionIds.CAT_FIREBALL, "mp_cost": 18, "tags": [ActionTags.MAGICAL, ActionTags.ALL_ENEMIES, ActionTags.ELEMENTAL]}
		ActionIds.CAT_MAGE_ARMOR:
			return {"action_id": ActionIds.CAT_MAGE_ARMOR, "mp_cost": 4, "tags": [ActionTags.MAGICAL, ActionTags.BUFF, ActionTags.SELF]}
		ActionIds.CAT_METAMAGIC_QUICKEN:
			return {"action_id": ActionIds.CAT_METAMAGIC_QUICKEN, "resource_type": "sorcery_points", "resource_cost": 2, "tags": [ActionTags.METAMAGIC, ActionTags.RESOURCE, ActionTags.SELF]}
		ActionIds.CAT_METAMAGIC_TWIN:
			return {"action_id": ActionIds.CAT_METAMAGIC_TWIN, "resource_type": "sorcery_points", "resource_cost": 1, "tags": [ActionTags.METAMAGIC, ActionTags.RESOURCE, ActionTags.SELF]}
		ActionIds.KAI_LIMIT:
			return {"action_id": ActionIds.KAI_LIMIT, "tags": [ActionTags.PHYSICAL, ActionTags.MAGICAL, ActionTags.SINGLE]}
		ActionIds.LUD_LIMIT:
			return {"action_id": ActionIds.LUD_LIMIT, "tags": [ActionTags.MAGICAL, ActionTags.ALL_ENEMIES, ActionTags.BUFF, ActionTags.DEBUFF]}
		ActionIds.NINOS_LIMIT:
			return {"action_id": ActionIds.NINOS_LIMIT, "tags": [ActionTags.MAGICAL, ActionTags.ALL_ALLIES, ActionTags.HEALING, ActionTags.BUFF]}
		ActionIds.CAT_LIMIT:
			return {"action_id": ActionIds.CAT_LIMIT, "tags": [ActionTags.MAGICAL, ActionTags.SELF, ActionTags.BUFF]}
		ActionIds.BOS_GREATAXE_SLAM:
			return {"action_id": ActionIds.BOS_GREATAXE_SLAM, "multiplier": 1.2, "tags": [ActionTags.PHYSICAL, ActionTags.SINGLE]}
		ActionIds.BOS_TENDRIL_LASH:
			return {"action_id": ActionIds.BOS_TENDRIL_LASH, "multiplier": 0.8, "tags": [ActionTags.PHYSICAL, ActionTags.STATUS, ActionTags.SINGLE]}
		ActionIds.BOS_BATTLE_ROAR:
			return {"action_id": ActionIds.BOS_BATTLE_ROAR, "tags": [ActionTags.SELF, ActionTags.BUFF]}
		ActionIds.BOS_COLLECTORS_GRASP:
			return {"action_id": ActionIds.BOS_COLLECTORS_GRASP, "tags": [ActionTags.SINGLE]}
		ActionIds.BOS_DARK_REGEN:
			return {"action_id": ActionIds.BOS_DARK_REGEN, "tags": [ActionTags.SELF, ActionTags.HEALING]}
		ActionIds.BOS_SYMBIOTIC_RAGE:
			return {"action_id": ActionIds.BOS_SYMBIOTIC_RAGE, "tags": [ActionTags.SINGLE, ActionTags.PHYSICAL]}
		ActionIds.BOS_VENOM_STRIKE:
			return {"action_id": ActionIds.BOS_VENOM_STRIKE, "tags": [ActionTags.ALL_ENEMIES, ActionTags.STATUS]}
		_:
			return {}


static func _dict_get(dict: Dictionary, key: Variant, fallback: Variant) -> Variant:
	if dict.has(key):
		return dict[key]
	return fallback

static func basic_attack(actor_id: String, target_id: String, multiplier: float = 1.0) -> Dictionary:
	return _build_action(ActionIds.BASIC_ATTACK, actor_id, [target_id], multiplier)


static func skip_turn(actor_id: String) -> Dictionary:
	return _build_action(ActionIds.SKIP_TURN, actor_id, [])


static func kairus_flurry(actor_id: String, target_id: String) -> Dictionary:
	return _build_action(ActionIds.KAI_FLURRY, actor_id, [target_id])


static func kairus_stunning_strike(actor_id: String, target_id: String) -> Dictionary:
	return _build_action(ActionIds.KAI_STUN_STRIKE, actor_id, [target_id])


static func kairus_fire_imbue(actor_id: String) -> Dictionary:
	return _build_action(ActionIds.KAI_FIRE_IMBUE, actor_id, [actor_id])


static func ludwig_guard_stance(actor_id: String) -> Dictionary:
	return _build_action(ActionIds.LUD_GUARD_STANCE, actor_id, [actor_id])


static func ludwig_lunging_attack(actor_id: String, target_id: String) -> Dictionary:
	return _build_action(ActionIds.LUD_LUNGING, actor_id, [target_id])


static func ludwig_precision_strike(actor_id: String, target_id: String) -> Dictionary:
	return _build_action(ActionIds.LUD_PRECISION, actor_id, [target_id])


static func ludwig_shield_bash(actor_id: String, target_id: String) -> Dictionary:
	return _build_action(ActionIds.LUD_SHIELD_BASH, actor_id, [target_id])


static func ludwig_rally(actor_id: String, target_id: String) -> Dictionary:
	return _build_action(ActionIds.LUD_RALLY, actor_id, [target_id])


static func ninos_inspire_attack(actor_id: String, target_id: String) -> Dictionary:
	return _build_action(ActionIds.NINOS_INSPIRE_ATTACK, actor_id, [target_id])


static func ninos_vicious_mockery(actor_id: String, target_id: String) -> Dictionary:
	return _build_action(ActionIds.NINOS_VICIOUS_MOCKERY, actor_id, [target_id])


static func ninos_healing_word(actor_id: String, target_id: String) -> Dictionary:
	return _build_action(ActionIds.NINOS_HEALING_WORD, actor_id, [target_id])


static func ninos_bless(actor_id: String, target_ids: Array) -> Dictionary:
	return _build_action(ActionIds.NINOS_BLESS, actor_id, target_ids)


static func catraca_fire_bolt(actor_id: String, target_id: String) -> Dictionary:
	return _build_action(ActionIds.CAT_FIRE_BOLT, actor_id, [target_id])


static func catraca_fireball(actor_id: String, target_ids: Array) -> Dictionary:
	return _build_action(ActionIds.CAT_FIREBALL, actor_id, target_ids)


static func catraca_mage_armor(actor_id: String) -> Dictionary:
	return _build_action(ActionIds.CAT_MAGE_ARMOR, actor_id, [actor_id])


static func catraca_metamagic_quicken(actor_id: String) -> Dictionary:
	return _build_action(ActionIds.CAT_METAMAGIC_QUICKEN, actor_id, [actor_id])


static func catraca_metamagic_twin(actor_id: String) -> Dictionary:
	return _build_action(ActionIds.CAT_METAMAGIC_TWIN, actor_id, [actor_id])


static func kairus_limit(actor_id: String, target_id: String) -> Dictionary:
	return _build_action(ActionIds.KAI_LIMIT, actor_id, [target_id])


static func ludwig_limit(actor_id: String) -> Dictionary:
	return _build_action(ActionIds.LUD_LIMIT, actor_id, [])


static func ninos_limit(actor_id: String) -> Dictionary:
	return _build_action(ActionIds.NINOS_LIMIT, actor_id, [])


static func catraca_limit(actor_id: String) -> Dictionary:
	return _build_action(ActionIds.CAT_LIMIT, actor_id, [actor_id])


static func marcus_greataxe_slam(actor_id: String, target_id: String) -> Dictionary:
	return _build_action(ActionIds.BOS_GREATAXE_SLAM, actor_id, [target_id])


static func marcus_tendril_lash(actor_id: String, target_id: String) -> Dictionary:
	return _build_action(ActionIds.BOS_TENDRIL_LASH, actor_id, [target_id])


static func marcus_battle_roar(actor_id: String) -> Dictionary:
	return _build_action(ActionIds.BOS_BATTLE_ROAR, actor_id, [actor_id])


static func marcus_collectors_grasp(actor_id: String, target_id: String) -> Dictionary:
	return _build_action(ActionIds.BOS_COLLECTORS_GRASP, actor_id, [target_id])

static func marcus_dark_regen(actor_id: String) -> Dictionary:
	return _build_action(ActionIds.BOS_DARK_REGEN, actor_id, [actor_id])

static func marcus_symbiotic_rage(actor_id: String, target_ids: Array) -> Dictionary:
	return _build_action(ActionIds.BOS_SYMBIOTIC_RAGE, actor_id, target_ids)

static func marcus_venom_strike(actor_id: String, target_ids: Array) -> Dictionary:
	return _build_action(ActionIds.BOS_VENOM_STRIKE, actor_id, target_ids)
