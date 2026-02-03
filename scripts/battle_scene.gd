extends Node

var battle_manager: BattleManager
var debug_panel: Control
var debug_log: RichTextLabel
var debug_toggle_btn: Button

var party_status_panel: VBoxContainer
var status_effects_display: Label # Renamed to fit purpose
var turn_order_display: Label # Visible turn order at top
var combat_log_display: Label # Toast for battle messages
var enemy_intent_label: Label
var enemy_intent_bg: ColorRect
var boss_hp_bar: ProgressBar
var boss_hp_bar_label: Label
var boss_hp_fill_style: StyleBoxFlat
var battle_log_panel: RichTextLabel
var demo_running: bool = false
var pending_effect_messages: Array = []
var last_logged_turn_id: String = ""
var actor_sprites: Dictionary = {}
var actor_name_labels: Dictionary = {}
var input_cooldown_until_ms: int = 0
var actor_idle_tweens: Dictionary = {}
var actor_base_positions: Dictionary = {}
var actor_action_tweens: Dictionary = {}
var actor_shake_tweens: Dictionary = {}
var actor_nodes: Dictionary = {}
var actor_root_positions: Dictionary = {}
var actor_global_idle_tweens: Dictionary = {}
var actor_global_idle_tokens: Dictionary = {}

var battle_menu: BattleMenu
var target_cursor: Node2D
var state = "BATTLE_START" # BATTLE_START, PLAYER_TURN, ENEMY_TURN, BATTLE_END
var active_player_id = ""
var battle_over: bool = false
var pending_enemy_action: Dictionary = {}
const ACTOR_SCALE := 2.0
const BOSS_SCALE := 2.0
const ACTIVE_NAME_COLOR := Color(1.0, 0.9, 0.4)
const INACTIVE_NAME_COLOR := Color(1, 1, 1)
const ACTIVE_NAME_FONT_SIZE := 16
const INACTIVE_NAME_FONT_SIZE := 13
const LOWER_UI_TOP := 492
@export var enemy_intent_duration := 2.0
const HERO_POSITIONS := {
	"kairus": Vector2(735, 326),
	"ludwig": Vector2(607, 250),
	"ninos": Vector2(802, 208),
	"catraca": Vector2(895, 280)
}
const BOSS_POSITION := Vector2(286, 248)

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

	# Background
	_setup_background()

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
			"position": HERO_POSITIONS.kairus,
			"color": Color(0.5, 0, 0.5) # Purple
		}),
		_make_character({
			"id": "ludwig",
			"display_name": "Ludwig",
			"stats": {"hp_max": 580, "mp_max": 40, "atk": 58, "def": 65, "mag": 22, "spd": 34},
			"resources": {"superiority_dice": {"current": 4, "max": 4}},
			"position": HERO_POSITIONS.ludwig,
			"color": Color.GRAY # Gray
		}),
		_make_character({
			"id": "ninos",
			"display_name": "Ninos",
			"stats": {"hp_max": 420, "mp_max": 110, "atk": 38, "def": 35, "mag": 52, "spd": 42},
			"resources": {"bardic_inspiration": {"current": 4, "max": 4}},
			"position": HERO_POSITIONS.ninos,
			"color": Color.GREEN # Green
		}),
		_make_character({
			"id": "catraca",
			"display_name": "Catraca",
			"stats": {"hp_max": 360, "mp_max": 120, "atk": 30, "def": 32, "mag": 68, "spd": 40},
			"resources": {"sorcery_points": {"current": 5, "max": 5}},
			"position": HERO_POSITIONS.catraca,
			"color": Color.RED # Red
		})
	]

	var enemies: Array = [
		_make_boss({
			"id": "marcus_gelt",
			"display_name": "Marcus Gelt",
			"stats": {"hp_max": 1200, "mp_max": 0, "atk": 75, "def": 55, "mag": 35, "spd": 38},
			"phase": 1,
			"position": BOSS_POSITION,
			"color": Color.BLACK # Black
		})
	]

	battle_manager.setup_state(party, enemies)
	battle_manager.start_round()
	var order = battle_manager.battle_state.get("turn_order", [])
	_on_turn_order_updated(order) # Force UI update
	_start_global_idle_all()
	
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
	actor_nodes[data.get("id", "")] = character
	actor_root_positions[data.get("id", "")] = character.position
	
	# Add Visuals
	var sprite_path = ""
	var sprite_size = Vector2(40, 40)
	match data.get("id", ""):
		"kairus":
			sprite_path = "res://assets/sprites/characters/kairus_sprite_main.png"
		"catraca":
			sprite_path = "res://assets/sprites/characters/catraca_sprite_main.png"
		"ninos":
			sprite_path = "res://assets/sprites/characters/ninos_sprite_main.png"
		"ludwig":
			sprite_path = "res://assets/sprites/characters/Ludwig_sprite_main.png"
	if sprite_path != "":
		var sprite = Sprite2D.new()
		sprite.name = "Visual"
		sprite.texture = load(sprite_path)
		sprite.centered = false
		sprite.position = Vector2(0, 0)
		sprite.scale = Vector2(ACTOR_SCALE, ACTOR_SCALE)
		if sprite.texture:
			sprite_size = sprite.texture.get_size() * ACTOR_SCALE
		character.add_child(sprite)
		actor_sprites[data.get("id", "")] = sprite
		actor_base_positions[data.get("id", "")] = sprite.position
	else:
		var color = data.get("color", Color.WHITE)
		var visual = ColorRect.new()
		visual.name = "Visual"
		visual.size = Vector2(40, 40)
		visual.position = Vector2(-20, -20) # Center
		visual.color = color
		character.add_child(visual)
		sprite_size = visual.size
		actor_sprites[data.get("id", "")] = visual
		actor_base_positions[data.get("id", "")] = visual.position
	
	# Add Name Label above head
	var name_lbl = Label.new()
	name_lbl.text = data.get("display_name", "")
	name_lbl.position = Vector2(0, sprite_size.y + 4)
	name_lbl.size = Vector2(max(sprite_size.x, 80), 20)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_active_name_style(name_lbl, false)
	character.add_child(name_lbl)
	actor_name_labels[data.get("id", "")] = name_lbl
	
	add_child(character)
	return character


