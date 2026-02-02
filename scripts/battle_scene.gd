extends Node

var battle_manager: BattleManager
var debug_panel: Control
var debug_log: RichTextLabel
var debug_toggle_btn: Button

var party_status_panel: VBoxContainer
var status_effects_display: Label # Renamed to fit purpose
var turn_order_display: Label # Visible turn order at top
var combat_log_display: Label # Toast for battle messages
var boss_hp_label: Label # New Boss HP Bar
var battle_log_panel: RichTextLabel
var demo_running: bool = false
var pending_effect_messages: Array = []
var last_logged_turn_id: String = ""

var battle_menu: BattleMenu
var target_cursor: Node2D
var state = "BATTLE_START" # BATTLE_START, PLAYER_TURN, ENEMY_TURN, BATTLE_END
var active_player_id = ""
var battle_over: bool = false

const BattleMenuScene = preload("res://scenes/ui/battle_menu.tscn")
const TargetCursorScene = preload("res://scenes/ui/target_cursor.tscn")

var ai_controller: AiController


func _ready() -> void:
	battle_manager = BattleManager.new()
	add_child(battle_manager)

	# Setup Debug UI
	_setup_debug_ui()
	
	# Setup Game UI
	_setup_game_ui()

	# Instantiate UI
	battle_menu = BattleMenuScene.instantiate()
	add_child(battle_menu)
	battle_menu.action_selected.connect(_on_menu_action_selected)
	battle_menu.action_blocked.connect(_on_menu_action_blocked)
	battle_menu.menu_changed.connect(_on_menu_changed)
	# battle_menu.menu_canceled.connect(_on_menu_canceled) # Not implemented yet

	target_cursor = TargetCursorScene.instantiate()
	add_child(target_cursor)
	target_cursor.target_selected.connect(_on_target_selected)
	target_cursor.selection_canceled.connect(_on_target_canceled)

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
			"resources": {"ki": {"current": 6, "max": 6}},
			"position": Vector2(800, 150),
			"color": Color(0.5, 0, 0.5) # Purple
		}),
		_make_character({
			"id": "ludwig",
			"display_name": "Ludwig",
			"stats": {"hp_max": 580, "mp_max": 40, "atk": 58, "def": 65, "mag": 22, "spd": 34},
			"resources": {"superiority_dice": {"current": 4, "max": 4}},
			"position": Vector2(850, 220),
			"color": Color.GRAY # Gray
		}),
		_make_character({
			"id": "ninos",
			"display_name": "Ninos",
			"stats": {"hp_max": 420, "mp_max": 110, "atk": 38, "def": 35, "mag": 52, "spd": 42},
			"resources": {"bardic_inspiration": {"current": 4, "max": 4}},
			"position": Vector2(800, 290),
			"color": Color.GREEN # Green
		}),
		_make_character({
			"id": "catraca",
			"display_name": "Catraca",
			"stats": {"hp_max": 360, "mp_max": 120, "atk": 30, "def": 32, "mag": 68, "spd": 40},
			"resources": {"sorcery_points": {"current": 5, "max": 5}},
			"position": Vector2(850, 360),
			"color": Color.RED # Red
		})
	]

	var enemies: Array = [
		_make_boss({
			"id": "marcus_gelt",
			"display_name": "Marcus Gelt",
			"stats": {"hp_max": 1200, "mp_max": 0, "atk": 75, "def": 55, "mag": 35, "spd": 38},
			"phase": 1,
			"position": Vector2(250, 250),
			"color": Color.BLACK # Black
		})
	]

	battle_manager.setup_state(party, enemies)
	battle_manager.start_round()
	var order = battle_manager.battle_state.get("turn_order", [])
	_on_turn_order_updated(order) # Force UI update
	
	# Removed Demo Status Effects (Poison/Regen) 
	
	_update_status_label([
		"Battle Start!",
		"Turn order: " + str(order)
	])
	
	# Start loop
	_process_turn_loop()


func _make_character(data: Dictionary) -> Character:
	var character = Character.new()
	character.setup(data)
	if data.has("position"):
		character.position = data["position"]
	
	# Add Visuals
	var color = data.get("color", Color.WHITE)
	var visual = ColorRect.new()
	visual.size = Vector2(40, 40)
	visual.position = Vector2(-20, -20) # Center
	visual.color = color
	character.add_child(visual)
	
	# Add Name Label above head
	var name_lbl = Label.new()
	name_lbl.text = data.get("display_name", "")
	name_lbl.position = Vector2(-30, -50)
	character.add_child(name_lbl)
	
	add_child(character)
	return character


