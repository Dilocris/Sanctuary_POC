extends Node

var battle_manager: BattleManager
var status_label: Label


func _ready() -> void:
	battle_manager = BattleManager.new()
	add_child(battle_manager)

	status_label = _make_status_label()
	add_child(status_label)

	var party: Array = [
		_make_character({
			"id": "kairus",
			"display_name": "Kairus",
			"stats": {"hp_max": 450, "mp_max": 60, "atk": 62, "def": 42, "mag": 28, "spd": 55},
			"resources": {"ki": {"current": 6, "max": 6}}
		}),
		_make_character({
			"id": "ludwig",
			"display_name": "Ludwig",
			"stats": {"hp_max": 580, "mp_max": 40, "atk": 58, "def": 65, "mag": 22, "spd": 34},
			"resources": {"superiority_dice": {"current": 4, "max": 4}}
		}),
		_make_character({
			"id": "ninos",
			"display_name": "Ninos",
			"stats": {"hp_max": 420, "mp_max": 110, "atk": 38, "def": 35, "mag": 52, "spd": 42},
			"resources": {"bardic_inspiration": {"current": 4, "max": 4}}
		}),
		_make_character({
			"id": "catraca",
			"display_name": "Catraca",
			"stats": {"hp_max": 360, "mp_max": 120, "atk": 30, "def": 32, "mag": 68, "spd": 40},
			"resources": {"sorcery_points": {"current": 5, "max": 5}}
		})
	]

	var enemies: Array = [
		_make_character({
			"id": "marcus_gelt",
			"display_name": "Marcus Gelt",
			"stats": {"hp_max": 1200, "mp_max": 0, "atk": 75, "def": 55, "mag": 35, "spd": 38}
		})
	]

	battle_manager.setup_state(party, enemies)
	battle_manager.start_round()
	var order = battle_manager.battle_state.get("turn_order", [])
	_print_turn_order(order)

	var attack_result = battle_manager.execute_basic_attack("kairus", "marcus_gelt", 1.0)
	var marcus = battle_manager.get_actor_by_id("marcus_gelt")
	var hp_line = ""
	if marcus != null:
		hp_line = "Marcus HP: " + str(marcus.hp_current) + "/" + str(marcus.stats["hp_max"])
	var result_line = "Attack result: " + str(attack_result)
	var order_line = "Turn order: " + str(order)
	_update_status_label([order_line, result_line, hp_line])


func _make_character(data: Dictionary) -> Character:
	var character = Character.new()
	character.setup(data)
	add_child(character)
	return character


func _make_status_label() -> Label:
	var label = Label.new()
	label.name = "BattleDebug"
	label.anchor_left = 0.0
	label.anchor_top = 0.0
	label.anchor_right = 1.0
	label.anchor_bottom = 0.0
	label.offset_left = 12
	label.offset_top = 12
	label.offset_right = -12
	label.offset_bottom = 120
	label.text = "Battle debug: initializing..."
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _print_turn_order(order: Array) -> void:
	print("Turn order: ", order)


func _update_status_label(lines: Array) -> void:
	if status_label == null:
		return
	status_label.text = "\n".join(lines)