func _make_boss(data: Dictionary) -> Boss:
	var boss = Boss.new()
	boss.setup(data)
	if data.has("position"):
		boss.position = data["position"]
	actor_nodes[data.get("id", "")] = boss
	actor_root_positions[data.get("id", "")] = boss.position
		
	# Add Visuals (Larger for boss)
	var sprite_path = "res://assets/sprites/characters/marcus_sprite_main.png"
	if ResourceLoader.exists(sprite_path):
		var sprite = Sprite2D.new()
		sprite.name = "Visual"
		sprite.texture = load(sprite_path)
		var tex_size = sprite.texture.get_size()
		sprite.centered = false
		sprite.position = Vector2(0, 0)
		sprite.scale = Vector2(BOSS_SCALE, BOSS_SCALE)
		boss.add_child(sprite)
		actor_sprites[data.get("id", "")] = sprite
		actor_base_positions[data.get("id", "")] = sprite.position
		
		var name_lbl = Label.new()
		name_lbl.text = data.get("display_name", "")
		var scaled_size = tex_size * BOSS_SCALE
		name_lbl.position = Vector2(0, scaled_size.y + 6)
		name_lbl.size = Vector2(max(scaled_size.x, 120), 20)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_apply_active_name_style(name_lbl, false)
		boss.add_child(name_lbl)
		actor_name_labels[data.get("id", "")] = name_lbl
		
		boss_hp_bar = ProgressBar.new()
		boss_hp_bar.min_value = 0
		boss_hp_bar.max_value = data.get("stats", {}).get("hp_max", 1)
		boss_hp_bar.value = boss_hp_bar.max_value
		boss_hp_bar.show_percentage = false
		boss_hp_bar.position = Vector2(name_lbl.position.x, name_lbl.position.y + name_lbl.size.y + 2)
		boss_hp_bar.size = Vector2(name_lbl.size.x, 26)
		boss_hp_bar_label = Label.new()
		boss_hp_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		boss_hp_bar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		boss_hp_bar_label.anchor_right = 1.0
		boss_hp_bar_label.anchor_bottom = 1.0
		boss_hp_bar_label.offset_left = 0.0
		boss_hp_bar_label.offset_top = 0.0
		boss_hp_bar_label.offset_right = 0.0
		boss_hp_bar_label.offset_bottom = 0.0
		boss_hp_bar.add_child(boss_hp_bar_label)
		
		var bg_style = StyleBoxFlat.new()
		bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
		bg_style.corner_radius_top_left = 8
		bg_style.corner_radius_top_right = 8
		bg_style.corner_radius_bottom_left = 8
		bg_style.corner_radius_bottom_right = 8
		boss_hp_fill_style = StyleBoxFlat.new()
		boss_hp_fill_style.bg_color = Color(0.2, 0.8, 0.2)
		boss_hp_fill_style.corner_radius_top_left = 8
		boss_hp_fill_style.corner_radius_top_right = 8
		boss_hp_fill_style.corner_radius_bottom_left = 8
		boss_hp_fill_style.corner_radius_bottom_right = 8
		boss_hp_bar.add_theme_stylebox_override("background", bg_style)
		boss_hp_bar.add_theme_stylebox_override("fill", boss_hp_fill_style)
		boss_hp_bar.add_theme_stylebox_override("fg", boss_hp_fill_style)
		boss.add_child(boss_hp_bar)
	else:
		var color = data.get("color", Color.BLACK)
		var visual = ColorRect.new()
		visual.name = "Visual"
		visual.size = Vector2(80, 80)
		visual.position = Vector2(0, 0) # Top-left
		visual.color = color
		boss.add_child(visual)
		actor_sprites[data.get("id", "")] = visual
		actor_base_positions[data.get("id", "")] = visual.position
		var name_lbl = Label.new()
		name_lbl.text = data.get("display_name", "")
		name_lbl.position = Vector2(0, visual.size.y + 6)
		name_lbl.size = Vector2(max(visual.size.x, 120), 20)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_apply_active_name_style(name_lbl, false)
		boss.add_child(name_lbl)
		actor_name_labels[data.get("id", "")] = name_lbl
		boss_hp_bar = ProgressBar.new()
		boss_hp_bar.min_value = 0
		boss_hp_bar.max_value = data.get("stats", {}).get("hp_max", 1)
		boss_hp_bar.value = boss_hp_bar.max_value
		boss_hp_bar.show_percentage = false
		boss_hp_bar.position = Vector2(name_lbl.position.x, name_lbl.position.y + name_lbl.size.y + 2)
		boss_hp_bar.size = Vector2(name_lbl.size.x, 26)
		boss_hp_bar_label = Label.new()
		boss_hp_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		boss_hp_bar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		boss_hp_bar_label.anchor_right = 1.0
		boss_hp_bar_label.anchor_bottom = 1.0
		boss_hp_bar_label.offset_left = 0.0
		boss_hp_bar_label.offset_top = 0.0
		boss_hp_bar_label.offset_right = 0.0
		boss_hp_bar_label.offset_bottom = 0.0
		boss_hp_bar.add_child(boss_hp_bar_label)
		
		var bg_style = StyleBoxFlat.new()
		bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
		bg_style.corner_radius_top_left = 8
		bg_style.corner_radius_top_right = 8
		bg_style.corner_radius_bottom_left = 8
		bg_style.corner_radius_bottom_right = 8
		boss_hp_fill_style = StyleBoxFlat.new()
		boss_hp_fill_style.bg_color = Color(0.2, 0.8, 0.2)
		boss_hp_fill_style.corner_radius_top_left = 8
		boss_hp_fill_style.corner_radius_top_right = 8
		boss_hp_fill_style.corner_radius_bottom_left = 8
		boss_hp_fill_style.corner_radius_bottom_right = 8
		boss_hp_bar.add_theme_stylebox_override("background", bg_style)
		boss_hp_bar.add_theme_stylebox_override("fill", boss_hp_fill_style)
		boss_hp_bar.add_theme_stylebox_override("fg", boss_hp_fill_style)
		boss.add_child(boss_hp_bar)
	
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
	_update_active_character_highlight(actor_id)
	_update_active_idle_motion(actor_id)

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
		var attacker_id = payload.get("attacker_id", "")
		if attacker_id != "":
			_play_action_whip(attacker_id)
		
		# Handle Damage
		if payload.has("damage_instances"):
			var instances = payload.get("damage_instances", [])
			if target:
				_spawn_damage_numbers(target_id, instances)
				_play_hit_shake(target_id)
			var total_instances = 0
			for hit in instances:
				total_instances += int(hit)
			pending_effect_messages.append("Damage: " + str(total_instances))
		elif payload.has("damage"):
			var dmg = payload["damage"]
			if target:
				_spawn_damage_numbers(target_id, [dmg])
				_play_hit_shake(target_id)
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
			_create_status_indicator(payload.get("attacker_id", payload.get("target_id", "")))
			pending_effect_messages.append("Buff: " + str(payload["buff"]))
		elif payload.has("debuff"):
			if target:
				_create_floating_text(target.position, "-" + str(payload["debuff"]), Color.ORANGE)
				_play_hit_shake(target_id)
			_create_status_indicator(payload.get("target_id", ""))
			pending_effect_messages.append("Debuff: " + str(payload["debuff"]))
		elif payload.has("stun_applied") and payload["stun_applied"]:
			if target:
				_create_floating_text(target.position, "STUNNED", Color.YELLOW)
				_play_hit_shake(target_id)
			_create_status_indicator(payload.get("target_id", ""))
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
		_apply_input_cooldown(250)
		battle_menu.set_enabled(true)
		battle_menu.setup(actor)
		_update_menu_disables(actor)
		target_cursor.deactivate()
		# Wait for signal
	else:
		state = "ENEMY_TURN"
		message_log("Enemy turn: " + actor.display_name)
		_apply_input_cooldown(250)
		battle_menu.set_enabled(false)
		target_cursor.deactivate()
		await _telegraph_enemy_intent(actor)
		_execute_enemy_turn(actor)