func _make_boss(data: Dictionary) -> Boss:
	var boss = Boss.new()
	boss.setup(data)
	if data.has("position"):
		boss.position = data["position"]
		
	# Add Visuals (Larger for boss)
	var color = data.get("color", Color.BLACK)
	var visual = ColorRect.new()
	visual.size = Vector2(80, 80)
	visual.position = Vector2(-40, -40) # Center
	visual.color = color
	boss.add_child(visual)
	
	var name_lbl = Label.new()
	name_lbl.text = data.get("display_name", "")
	name_lbl.position = Vector2(-40, -70)
	boss.add_child(name_lbl)
	
	add_child(boss)
	return boss

# Missing Handlers Restored
func _on_message_added(text: String) -> void:
	if debug_log:
		debug_log.add_text(text + "\n")
	if combat_log_display:
		combat_log_display.text = text
	_update_battle_log()

func _on_turn_order_updated(order: Array) -> void:
	# Update general status label if we want to track it
	_update_turn_order_visual()

func _on_active_character_changed(actor_id: String) -> void:
	_update_status_label(["Active Character: " + actor_id])
	_update_turn_order_visual()

func _update_turn_order_visual() -> void:
	if not turn_order_display: return
	var order = battle_manager.battle_state.get("turn_order", [])
	var active = battle_manager.battle_state.get("active_character_id", "")
	if order.is_empty(): return
	
	# Rotate for display: Find active, display from there wrapping around
	var display_order = []
	var start_index = order.find(active)
	if start_index == -1: 
		display_order = order # Fallback
	else:
		# Slice from start to end, then 0 to start
		display_order = order.slice(start_index, order.size()) + order.slice(0, start_index)
	
	turn_order_display.text = "Turn Order: " + " > ".join(display_order)
















func _print_turn_order(order: Array) -> void:
	print("Turn order: ", order)










func _on_action_enqueued(action: Dictionary) -> void:
	print("Action enqueued: ", action)
	# _update_queue_label() # Queuelabel is deprecated


func _on_action_executed(result: Dictionary) -> void:
	print("Action executed: ", result)
	
	# Spawn Floating Text based on result
	if result.get("ok"):
		var payload = result.get("payload", {})
		var target_id = payload.get("target_id", "")
		var target = battle_manager.get_actor_by_id(target_id)
		
		# Handle Damage
		if payload.has("damage"):
			var dmg = payload["damage"]
			if target:
				_create_floating_text(target.position, str(dmg), Color.RED)
			pending_effect_messages.append("Damage: " + str(dmg))
				
		# Handle Healing
		if payload.has("healed"):
			var heal = payload["healed"]
			if target:
				_create_floating_text(target.position, str(heal), Color.GREEN)
			pending_effect_messages.append("Heal: " + str(heal))
				
		# Handle Status/Buffs (Simplified)
		if payload.has("buff"):
			if target: # Self buff usually
				_create_floating_text(target.position, "+" + str(payload["buff"]), Color.CYAN)
			pending_effect_messages.append("Buff: " + str(payload["buff"]))
		elif payload.has("debuff"):
			if target:
				_create_floating_text(target.position, "-" + str(payload["debuff"]), Color.ORANGE)
			pending_effect_messages.append("Debuff: " + str(payload["debuff"]))
		elif payload.has("stun_applied") and payload["stun_applied"]:
			if target:
				_create_floating_text(target.position, "STUNNED", Color.YELLOW)
			pending_effect_messages.append("Status: STUN")
				
	# Pass to log logic...
	pass


func _on_battle_ended(result: String) -> void:
	print("Battle ended: ", result)
	battle_over = true
	_update_status_label(["Battle ended: " + result])







func _compact_lines(lines: Array, max_lines: int) -> String:
	if lines.is_empty():
		return ""
	var start = max(0, lines.size() - max_lines)
	return "\n".join(lines.slice(start, lines.size()))


func _compact_order(order: Array) -> String:
	if order.is_empty():
		return "[]"
	return "[" + ", ".join(order) + "]"


