extends Node

var battle_manager: BattleManager
var status_label: Label
var log_panel: RichTextLabel
var turn_order_label: Label
var action_log_label: Label
var queue_label: Label
var resource_label: Label
var status_effects_label: Label
var demo_running: bool = false
var ai_controller: AiController


func _ready() -> void:
	battle_manager = BattleManager.new()
	add_child(battle_manager)

	status_label = _make_status_label()
	add_child(status_label)
	log_panel = _make_log_panel()
	add_child(log_panel)
	turn_order_label = _make_turn_order_label()
	add_child(turn_order_label)
	action_log_label = _make_action_log_label()
	add_child(action_log_label)
	queue_label = _make_queue_label()
	add_child(queue_label)
	resource_label = _make_resource_label()
	add_child(resource_label)
	status_effects_label = _make_status_effects_label()
	add_child(status_effects_label)

	battle_manager.message_added.connect(_on_message_added)
	battle_manager.turn_order_updated.connect(_on_turn_order_updated)
	battle_manager.active_character_changed.connect(_on_active_character_changed)
	battle_manager.action_enqueued.connect(_on_action_enqueued)
	battle_manager.action_executed.connect(_on_action_executed)
	battle_manager.battle_ended.connect(_on_battle_ended)
	ai_controller = AiController.new()

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
		_make_boss({
			"id": "marcus_gelt",
			"display_name": "Marcus Gelt",
			"stats": {"hp_max": 1200, "mp_max": 0, "atk": 75, "def": 55, "mag": 35, "spd": 38},
			"phase": 1
		})
	]

	battle_manager.setup_state(party, enemies)
	battle_manager.start_round()
	var order = battle_manager.battle_state.get("turn_order", [])
	_print_turn_order(order)
	var kairus = battle_manager.get_actor_by_id("kairus")
	var ninos = battle_manager.get_actor_by_id("ninos")
	if kairus != null:
		kairus.add_status(StatusEffectFactory.poison())
	if ninos != null:
		ninos.add_status(StatusEffectFactory.regen())
	_update_status_label([
		"Turn order: " + str(order),
		"Running demo...",
		"Applied POISON to Kairus.",
		"Applied REGEN to Ninos."
	])
	await _run_demo_round()


func _make_character(data: Dictionary) -> Character:
	var character = Character.new()
	character.setup(data)
	add_child(character)
	return character


func _make_boss(data: Dictionary) -> Boss:
	var boss = Boss.new()
	boss.setup(data)
	add_child(boss)
	return boss


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


func _make_log_panel() -> RichTextLabel:
	var panel = RichTextLabel.new()
	panel.name = "MessageLog"
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 0.0
	panel.offset_left = 12
	panel.offset_top = 140
	panel.offset_right = -12
	panel.offset_bottom = 280
	panel.fit_content = true
	panel.scroll_active = false
	panel.scroll_following = true
	panel.text = "Message log:\n"
	return panel


func _make_turn_order_label() -> Label:
	var label = Label.new()
	label.name = "TurnOrder"
	label.anchor_left = 0.0
	label.anchor_top = 0.0
	label.anchor_right = 1.0
	label.anchor_bottom = 0.0
	label.offset_left = 12
	label.offset_top = 300
	label.offset_right = -12
	label.offset_bottom = 360
	label.text = "Turn order: (pending)"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _make_action_log_label() -> Label:
	var label = Label.new()
	label.name = "ActionLog"
	label.anchor_left = 0.0
	label.anchor_top = 0.0
	label.anchor_right = 1.0
	label.anchor_bottom = 0.0
	label.offset_left = 12
	label.offset_top = 380
	label.offset_right = -12
	label.offset_bottom = 440
	label.text = "Action log: (pending)"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _make_queue_label() -> Label:
	var label = Label.new()
	label.name = "QueueLabel"
	label.anchor_left = 0.0
	label.anchor_top = 0.0
	label.anchor_right = 1.0
	label.anchor_bottom = 0.0
	label.offset_left = 12
	label.offset_top = 460
	label.offset_right = -12
	label.offset_bottom = 520
	label.text = "Queue size: 0"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _make_resource_label() -> Label:
	var label = Label.new()
	label.name = "ResourceLabel"
	label.anchor_left = 0.0
	label.anchor_top = 0.0
	label.anchor_right = 1.0
	label.anchor_bottom = 0.0
	label.offset_left = 12
	label.offset_top = 540
	label.offset_right = -12
	label.offset_bottom = 600
	label.text = "Resources: (pending)"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _make_status_effects_label() -> Label:
	var label = Label.new()
	label.name = "StatusEffectsLabel"
	label.anchor_left = 0.0
	label.anchor_top = 0.0
	label.anchor_right = 1.0
	label.anchor_bottom = 0.0
	label.offset_left = 600
	label.offset_top = 12
	label.offset_right = -12
	label.offset_bottom = 200
	label.text = "Active Statuses:\n(None)"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _print_turn_order(order: Array) -> void:
	print("Turn order: ", order)


func _update_status_label(lines: Array) -> void:
	if status_label == null:
		return
	status_label.text = _compact_lines(lines, 3)