func _execute_enemy_turn(actor: Boss) -> void:
	# Use new AI Controller logic
	var ai_action = pending_enemy_action
	if ai_action.is_empty():
		ai_action = ai_controller.get_next_action(actor, battle_manager.battle_state)
	
	# Enqueue the AI-selected action directly
	if ai_action.is_empty():
		battle_manager.enqueue_action(ActionFactory.skip_turn(actor.id))
	else:
		battle_manager.enqueue_action(ai_action)
		
	pending_enemy_action = {}
	_execute_next_action()

func _telegraph_enemy_intent(actor: Boss) -> Signal:
	var ai_action = ai_controller.get_next_action(actor, battle_manager.battle_state)
	if ai_action.is_empty():
		return get_tree().create_timer(0.5).timeout
	pending_enemy_action = ai_action
	var text = battle_manager.format_action_declaration(actor.id, ai_action)
	_show_enemy_intent(text)
	return get_tree().create_timer(enemy_intent_duration).timeout

func _show_enemy_intent(text: String) -> void:
	if enemy_intent_label == null:
		return
	enemy_intent_label.text = text
	enemy_intent_label.visible = true
	var tween = create_tween()
	enemy_intent_label.modulate.a = 1.0
	tween.tween_interval(enemy_intent_duration)
	tween.tween_property(enemy_intent_label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func (): enemy_intent_label.visible = false)