func _process_turn_loop() -> void:
	if battle_over:
		return
	if battle_manager.battle_state.get("turn_order", []).is_empty():
		return

	var actor_id = battle_manager.battle_state.get("active_character_id", "")
	var actor = battle_manager.get_actor_by_id(actor_id)
	
	if actor == null or actor.is_ko():
		battle_manager.advance_turn()
		await get_tree().create_timer(0.5).timeout
		_process_turn_loop()
		return
		
	active_player_id = actor_id
	
	if _is_party_member(actor_id):
		state = "PLAYER_TURN"
		message_log("Player turn: " + actor.display_name)
		battle_menu.set_enabled(true)
		battle_menu.setup(actor)
		_update_menu_disables(actor)
		target_cursor.deactivate()
		# Wait for signal
	else:
		state = "ENEMY_TURN"
		message_log("Enemy turn: " + actor.display_name)
		battle_menu.set_enabled(false)
		target_cursor.deactivate()
		await get_tree().create_timer(1.5).timeout
		_execute_enemy_turn(actor)

func _execute_enemy_turn(actor: Boss) -> void:
	# Use new AI Controller logic
	var ai_action = ai_controller.get_next_action(actor, battle_manager.battle_state)
	
	# Convert generic AI action to BattleManager enqueue
	if ai_action.get("action_id", "") == ActionIds.BASIC_ATTACK:
		var targets = ai_action.get("targets", [])
		if targets.size() > 0:
			battle_manager.enqueue_action(ActionFactory.basic_attack(actor.id, targets[0]))
	elif ai_action.get("action_id", "") == ActionIds.SKIP_TURN:
		battle_manager.enqueue_action(ActionFactory.skip_turn(actor.id))
	else:
		# Fallback or specific boss skills
		battle_manager.enqueue_action(ActionFactory.basic_attack(actor.id, "kairus")) # Fallback
		
	_execute_next_action()


func _on_menu_action_selected(action_id: String) -> void:
	var is_metamagic = action_id == ActionIds.CAT_METAMAGIC_QUICKEN or action_id == ActionIds.CAT_METAMAGIC_TWIN
	if is_metamagic and action_id == ActionIds.CAT_METAMAGIC_TWIN and battle_manager.get_alive_enemies().size() < 2:
		message_log("Twin Spell requires 2+ enemies.")
		battle_menu.visible = true
		return
	battle_menu.visible = not is_metamagic
	var template_action = ActionFactory.create_action(action_id, active_player_id, [])
	var tags = template_action.get("tags", [])
	var target_mode = _determine_target_mode(tags)
	var target_pool = _determine_target_pool(tags, action_id)
	if target_mode == "SINGLE":
		var pending_meta = battle_manager.peek_metamagic(active_player_id)
		if pending_meta == "TWIN":
			if target_pool.size() < 2:
				message_log("Twin Spell requires 2+ targets.")
				battle_menu.visible = true
				return
			target_mode = "DOUBLE"
	
	if target_pool.is_empty() and target_mode != "SELF":
		message_log("No valid targets.")
		battle_menu.visible = true
		return

	if target_mode == "SELF":
		_enqueue_and_execute(action_id, [active_player_id])
	elif target_mode == "ALL":
		target_cursor.start_selection(target_pool, "ALL")
		current_pending_action_id = action_id
	elif target_mode == "DOUBLE":
		target_cursor.start_selection(target_pool, "DOUBLE")
		current_pending_action_id = action_id
	else:
		current_pending_action_id = action_id
		target_cursor.start_selection(target_pool, "SINGLE")


func _on_menu_action_blocked(reason: String) -> void:
	message_log(reason)
	battle_menu.visible = true


func _on_menu_changed(_items: Array) -> void:
	var actor = battle_manager.get_actor_by_id(active_player_id)
	if actor:
		_update_menu_disables(actor)


var current_pending_action_id = ""

func _on_target_selected(target_ids: Array) -> void:
	# Enqueue the pending action with these targets
	target_cursor.deactivate()
	_enqueue_and_execute(current_pending_action_id, target_ids)

func _on_target_canceled() -> void:
	# Go back to menu
	target_cursor.deactivate()
	var actor = battle_manager.get_actor_by_id(active_player_id)
	if actor:
		battle_menu.set_enabled(true)
		battle_menu.setup(actor)

