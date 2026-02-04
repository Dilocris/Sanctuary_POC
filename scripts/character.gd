extends Node2D
class_name Character

const DataCloneUtil = preload("res://scripts/utils/data_clone.gd")

signal hp_changed(current: int, max: int)
signal mp_changed(current: int, max: int)
signal resource_changed(resource_type: String, current: int, max: int)
signal status_added(status_id: String)
signal status_removed(status_id: String)
signal ko_state_changed(is_ko: bool)
signal damage_taken(amount: int)

var id: String = ""
var display_name: String = ""

var stats := {
	"hp_max": 1,
	"mp_max": 0,
	"atk": 0,
	"def": 0,
	"mag": 0,
	"spd": 0
}

var hp_current: int = 1
var mp_current: int = 0
var resources: Dictionary = {} # Example: {"ki": {"current": 0, "max": 0}}
var status_effects: Array = []
var limit_gauge: int = 0
const LIMIT_GAUGE_MAX := 100


func setup(data: Dictionary) -> void:
	id = data.get("id", id)
	display_name = data.get("display_name", display_name)
	stats = _merge_stats(DataCloneUtil.dict(data.get("stats", {})))

	hp_current = data.get("hp_current", stats["hp_max"])
	mp_current = data.get("mp_current", stats["mp_max"])
	resources = DataCloneUtil.dict(data.get("resources", resources))
	status_effects = DataCloneUtil.array(data.get("status_effects", status_effects))
	limit_gauge = data.get("limit_gauge", limit_gauge)

	_emit_all_resources()
	_emit_core_stats()


func is_ko() -> bool:
	return hp_current <= 0


func apply_damage(amount: int) -> void:
	if amount <= 0:
		return
	var was_ko = is_ko()
	hp_current = max(0, hp_current - amount)
	emit_signal("hp_changed", hp_current, stats["hp_max"])
	emit_signal("damage_taken", amount)
	if was_ko != is_ko():
		emit_signal("ko_state_changed", is_ko())


func heal(amount: int) -> void:
	if amount <= 0:
		return
	var was_ko = is_ko()
	hp_current = min(stats["hp_max"], hp_current + amount)
	emit_signal("hp_changed", hp_current, stats["hp_max"])
	if was_ko != is_ko():
		emit_signal("ko_state_changed", is_ko())


func add_status(status: Variant) -> void:
	var status_id = _get_status_id(status)
	if status_id.is_empty():
		return
	status_effects.append(status)
	emit_signal("status_added", status_id)


func remove_status(status_id: String) -> void:
	if status_id.is_empty():
		return
	for i in range(status_effects.size() - 1, -1, -1):
		if _get_status_id(status_effects[i]) == status_id:
			status_effects.remove_at(i)
	emit_signal("status_removed", status_id)


func has_status(status_id: String) -> bool:
	for status in status_effects:
		if _get_status_id(status) == status_id:
			return true
	return false


func can_use_action(action: Dictionary) -> bool:
	if action.get("resource_type", "") != "":
		return _has_resource(action.resource_type, action.get("resource_cost", 0))
	var mp_cost = action.get("mp_cost", 0)
	if mp_cost > 0 and mp_current < mp_cost:
		return false
	return true


func consume_resources(action: Dictionary) -> void:
	if action.get("resource_type", "") != "":
		consume_resource(action.resource_type, action.get("resource_cost", 0))
	var mp_cost = action.get("mp_cost", 0)
	if mp_cost > 0:
		mp_current = max(0, mp_current - mp_cost)
		emit_signal("mp_changed", mp_current, stats["mp_max"])


func execute_action(action: Dictionary, targets: Array) -> Dictionary:
	if not can_use_action(action):
		return {"ok": false, "error": "insufficient_resources"}
	consume_resources(action)
	return {"ok": true, "action": action, "targets": targets}


func _has_resource(resource_type: String, cost: int) -> bool:
	if not resources.has(resource_type):
		return false
	return resources[resource_type].get("current", 0) >= cost


func _consume_resource(resource_type: String, cost: int) -> void:
	if not resources.has(resource_type) or cost <= 0:
		return
	var current = resources[resource_type].get("current", 0)
	var max_val = resources[resource_type].get("max", 0)
	resources[resource_type]["current"] = max(0, current - cost)
	emit_signal("resource_changed", resource_type, resources[resource_type]["current"], max_val)


func consume_resource(resource_type: String, cost: int) -> void:
	_consume_resource(resource_type, cost)


func get_resource_current(resource_type: String) -> int:
	if not resources.has(resource_type):
		return 0
	return resources[resource_type].get("current", 0)


func set_resource_current(resource_type: String, value: int) -> void:
	if not resources.has(resource_type):
		return
	var max_val = resources[resource_type].get("max", 0)
	resources[resource_type]["current"] = clamp(value, 0, max_val)
	emit_signal("resource_changed", resource_type, resources[resource_type]["current"], max_val)


func add_limit_gauge(amount: int) -> void:
	if amount <= 0:
		return
	limit_gauge = clamp(limit_gauge + amount, 0, LIMIT_GAUGE_MAX)


func reset_limit_gauge() -> void:
	limit_gauge = 0


func _merge_stats(overrides: Dictionary) -> Dictionary:
	var merged := stats.duplicate(true)
	for key in overrides.keys():
		merged[key] = overrides[key]
	return merged




func _emit_core_stats() -> void:
	emit_signal("hp_changed", hp_current, stats["hp_max"])
	emit_signal("mp_changed", mp_current, stats["mp_max"])


func _emit_all_resources() -> void:
	for resource_type in resources.keys():
		var entry = resources[resource_type]
		emit_signal("resource_changed", resource_type, entry.get("current", 0), entry.get("max", 0))


func _get_status_id(status: Variant) -> String:
	if status is StatusEffect:
		return status.id
	if status is Dictionary:
		return status.get("id", "")
	return ""
