extends RefCounted
class_name ActionResult

var ok: bool
var error: String
var payload: Dictionary


func _init(success: bool = true, error_text: String = "", data: Dictionary = {}) -> void:
	ok = success
	error = error_text
	payload = data


func to_dict() -> Dictionary:
	return {
		"ok": ok,
		"error": error,
		"payload": payload
	}