func _enqueue_and_execute(action_id: String, target_ids: Array) -> void:
	# Construct dictionary via Factory is tricky dynamically without a "create_by_id" method
	# We might need to map ID -> Factory Call or just manually construct the dict if we know the ID
	# For this POC, we can use a big match or add a `create_action(id, actor, targets)` to ActionFactory.
	# Let's add `create_action` helper to `battle_scene` or `ActionFactory` later. 
	# For now, I'll implement a helper `_create_action_dict` here.
	
	var action = _create_action_dict(action_id, active_player_id, target_ids)
	battle_manager.enqueue_action(action)
	_execute_next_action()


func _determine_target_mode(tags: Array) -> String:
	if tags.has(ActionTags.SELF):
		return "SELF"
	if tags.has(ActionTags.ALL_ENEMIES) or tags.has(ActionTags.ALL_ALLIES):
		return "ALL"
	return "SINGLE"


func _determine_target_pool(tags: Array, action_id: String) -> Array:
	if tags.has(ActionTags.ALL_ALLIES) or tags.has(ActionTags.BUFF) or tags.has(ActionTags.HEALING) or tags.has(ActionTags.SELF):
		return battle_manager.battle_state.party
	if tags.has(ActionTags.ALL_ENEMIES) or tags.has(ActionTags.PHYSICAL) or tags.has(ActionTags.MAGICAL):
		return battle_manager.battle_state.enemies
	return battle_manager.battle_state.enemies


func _update_menu_disables(actor: Character) -> void:
	var disabled: Dictionary = {}
	for item in battle_menu.menu_items:
		var id = item.get("id", "")
		if id == "ATTACK" or id == "SKILL_SUB" or id == "ITEM_SUB" or id == "META_SUB" or id == "DEFEND" or id == "GUARD_TOGGLE":
			continue
		var action = ActionFactory.create_action(id, actor.id, [])
		if action.get("resource_type", "") != "":
			var cost = action.get("resource_cost", 0)
			if actor.get_resource_current(action.resource_type) < cost:
				disabled[id] = "Not enough " + action.resource_type.capitalize() + "."
				continue
		var mp_cost = action.get("mp_cost", 0)
		if mp_cost > 0 and actor.mp_current < mp_cost:
			disabled[id] = "Not enough MP."
			continue
		if id == ActionIds.CAT_METAMAGIC_TWIN and battle_manager.get_alive_enemies().size() < 2:
			disabled[id] = "Requires 2+ enemies."
			continue
		var tags = action.get("tags", [])
		var pool = _determine_target_pool(tags, id)
		if not tags.has(ActionTags.SELF) and pool.is_empty():
			disabled[id] = "No valid targets."
			continue
	battle_menu.set_disabled_actions(disabled)

func _execute_next_action() -> void:
	var result = battle_manager.process_next_action()
	var payload = result.get("payload", result)
	message_log("Action Result: " + str(payload))
	if payload.get("metamagic", "") != "":
		var actor_meta = battle_manager.get_actor_by_id(active_player_id)
		if actor_meta:
			message_log("Metamagic set: " + str(payload.get("metamagic", "")))
			battle_menu.visible = true
			battle_menu.open_magic_submenu()
			_update_menu_disables(actor_meta)
			return
	
	# End of turn cleanup
	var actor = battle_manager.get_actor_by_id(active_player_id)
	if actor and not payload.get("quicken", false):
		battle_manager.process_end_of_turn_effects(actor)
	if payload.get("quicken", false) and actor and actor.id == "catraca":
		message_log("Quicken: extra action!")
		battle_menu.setup(actor)
		_update_menu_disables(actor)
		return
	
	if battle_over:
		message_log("Battle Ended!")
		return
		
	battle_manager.advance_turn()
	await get_tree().create_timer(0.9).timeout
	_process_turn_loop()

func message_log(msg: String) -> void:
	# Helper to update label
	_update_status_label([msg])
	# Also update toast with delay
	if combat_log_display:
		combat_log_display.text = msg
		# Simple "persistence": If a message comes too fast, it overwrites. 
		# If user wants it to stay for +1s, we should verify it stays *at least* that long if no new msg comes.
		# Ideally we'd have a queue. For now, we trust the turn delays (0.5s/1.0s) help.
		# If we specifically want to FORCE it to persist, we'd need to block updates? 
		# Or just ensure the *previous* toast isn't cleared too fast.
		# Since we have pauses in the Turn Loop, this might be naturally handled.
		# If not, let's add a visual "flash" or something.
		var tween = create_tween()
		combat_log_display.modulate.a = 1.0
		tween.tween_interval(3.0)
		tween.tween_property(combat_log_display, "modulate:a", 0.0, 1.5) # Fade out after 3s