func _on_menu_action_selected(action_id: String) -> void:
	if _is_input_cooldown_active():
		return
	_apply_input_cooldown(200)
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


func _get_target_node(actor_id: String) -> Node2D:
	var actor = battle_manager.get_actor_by_id(actor_id)
	if actor != null:
		return actor
	return null


func _get_sprite_anchor(actor_id: String) -> Vector2:
	if not actor_sprites.has(actor_id):
		return Vector2.ZERO
	var sprite = actor_sprites[actor_id]
	if sprite is Node2D:
		return sprite.global_position
	return Vector2.ZERO


func _create_status_indicator(actor_id: String) -> void:
	if actor_id == "":
		return
	var anchor = _get_sprite_anchor(actor_id)
	if anchor == Vector2.ZERO:
		var actor = _get_target_node(actor_id)
		if actor:
			anchor = actor.global_position
	if anchor != Vector2.ZERO:
		_create_floating_text(anchor, "STATUS", Color.SKY_BLUE)


func _update_menu_disables(actor: Character) -> void:
	var disabled: Dictionary = {}
	for item in battle_menu.menu_items:
		var id = item.get("id", "")
		if id == "ATTACK" or id == "SKILL_SUB" or id == "ITEM_SUB" or id == "META_SUB" or id == "DEFEND" or id == "GUARD_TOGGLE":
			if actor.id == "ludwig" and actor.has_status(StatusEffectIds.GUARD_STANCE) and id == "ATTACK":
				disabled[id] = "Guard Stance active."
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
		if actor.id == "ludwig" and actor.has_status(StatusEffectIds.GUARD_STANCE):
			if id in [ActionIds.LUD_LUNGING, ActionIds.LUD_PRECISION, ActionIds.LUD_SHIELD_BASH]:
				disabled[id] = "Guard Stance active."
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


