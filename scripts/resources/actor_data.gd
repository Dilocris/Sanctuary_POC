extends Resource
class_name ActorData

@export var id: String = ""
@export var display_name: String = ""
@export var stats: Dictionary = {
	"hp_max": 1,
	"mp_max": 0,
	"atk": 0,
	"def": 0,
	"mag": 0,
	"spd": 0
}
@export var resources: Dictionary = {}
@export var status_effects: Array = []
@export var position: Vector2 = Vector2.ZERO
@export var color: Color = Color.WHITE
@export var is_boss: bool = false
@export var phase: int = 1