func _create_action_dict(id: String, actor: String, targets: Array) -> Dictionary:
	return ActionFactory.create_action(id, actor, targets)

# --- UI Construction ---
func _setup_debug_ui() -> void:
	# Container for all debug clutter
	debug_panel = Control.new()
	debug_panel.name = "DebugPanel"
	debug_panel.visible = false # Hidden by default
	add_child(debug_panel)
	
	debug_log = RichTextLabel.new()
	debug_log.name = "DebugLog"
	debug_log.position = Vector2(0, 0)
	debug_log.size = Vector2(400, 200)
	debug_panel.add_child(debug_log)
	
	debug_toggle_btn = Button.new()
	debug_toggle_btn.text = "Debug"
	debug_toggle_btn.position = Vector2(10, 10)
	debug_toggle_btn.pressed.connect(func(): debug_panel.visible = !debug_panel.visible)
	add_child(debug_toggle_btn)


func _setup_game_ui() -> void:
	# Party Status Panel (Bottom Right)
	var panel_bg = Panel.new()
	panel_bg.position = Vector2(650, 450)
	panel_bg.size = Vector2(400, 150)
	add_child(panel_bg)
	
	party_status_panel = VBoxContainer.new()
	party_status_panel.position = Vector2(10, 10)
	party_status_panel.size = Vector2(380, 130)
	panel_bg.add_child(party_status_panel)
	
	# Turn Order Display (Top Center)
	turn_order_display = Label.new()
	turn_order_display.position = Vector2(350, 10)
	turn_order_display.size = Vector2(400, 30)
	turn_order_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(turn_order_display)

	# Status Effects Display (Centered below Turn Order)
	status_effects_display = Label.new()
	status_effects_display.position = Vector2(350, 40)
	status_effects_display.size = Vector2(400, 30) 
	status_effects_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(status_effects_display)
	
	# Combat Log Toast (Above Bottom UI)
	combat_log_display = Label.new()
	combat_log_display.position = Vector2(200, 410)
	combat_log_display.size = Vector2(700, 30)
	combat_log_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combat_log_display.text = "Battle Start!"
	
	# Optional: Add a semi-transparent background for readability
	var bg = ColorRect.new()
	bg.show_behind_parent = true
	bg.color = Color(0, 0, 0, 0.5)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	combat_log_display.add_child(bg)
	
	add_child(combat_log_display)
	
	# Boss HP (Below Boss)
	boss_hp_label = Label.new()
	boss_hp_label.position = Vector2(250, 310) # Roughly below boss
	boss_hp_label.size = Vector2(200, 30)
	boss_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_hp_label.text = "Boss HP"
	add_child(boss_hp_label)

	# Battle Log Panel (Left side)
	battle_log_panel = RichTextLabel.new()
	battle_log_panel.position = Vector2(10, 10)
	battle_log_panel.size = Vector2(320, 160)
	battle_log_panel.scroll_active = false
	battle_log_panel.scroll_following = true
	battle_log_panel.add_theme_font_size_override("normal_font_size", 12)
	add_child(battle_log_panel)


