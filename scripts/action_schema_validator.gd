extends RefCounted
class_name ActionSchemaValidator

static func validate(action: Dictionary) -> Dictionary:
	if not action.has("action_id") or not action.has("actor_id"):
		return ActionResult.new(false, "missing_fields").to_dict()
	if not (action.get("targets", []) is Array):
		return ActionResult.new(false, "invalid_targets").to_dict()
	if action.has("tags") and not (action.get("tags") is Array):
		return ActionResult.new(false, "invalid_tags").to_dict()
	return ActionResult.new(true).to_dict()
