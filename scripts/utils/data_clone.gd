extends RefCounted
class_name DataClone

## DataClone - Safe deep-copy helpers for runtime mutation

static func dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value.duplicate(true)
	return {}


static func array(value: Variant) -> Array:
	if value is Array:
		return value.duplicate(true)
	return []


static func variant(value: Variant) -> Variant:
	if value is Dictionary:
		return value.duplicate(true)
	if value is Array:
		return value.duplicate(true)
	return value


static func resource_to_dict(resource: Resource) -> Dictionary:
	if resource == null:
		return {}
	var output: Dictionary = {}
	for entry in resource.get_property_list():
		if not entry.has("name") or not entry.has("usage"):
			continue
		var usage = entry["usage"]
		if (usage & PROPERTY_USAGE_STORAGE) == 0:
			continue
		var name = entry["name"]
		output[name] = variant(resource.get(name))
	return output