func _update_status_label(lines: Array) -> void:
	# Update both debug log and game UI
	var text = "\n".join(lines)
	if debug_log:
		debug_log.text = text
	
	# Update Party Panel
	if party_status_panel:
		for child in party_status_panel.get_children():
			child.queue_free()
		
		# Rebuild party list
		for actor in battle_manager.battle_state.party:
			var hbox = HBoxContainer.new()
			var name_lbl = Label.new()
			name_lbl.text = actor.display_name
			name_lbl.custom_minimum_size = Vector2(100, 0)
			
			var hp_lbl = Label.new()
			hp_lbl.text = "HP: %d/%d" % [actor.hp_current, actor.stats["hp_max"]]
			hp_lbl.custom_minimum_size = Vector2(100, 0)
			
			var mp_lbl = Label.new()
			if actor.stats["mp_max"] > 0:
				mp_lbl.text = "MP:%d/%d" % [actor.mp_current, actor.stats["mp_max"]]
			else:
				mp_lbl.text = ""
			
			# Append unique resources (short labels)
			if actor.resources.has("ki"):
				mp_lbl.text += " | Ki:%d" % actor.get_resource_current("ki")
			if actor.resources.has("superiority_dice"):
				mp_lbl.text += " | SD:%d" % actor.get_resource_current("superiority_dice")
			if actor.resources.has("bardic_inspiration"):
				mp_lbl.text += " | BI:%d" % actor.get_resource_current("bardic_inspiration")
			if actor.resources.has("sorcery_points"):
				mp_lbl.text += " | SP:%d" % actor.get_resource_current("sorcery_points")
			mp_lbl.text += " | LB:%d%%" % actor.limit_gauge
			
			var lb_bar = ProgressBar.new()
			lb_bar.min_value = 0
			lb_bar.max_value = 100
			lb_bar.value = actor.limit_gauge
			lb_bar.custom_minimum_size = Vector2(120, 8)
			lb_bar.show_percentage = false
			
			hbox.add_child(name_lbl)
			hbox.add_child(hp_lbl)
			hbox.add_child(mp_lbl)
			hbox.add_child(lb_bar)
			party_status_panel.add_child(hbox)

	# Update Boss Status (Simple Label above boss if exists or separate panel)
	# For simplicity, let's find the boss or use a dedicated Boss Label if we created one.
	# We didn't create a dedicated variable for boss UI yet, so let's add it dynamically or just rely on a new label.
	if boss_hp_label:
		var enemies = battle_manager.get_alive_enemies()
		if enemies.size() > 0:
			var boss = enemies[0]
			boss_hp_label.text = "%s HP: %d/%d" % [boss.display_name, boss.hp_current, boss.stats["hp_max"]]
		else:
			boss_hp_label.text = "Victory?"
			
	# Update Status Effects Label
	_update_status_effects_text()


func _update_battle_log() -> void:
	if battle_log_panel == null:
		return
	var lines = battle_manager.battle_state.get("message_log", [])
	var start = max(0, lines.size() - 6)
	var effect_lines = []
	if pending_effect_messages.size() > 0:
		effect_lines = pending_effect_messages.duplicate()
		pending_effect_messages.clear()
	var combined = lines.slice(start, lines.size()) + effect_lines
	var turn_header = _get_turn_header()
	if not turn_header.is_empty():
		combined.append(turn_header)
	combined.append("---------------")
	battle_log_panel.text = "Log:\n" + "\n".join(combined)


func _get_turn_header() -> String:
	var turn_id = str(battle_manager.battle_state.get("turn_count", 0)) + ":" + \
		str(battle_manager.battle_state.get("active_character_id", ""))
	if turn_id == last_logged_turn_id:
		return ""
	last_logged_turn_id = turn_id
	return "---- Turn " + str(battle_manager.battle_state.get("turn_count", 0)) + \
		" (" + str(battle_manager.battle_state.get("active_character_id", "")) + ") ----"


func _update_status_effects_text() -> void:
	var active_statuses = []
	for member in battle_manager.battle_state.party:
		if member.status_effects.size() > 0:
			var effect_names = []
			for effect in member.status_effects:
				effect_names.append(effect.id)
			active_statuses.append(member.display_name + ": [" + ", ".join(effect_names) + "]")
	
	for enemy in battle_manager.battle_state.enemies:
		if enemy.status_effects.size() > 0:
			var effect_names = []
			for effect in enemy.status_effects:
				effect_names.append(effect.id)
			active_statuses.append(enemy.display_name + ": [" + ", ".join(effect_names) + "]")
			
	if status_effects_display:
		if active_statuses.is_empty():
			status_effects_display.text = ""
		else:
			status_effects_display.text = "Statuses: " + " | ".join(active_statuses)


func _create_floating_text(pos: Vector2, text: String, color: Color) -> void:
	var label = Label.new()
	label.text = text
	label.modulate = color
	label.position = pos + Vector2(0, -50) # Start above character
	label.add_theme_font_size_override("font_size", 24)
	add_child(label)
	
	# Tween it up and fade out
	var tween = create_tween()
	tween.parallel().tween_property(label, "position:y", label.position.y - 50, 1.0)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)

func _is_party_member(actor_id: String) -> bool:
	for member in battle_manager.battle_state.party:
		if member.id == actor_id:
			return true
	return false