func _on_message_added(text: String) -> void:
	if log_panel == null:
		return
	var lines = battle_manager.battle_state.get("message_log", [])
	log_panel.text = "Message log:\n" + _compact_lines(lines, 6)


func _on_turn_order_updated(order: Array) -> void:
	if turn_order_label == null:
		return
	turn_order_label.text = "Turn order: " + _compact_order(order)


func _on_active_character_changed(actor_id: String) -> void:
	if turn_order_label == null:
		return
	turn_order_label.text = "Turn order: " + _compact_order(battle_manager.battle_state.get("turn_order", [])) + \
		"\nActive: " + actor_id


func _on_action_enqueued(action: Dictionary) -> void:
	print("Action enqueued: ", action)
	_update_queue_label()


func _on_action_executed(result: Dictionary) -> void:
	print("Action executed: ", result)
	if action_log_label != null:
		action_log_label.text = "Action log: " + str(result.get("payload", result))
	_update_queue_label()
	_update_resource_label()


func _on_battle_ended(result: String) -> void:
	print("Battle ended: ", result)
	_update_status_label(["Battle ended: " + result])


func _update_queue_label() -> void:
	if queue_label == null:
		return
	queue_label.text = "Queue size: " + str(battle_manager.battle_state.get("action_queue", []).size())


func _update_resource_label() -> void:
	if resource_label == null:
		return
	var kairus = battle_manager.get_actor_by_id("kairus")
	if kairus == null:
		resource_label.text = "Resources: (kairus missing)"
		return
	var ki_line = "Kairus Ki: " + str(kairus.get_resource_current("ki")) + "/" + \
		str(kairus.resources.get("ki", {}).get("max", 0))
	var imbue_line = "Fire Imbue: " + ("ON" if kairus.has_status(StatusEffectIds.FIRE_IMBUE) else "OFF")
	resource_label.text = ki_line + "\n" + imbue_line
	_update_status_effects_text()

func _update_status_effects_text() -> void:
	if status_effects_label == null:
		return
	var text = "Active Statuses:\n"
	var actors = battle_manager.battle_state.party + battle_manager.battle_state.enemies
	for actor in actors:
		if actor.status_effects.size() > 0:
			var statuses = []
			for s in actor.status_effects:
				statuses.append(battle_manager._get_status_id(s))
			text += actor.display_name + ": " + ", ".join(statuses) + "\n"
	status_effects_label.text = text


func _compact_lines(lines: Array, max_lines: int) -> String:
	if lines.is_empty():
		return ""
	var start = max(0, lines.size() - max_lines)
	return "\n".join(lines.slice(start, lines.size()))


func _compact_order(order: Array) -> String:
	if order.is_empty():
		return "[]"
	return "[" + ", ".join(order) + "]"


func _run_demo_round() -> void:
	if demo_running:
		return
	demo_running = true
	var order = battle_manager.battle_state.get("turn_order", [])
	if order.is_empty():
		demo_running = false
		return

	var turns_to_run = order.size() * 2
	for _i in range(turns_to_run):
		var actor_id = battle_manager.battle_state.get("active_character_id", "")
		var actor = battle_manager.get_actor_by_id(actor_id)
		if actor != null:
			_handle_turn(actor_id)
			battle_manager.process_end_of_turn_effects(actor)
			if actor.is_ko():
				print("Actor KO: ", actor_id)
		battle_manager.advance_turn()
		await get_tree().create_timer(0.6).timeout

	_update_status_label(["Round complete.", "Check console for details."])
	demo_running = false