func _setup_background() -> void:
	var bg_path = "res://assets/sprites/environment/env_sprite_dungeon_corridor.png"
	if not ResourceLoader.exists(bg_path):
		return
	var bg = Sprite2D.new()
	var tex = load(bg_path)
	bg.texture = tex
	bg.position = Vector2(0, 0)
	bg.centered = false
	# Background now matches viewport size (1152x648), so no scaling needed.
	bg.z_index = -10
	add_child(bg)


func _setup_game_ui() -> void:
	# Lower UI background
	var lower_ui_bg = ColorRect.new()
	lower_ui_bg.color = Color(0, 0, 0, 0.6)
	lower_ui_bg.position = Vector2(0, LOWER_UI_TOP - 24)
	lower_ui_bg.size = Vector2(1152, 176)
	lower_ui_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lower_ui_bg)

	# Party Status Panel (Bottom Right)
	var panel_bg = Panel.new()
	panel_bg.position = Vector2(620, LOWER_UI_TOP)
	panel_bg.size = Vector2(520, 140)
	add_child(panel_bg)
	
	party_status_panel = VBoxContainer.new()
	party_status_panel.position = Vector2(12, 12)
	party_status_panel.size = Vector2(496, 116)
	party_status_panel.add_theme_constant_override("separation", 6)
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
	combat_log_display.position = Vector2(200, 458)
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

	# Enemy Intent (Top Center)
	enemy_intent_label = Label.new()
	enemy_intent_label.position = Vector2(260, 74)
	enemy_intent_label.size = Vector2(640, 30)
	enemy_intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_intent_label.visible = false
	enemy_intent_label.modulate = Color(1, 0.9, 0.6)
	enemy_intent_bg = ColorRect.new()
	enemy_intent_bg.show_behind_parent = true
	enemy_intent_bg.color = Color(0, 0, 0, 0.55)
	enemy_intent_bg.anchor_right = 1.0
	enemy_intent_bg.anchor_bottom = 1.0
	enemy_intent_label.add_child(enemy_intent_bg)
	add_child(enemy_intent_label)
	
	# Boss HP (Below Boss)
	# Boss HP label is attached to boss in _make_boss()

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
		
		var active_id = battle_manager.battle_state.get("active_character_id", "")
		# Rebuild party list
		for actor in battle_manager.battle_state.party:
			var hbox = HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 12)
			hbox.alignment = BoxContainer.ALIGNMENT_CENTER
			var name_lbl = Label.new()
			name_lbl.text = actor.display_name
			name_lbl.custom_minimum_size = Vector2(96, 0)
			_apply_active_name_style(name_lbl, actor.id == active_id)
			
			var hp_container = Control.new()
			hp_container.custom_minimum_size = Vector2(150, 18)
			hp_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var hp_bar = ProgressBar.new()
			hp_bar.min_value = 0
			hp_bar.max_value = actor.stats["hp_max"]
			hp_bar.value = actor.hp_current
			hp_bar.show_percentage = false
			hp_bar.size = Vector2(150, 18)
			var hp_bg = StyleBoxFlat.new()
			hp_bg.bg_color = Color(0.1, 0.1, 0.1, 0.9)
			hp_bg.corner_radius_top_left = 8
			hp_bg.corner_radius_top_right = 8
			hp_bg.corner_radius_bottom_left = 8
			hp_bg.corner_radius_bottom_right = 8
			var hp_fill = StyleBoxFlat.new()
			hp_fill.bg_color = Color(0.2, 0.8, 0.2)
			hp_fill.corner_radius_top_left = 8
			hp_fill.corner_radius_top_right = 8
			hp_fill.corner_radius_bottom_left = 8
			hp_fill.corner_radius_bottom_right = 8
			hp_bar.add_theme_stylebox_override("background", hp_bg)
			hp_bar.add_theme_stylebox_override("fill", hp_fill)
			hp_bar.add_theme_stylebox_override("fg", hp_fill)
			var hp_text = RichTextLabel.new()
			hp_text.bbcode_enabled = true
			hp_text.scroll_active = false
			hp_text.fit_content = true
			hp_text.text = "[b]%d[/b][font_size=11]/%d[/font_size]" % [actor.hp_current, actor.stats["hp_max"]]
			hp_text.add_theme_font_size_override("normal_font_size", 13)
			hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			hp_text.anchor_right = 1.0
			hp_text.anchor_bottom = 1.0
			hp_text.offset_left = 0.0
			hp_text.offset_top = 0.0
			hp_text.offset_right = 0.0
			hp_text.offset_bottom = 0.0
			hp_bar.add_child(hp_text)
			hp_container.add_child(hp_bar)
			
			var mp_lbl = Label.new()
			if actor.stats["mp_max"] > 0:
				mp_lbl.text = "MP:%d/%d" % [actor.mp_current, actor.stats["mp_max"]]
			else:
				mp_lbl.text = ""
			mp_lbl.custom_minimum_size = Vector2(190, 0)
			
			# Append unique resources (short labels)
			if actor.resources.has("ki"):
				mp_lbl.text += " | Ki:%d" % actor.get_resource_current("ki")
			if actor.resources.has("superiority_dice"):
				mp_lbl.text += " | SD:%d" % actor.get_resource_current("superiority_dice")
			if actor.resources.has("bardic_inspiration"):
				mp_lbl.text += " | BI:%d" % actor.get_resource_current("bardic_inspiration")
			if actor.resources.has("sorcery_points"):
				mp_lbl.text += " | SP:%d" % actor.get_resource_current("sorcery_points")
			mp_lbl.text += " | LB"
			
			var lb_bar = ProgressBar.new()
			lb_bar.min_value = 0
			lb_bar.max_value = 100
			lb_bar.value = actor.limit_gauge
			lb_bar.custom_minimum_size = Vector2(110, 12)
			lb_bar.show_percentage = false
			var lb_bg = StyleBoxFlat.new()
			lb_bg.bg_color = Color(0.12, 0.12, 0.12, 0.9)
			lb_bg.corner_radius_top_left = 6
			lb_bg.corner_radius_top_right = 6
			lb_bg.corner_radius_bottom_left = 6
			lb_bg.corner_radius_bottom_right = 6
			var lb_fill = StyleBoxFlat.new()
			lb_fill.bg_color = Color(0.5, 0.5, 0.5)
			if actor.limit_gauge >= 100:
				lb_fill.bg_color = Color(0.2, 0.6, 1.0)
			lb_fill.corner_radius_top_left = 6
			lb_fill.corner_radius_top_right = 6
			lb_fill.corner_radius_bottom_left = 6
			lb_fill.corner_radius_bottom_right = 6
			lb_bar.add_theme_stylebox_override("background", lb_bg)
			lb_bar.add_theme_stylebox_override("fill", lb_fill)
			lb_bar.add_theme_stylebox_override("fg", lb_fill)
			var lb_text = Label.new()
			lb_text.text = "%d%%" % actor.limit_gauge
			lb_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lb_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lb_text.anchor_right = 1.0
			lb_text.anchor_bottom = 1.0
			lb_text.offset_left = 0.0
			lb_text.offset_top = 0.0
			lb_text.offset_right = 0.0
			lb_text.offset_bottom = 0.0
			lb_bar.add_child(lb_text)
			
			hbox.add_child(name_lbl)
			hbox.add_child(hp_container)
			hbox.add_child(mp_lbl)
			hbox.add_child(lb_bar)
			party_status_panel.add_child(hbox)

	# Update Boss Status (Simple Label above boss if exists or separate panel)
	# For simplicity, let's find the boss or use a dedicated Boss Label if we created one.
	# We didn't create a dedicated variable for boss UI yet, so let's add it dynamically or just rely on a new label.
	if boss_hp_bar:
		var enemies = battle_manager.get_alive_enemies()
		if enemies.size() > 0:
			var boss = enemies[0]
			boss_hp_bar.max_value = boss.stats["hp_max"]
			boss_hp_bar.value = boss.hp_current
			if boss_hp_bar_label:
				boss_hp_bar_label.text = "%d/%d" % [boss.hp_current, boss.stats["hp_max"]]
			_update_boss_hp_color(boss.hp_current, boss.stats["hp_max"])
		else:
			if boss_hp_bar_label:
				boss_hp_bar_label.text = "Victory?"
			
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