func _handle_turn(actor_id: String) -> void:
	var order = battle_manager.battle_state.get("turn_order", [])
	var marcus = battle_manager.get_actor_by_id("marcus_gelt")
	var header = "Active: " + actor_id + " | Turn: " + str(battle_manager.battle_state.turn_count)

	if _is_party_member(actor_id):
		var processed = false
		var result_payload = {}
		
		# Kairus Logic
		if actor_id == "kairus":
			var kairus = battle_manager.get_actor_by_id("kairus")
			if battle_manager.battle_state.turn_count % 2 == 0:
				if kairus != null and kairus.get_resource_current("ki") >= 2:
					battle_manager.enqueue_action(ActionFactory.kairus_flurry(actor_id, "marcus_gelt"))
				else:
					battle_manager.enqueue_action(ActionFactory.basic_attack(actor_id, "marcus_gelt", 1.0))
			else:
				if kairus != null and kairus.has_status(StatusEffectIds.FIRE_IMBUE):
					battle_manager.enqueue_action(ActionFactory.kairus_fire_imbue(actor_id))
				elif kairus != null and kairus.get_resource_current("ki") >= 1:
					battle_manager.enqueue_action(ActionFactory.kairus_fire_imbue(actor_id))
				else:
					battle_manager.enqueue_action(ActionFactory.basic_attack(actor_id, "marcus_gelt", 1.0))
			processed = true

		# Ludwig Logic
		elif actor_id == "ludwig":
			var ludwig = battle_manager.get_actor_by_id("ludwig")
			if ludwig != null:
				if battle_manager.battle_state.turn_count % 3 == 0:
					if not ludwig.has_status(StatusEffectIds.GUARD_STANCE):
						battle_manager.enqueue_action(ActionFactory.ludwig_guard_stance(actor_id))
					else:
						battle_manager.enqueue_action(ActionFactory.ludwig_rally(actor_id, "ludwig"))
				else:
					if ludwig.has_status(StatusEffectIds.GUARD_STANCE):
						battle_manager.enqueue_action(ActionFactory.ludwig_guard_stance(actor_id))
					else:
						if ludwig.get_resource_current("superiority_dice") > 0:
							battle_manager.enqueue_action(ActionFactory.ludwig_lunging_attack(actor_id, "marcus_gelt"))
						else:
							battle_manager.enqueue_action(ActionFactory.basic_attack(actor_id, "marcus_gelt"))
			processed = true

		# Ninos Logic
		elif actor_id == "ninos":
			var ninos = battle_manager.get_actor_by_id("ninos")
			if ninos != null:
				if battle_manager.battle_state.turn_count % 3 == 0:
					# Use Bless if MP available, else Mockery
					if ninos.mp_current >= 10:
						battle_manager.enqueue_action(ActionFactory.ninos_bless(actor_id, ["kairus", "ludwig", "ninos", "catraca"]))
					else:
						# Fallback if low MP
						battle_manager.enqueue_action(ActionFactory.basic_attack(actor_id, "marcus_gelt"))
				elif battle_manager.battle_state.turn_count % 3 == 1:
					# Use Vicious Mockery
					if ninos.mp_current >= 5:
						battle_manager.enqueue_action(ActionFactory.ninos_vicious_mockery(actor_id, "marcus_gelt"))
					else:
						battle_manager.enqueue_action(ActionFactory.basic_attack(actor_id, "marcus_gelt"))
				else:
					# Healing Word on random ally or Inspire Attack on Kairus
					if ninos.get_resource_current("bardic_inspiration") > 0:
						battle_manager.enqueue_action(ActionFactory.ninos_inspire_attack(actor_id, "kairus"))
					elif ninos.mp_current >= 6:
						battle_manager.enqueue_action(ActionFactory.ninos_healing_word(actor_id, "ludwig")) # Heal tank
					else:
						battle_manager.enqueue_action(ActionFactory.basic_attack(actor_id, "marcus_gelt"))
			processed = true

		# Catraca Logic
		elif actor_id == "catraca":
			var catraca = battle_manager.get_actor_by_id("catraca")
			if catraca != null:
				# Use Mage Armor if not active
				if not catraca.has_status(StatusEffectIds.MAGE_ARMOR):
					battle_manager.enqueue_action(ActionFactory.catraca_mage_armor(actor_id))
				else:
					# Cycle between Fireball (AoE cheap sim) and Fire Bolt
					# If enough Sorcery Points/MP, use Fireball (simulating Quickened or just big spell)
					if battle_manager.battle_state.turn_count % 3 == 0 and catraca.mp_current >= 18:
						battle_manager.enqueue_action(ActionFactory.catraca_fireball(actor_id, ["marcus_gelt"]))
					else:
						battle_manager.enqueue_action(ActionFactory.catraca_fire_bolt(actor_id, "marcus_gelt"))
			processed = true

		# Default Logic/Fallback
		if not processed:
			battle_manager.enqueue_action(ActionFactory.basic_attack(actor_id, "marcus_gelt", 1.0))

		var result = battle_manager.process_next_action()
		result_payload = result.get("payload", result)

		var hp_line = ""
		if marcus != null:
			hp_line = "Marcus HP: " + str(marcus.hp_current) + "/" + str(marcus.stats["hp_max"])
		
		_update_status_label([header, "Turn order: " + str(order), "Action: " + str(result_payload), hp_line])
	else:
		var boss = battle_manager.get_actor_by_id(actor_id)
		var ai_action = {}
		if boss is Boss:
			ai_action = ai_controller.get_next_action(boss, battle_manager.battle_state)
		var ai_summary = "Enemy turn: " + str(ai_action)
		if ai_action.get("action_id", "") == ActionIds.BASIC_ATTACK:
			var target_id = ""
			var targets = ai_action.get("targets", [])
			if targets.size() > 0:
				target_id = targets[0]
			if target_id != "":
				battle_manager.enqueue_action(ActionFactory.basic_attack(actor_id, target_id, 1.0))
				var ai_result = battle_manager.process_next_action()
				ai_summary += " -> " + str(ai_result.get("payload", ai_result))
		elif ai_action.get("action_id", "") == ActionIds.SKIP_TURN:
			battle_manager.enqueue_action(ActionFactory.skip_turn(actor_id))
			var skip_result = battle_manager.process_next_action()
			ai_summary += " -> " + str(skip_result.get("payload", skip_result))
		_update_status_label([header, ai_summary])
	print(header)


func _is_party_member(actor_id: String) -> bool:
	for member in battle_manager.battle_state.party:
		if member.id == actor_id:
			return true
	return false