func _spawn_damage_numbers(target_id: String, damages: Array) -> void:
	var actor = battle_manager.get_actor_by_id(target_id)
	if actor == null:
		return
	for i in range(damages.size()):
		var dmg_val = int(damages[i])
		var delay = float(i) * 0.45
		var offset = Vector2(10 * i, -6 * i)
		var timer = get_tree().create_timer(delay)
		timer.timeout.connect(func ():
			_create_damage_text(actor.position + offset, str(dmg_val))
		)

func _create_damage_text(pos: Vector2, text: String) -> void:
	var label = Label.new()
	label.text = text
	label.modulate = Color(1.0, 0.55, 0.1)
	label.position = pos + Vector2(0, -64)
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 2)
	add_child(label)
	
	var tween = create_tween()
	tween.parallel().tween_property(label, "position:y", label.position.y - 50, 1.0)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)

func _update_active_idle_motion(active_id: String) -> void:
	for actor_id in actor_sprites.keys():
		if actor_id == active_id:
			_start_idle_wiggle(actor_id)
		else:
			_stop_idle_wiggle(actor_id)

func _start_idle_wiggle(actor_id: String) -> void:
	var sprite = actor_sprites.get(actor_id, null)
	if sprite == null:
		return
	if actor_idle_tweens.has(actor_id):
		var existing = actor_idle_tweens[actor_id]
		if existing:
			existing.kill()
	var base_pos = actor_base_positions.get(actor_id, Vector2.ZERO)
	sprite.position = base_pos
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(sprite, "position:x", base_pos.x + 3, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "position:x", base_pos.x - 3, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "position:x", base_pos.x, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	actor_idle_tweens[actor_id] = tween

func _stop_idle_wiggle(actor_id: String) -> void:
	if actor_idle_tweens.has(actor_id):
		var tween = actor_idle_tweens[actor_id]
		if tween:
			tween.kill()
		actor_idle_tweens.erase(actor_id)
	var sprite = actor_sprites.get(actor_id, null)
	if sprite == null:
		return
	var base_pos = actor_base_positions.get(actor_id, sprite.position)
	sprite.position = base_pos

func _play_action_whip(actor_id: String) -> void:
	var sprite = actor_sprites.get(actor_id, null)
	if sprite == null:
		return
	_stop_idle_wiggle(actor_id)
	if actor_action_tweens.has(actor_id):
		var existing = actor_action_tweens[actor_id]
		if existing:
			existing.kill()
	var base_pos = actor_base_positions.get(actor_id, sprite.position)
	var dir = 1.0
	if _is_party_member(actor_id):
		dir = -1.0
	var tween = create_tween()
	tween.tween_property(sprite, "position:x", base_pos.x + (dir * 10.0), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "position:x", base_pos.x, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	actor_action_tweens[actor_id] = tween
	_resume_idle_if_active(actor_id, 0.45)

func _play_hit_shake(actor_id: String) -> void:
	var sprite = actor_sprites.get(actor_id, null)
	if sprite == null:
		return
	_stop_idle_wiggle(actor_id)
	if actor_shake_tweens.has(actor_id):
		var existing = actor_shake_tweens[actor_id]
		if existing:
			existing.kill()
	var base_pos = actor_base_positions.get(actor_id, sprite.position)
	var tween = create_tween()
	tween.tween_property(sprite, "position:x", base_pos.x + 5, 0.04)
	tween.tween_property(sprite, "position:x", base_pos.x - 5, 0.04)
	tween.tween_property(sprite, "position:x", base_pos.x + 3, 0.04)
	tween.tween_property(sprite, "position:x", base_pos.x, 0.05)
	actor_shake_tweens[actor_id] = tween
	_resume_idle_if_active(actor_id, 0.6)

func _resume_idle_if_active(actor_id: String, delay: float) -> void:
	var timer = get_tree().create_timer(delay)
	timer.timeout.connect(func ():
		if battle_manager.battle_state.get("active_character_id", "") == actor_id:
			_start_idle_wiggle(actor_id)
	)

func _start_global_idle_all() -> void:
	for actor_id in actor_nodes.keys():
		_start_global_idle(actor_id)

func _start_global_idle(actor_id: String) -> void:
	var actor = actor_nodes.get(actor_id, null)
	if actor == null:
		return
	if actor_global_idle_tokens.has(actor_id):
		actor_global_idle_tokens[actor_id] += 1
	else:
		actor_global_idle_tokens[actor_id] = 1
	var token = actor_global_idle_tokens[actor_id]
	var base_pos = actor_root_positions.get(actor_id, actor.position)
	actor.position = base_pos
	var phase_seed = abs(hash(actor_id)) % 100
	var delay = float(phase_seed) / 100.0 * 1.2
	var timer = get_tree().create_timer(delay)
	timer.timeout.connect(func ():
		_global_idle_tick(actor_id, base_pos, token, true)
	)

func _global_idle_tick(actor_id: String, base_pos: Vector2, token: int, to_right: bool) -> void:
	if actor_global_idle_tokens.get(actor_id, 0) != token:
		return
	var actor = actor_nodes.get(actor_id, null)
	if actor == null:
		return
	actor.position = base_pos + Vector2(1 if to_right else -1, 0)
	var timer = get_tree().create_timer(1.2)
	timer.timeout.connect(func ():
		_global_idle_tick(actor_id, base_pos, token, not to_right)
	)

func _apply_active_name_style(label: Label, is_active: bool) -> void:
	if is_active:
		label.modulate = ACTIVE_NAME_COLOR
		label.add_theme_font_size_override("font_size", ACTIVE_NAME_FONT_SIZE)
	else:
		label.modulate = INACTIVE_NAME_COLOR
		label.add_theme_font_size_override("font_size", INACTIVE_NAME_FONT_SIZE)

func _update_active_character_highlight(active_id: String) -> void:
	for actor_id in actor_name_labels.keys():
		var lbl = actor_name_labels[actor_id]
		if lbl is Label:
			_apply_active_name_style(lbl, actor_id == active_id)

func _apply_input_cooldown(ms: int) -> void:
	input_cooldown_until_ms = Time.get_ticks_msec() + ms

func _is_input_cooldown_active() -> bool:
	return Time.get_ticks_msec() < input_cooldown_until_ms

func _update_boss_hp_color(current_hp: int, max_hp: int) -> void:
	if boss_hp_fill_style == null:
		return
	var ratio := 0.0
	if max_hp > 0:
		ratio = float(current_hp) / float(max_hp)
	if ratio <= 0.25:
		boss_hp_fill_style.bg_color = Color(0.85, 0.2, 0.2)
	elif ratio <= 0.5:
		boss_hp_fill_style.bg_color = Color(0.95, 0.65, 0.15)
	else:
		boss_hp_fill_style.bg_color = Color(0.2, 0.8, 0.2)
