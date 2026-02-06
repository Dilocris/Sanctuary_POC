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
var phase_overlay: ColorRect
var phase_label: Label
var limit_overlay: ColorRect
var limit_label: Label
var boss_hp_bar: AnimatedHealthBar
var battle_log_panel: RichTextLabel
var demo_running: bool = false
var pending_effect_messages: Array = []
var pending_damage_messages: Array = []
var pending_status_messages: Array = []
var last_logged_turn_id: String = ""
var actor_sprites: Dictionary = {}
var actor_name_labels: Dictionary = {}
var input_cooldown_until_ms: int = 0
var actor_base_positions: Dictionary = {}
var actor_base_modulates: Dictionary = {}
var actor_base_self_modulates: Dictionary = {}
var actor_nodes: Dictionary = {}
var actor_root_positions: Dictionary = {}

var battle_menu: BattleMenu
var target_cursor: Node2D
var state = "BATTLE_START" # BATTLE_START, PLAYER_TURN, ENEMY_TURN, BATTLE_END
var active_player_id = ""
var battle_over: bool = false
var pending_enemy_action: Dictionary = {}
var input_locked: bool = false
const LOWER_UI_TOP := 492
@export var enemy_intent_duration := 2.0

const BattleMenuScene = preload("res://scenes/ui/battle_menu.tscn")
const TargetCursorScene = preload("res://scenes/ui/target_cursor.tscn")
const SettingsMenuClass = preload("res://scripts/ui/settings_menu.gd")
const ActorDataScript = preload("res://scripts/resources/actor_data.gd")
const DataCloneUtil = preload("res://scripts/utils/data_clone.gd")
const ACTOR_DATA_PATHS := [
	"res://data/actors/kairus.tres",
	"res://data/actors/ludwig.tres",
	"res://data/actors/ninos.tres",
	"res://data/actors/catraca.tres"
]
const BOSS_DATA_PATHS := [
	"res://data/actors/marcus_gelt.tres"
]

const LEGACY_PARTY_DATA := [
	{
		"id": "kairus",
		"display_name": "Kairus",
		"stats": {"hp_max": 450, "mp_max": 60, "atk": 62, "def": 42, "mag": 28, "spd": 55},
		"resources": {"ki": {"current": 6, "max": 6}},
		"position": BattleRenderer.HERO_POSITIONS.kairus,
		"color": Color(0.5, 0, 0.5)
	},
	{
		"id": "ludwig",
		"display_name": "Ludwig",
		"stats": {"hp_max": 580, "mp_max": 40, "atk": 58, "def": 65, "mag": 22, "spd": 34},
		"resources": {"superiority_dice": {"current": 4, "max": 4}},
		"position": BattleRenderer.HERO_POSITIONS.ludwig,
		"color": Color.GRAY
	},
	{
		"id": "ninos",
		"display_name": "Ninos",
		"stats": {"hp_max": 420, "mp_max": 110, "atk": 38, "def": 35, "mag": 52, "spd": 42},
		"resources": {"bardic_inspiration": {"current": 4, "max": 4}},
		"position": BattleRenderer.HERO_POSITIONS.ninos,
		"color": Color.GREEN
	},
	{
		"id": "catraca",
		"display_name": "Catraca",
		"stats": {"hp_max": 360, "mp_max": 120, "atk": 30, "def": 32, "mag": 68, "spd": 40},
		"resources": {"sorcery_points": {"current": 5, "max": 5}},
		"position": BattleRenderer.HERO_POSITIONS.catraca,
		"color": Color.RED
	}
]

const LEGACY_BOSS_DATA := [
	{
		"id": "marcus_gelt",
		"display_name": "Marcus Gelt",
		"stats": {"hp_max": 1200, "mp_max": 0, "atk": 75, "def": 55, "mag": 35, "spd": 38},
		"phase": 1,
		"position": BattleRenderer.BOSS_POSITION,
		"color": Color.BLACK,
		"is_boss": true
	}
]

var ai_controller: AiController
var animation_controller: BattleAnimationController
var ui_manager: BattleUIManager
var renderer: BattleRenderer
var game_feel_controller: GameFeelController
var settings_menu: Node  # SettingsMenuClass instance


func _ready() -> void:
	battle_manager = BattleManager.new()
	add_child(battle_manager)

	# Setup UI Manager
	ui_manager = BattleUIManager.new()
	ui_manager.setup(self, battle_manager, enemy_intent_duration)
	ui_manager.phase_overlay_finished.connect(_on_phase_overlay_finished)

	# Setup Debug UI
	ui_manager.create_debug_ui()
	debug_panel = ui_manager.debug_panel
	debug_log = ui_manager.debug_log
	debug_toggle_btn = ui_manager.debug_toggle_btn

	# Setup Game UI
	ui_manager.create_game_ui()
	party_status_panel = ui_manager.party_status_panel
	status_effects_display = ui_manager.status_effects_display
	turn_order_display = ui_manager.turn_order_display
	combat_log_display = ui_manager.combat_log_display
	enemy_intent_label = ui_manager.enemy_intent_label
	enemy_intent_bg = ui_manager.enemy_intent_bg
	phase_overlay = ui_manager.phase_overlay
	phase_label = ui_manager.phase_label
	limit_overlay = ui_manager.limit_overlay
	limit_label = ui_manager.limit_label
	battle_log_panel = ui_manager.battle_log_panel

	# Setup Renderer
	renderer = BattleRenderer.new()
	renderer.setup(self)
	renderer.create_background()

	# Setup Game Feel Controller
	game_feel_controller = GameFeelController.new()
	game_feel_controller.setup(self, battle_manager)

	# Instantiate UI
	battle_menu = BattleMenuScene.instantiate()
	add_child(battle_menu)
	battle_menu.action_selected.connect(_on_menu_action_selected)
	battle_menu.action_blocked.connect(_on_menu_action_blocked)
	battle_menu.menu_changed.connect(_on_menu_changed)

	target_cursor = TargetCursorScene.instantiate()
	add_child(target_cursor)
	target_cursor.target_selected.connect(_on_target_selected)
	target_cursor.selection_canceled.connect(_on_target_canceled)

	# Settings/Debug overlay (F1)
	settings_menu = SettingsMenuClass.new()
	settings_menu.setup(self, battle_manager, game_feel_controller, ui_manager)
	add_child(settings_menu)

	battle_manager.message_added.connect(_on_message_added)
	battle_manager.turn_order_updated.connect(_on_turn_order_updated)
	battle_manager.active_character_changed.connect(_on_active_character_changed)
	battle_manager.action_enqueued.connect(_on_action_enqueued)
	battle_manager.action_executed.connect(_on_action_executed)
	battle_manager.battle_ended.connect(_on_battle_ended)
	battle_manager.phase_changed.connect(_on_phase_changed)
	battle_manager.status_tick.connect(_on_status_tick)
	ai_controller = AiController.new()

	var party: Array = []
	for path in ACTOR_DATA_PATHS:
		var data = _load_actor_data(path)
		if data != null:
			var actor = _create_actor_from_data(data)
			if actor != null:
				party.append(actor)
		else:
			push_warning("Missing actor data resource: " + path)
	if party.is_empty():
		push_warning("Actor data not found. Falling back to legacy party data.")
		for entry in LEGACY_PARTY_DATA:
			party.append(_make_character(entry))

	var enemies: Array = []
	for path in BOSS_DATA_PATHS:
		var data = _load_actor_data(path)
		if data != null:
			var enemy = _create_actor_from_data(data)
			if enemy != null:
				enemies.append(enemy)
		else:
			push_warning("Missing boss data resource: " + path)
	if enemies.is_empty():
		push_warning("Boss data not found. Falling back to legacy boss data.")
		for entry in LEGACY_BOSS_DATA:
			enemies.append(_make_boss(entry))

	push_warning("Battle load complete. Party: " + str(party.size()) + " Enemies: " + str(enemies.size()))

	# Copy renderer dictionaries for backward compatibility
	actor_sprites = renderer.actor_sprites
	actor_nodes = renderer.actor_nodes
	actor_name_labels = renderer.actor_name_labels
	actor_base_positions = renderer.actor_base_positions
	actor_base_modulates = renderer.actor_base_modulates
	actor_base_self_modulates = renderer.actor_base_self_modulates
	actor_root_positions = renderer.actor_root_positions
	boss_hp_bar = renderer.boss_hp_bar
	ui_manager.set_boss_hp_bar(boss_hp_bar)

	# Setup animation controller with references
	animation_controller = BattleAnimationController.new()
	animation_controller.setup(
		self,
		battle_manager,
		actor_sprites,
		actor_base_positions,
		actor_base_modulates,
		actor_base_self_modulates,
		actor_nodes,
		actor_root_positions
	)

	battle_manager.setup_state(party, enemies)

	# Initialize boss HP bar with current values (no animation on first display)
	if boss_hp_bar:
		var alive_enemies = battle_manager.get_alive_enemies()
		if alive_enemies.size() > 0:
			var boss = alive_enemies[0]
			boss_hp_bar.initialize(boss.hp_current, boss.stats["hp_max"])

	# Populate debug tab now that party data exists
	if settings_menu:
		settings_menu.populate_debug_party()

	battle_manager.start_round()
	var order = _dict_get(battle_manager.battle_state, "turn_order", [])
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
	var character = renderer.create_character(data)
	var actor_id = _dict_get(data, "id", "")
	character.status_added.connect(func (status_id):
		_on_status_added(actor_id, status_id)
	)
	character.status_removed.connect(func (status_id):
		_on_status_removed(actor_id, status_id)
	)
	character.damage_taken.connect(func (amount):
		_flash_damage_tint(actor_id, amount)
	)
	return character


func _make_boss(data: Dictionary) -> Boss:
	var boss = renderer.create_boss(data)
	var actor_id = _dict_get(data, "id", "")
	boss.status_added.connect(func (status_id):
		_on_status_added(actor_id, status_id)
	)
	boss.status_removed.connect(func (status_id):
		_on_status_removed(actor_id, status_id)
	)
	boss.damage_taken.connect(func (amount):
		_flash_damage_tint(actor_id, amount)
	)
	return boss

# Missing Handlers Restored
func _on_message_added(text: String) -> void:
	if debug_log:
		debug_log.add_text(text + "\n")
	if combat_log_display:
		combat_log_display.text = text
	_update_battle_log()

func _on_turn_order_updated(order: Array) -> void:
	var _order = order
	# Update general status label if we want to track it
	_update_turn_order_visual()

func _on_active_character_changed(actor_id: String) -> void:
	_update_status_label(["Active Character: " + actor_id])
	_update_turn_order_visual()
	_update_active_character_highlight(actor_id)
	_update_active_idle_motion(actor_id)

func _update_turn_order_visual() -> void:
	ui_manager.update_turn_order_visual()



func _print_turn_order(_order: Array) -> void:
	# Debug function - prints disabled for production
	pass






func _on_action_enqueued(_action: Dictionary) -> void:
	# Action enqueued - visual feedback handled elsewhere
	pass


func _on_action_executed(result: Dictionary) -> void:
	var action_id = _dict_get(result, "action_id", "")
	if action_id in [ActionIds.KAI_LIMIT, ActionIds.LUD_LIMIT, ActionIds.NINOS_LIMIT, ActionIds.CAT_LIMIT]:
		_show_limit_overlay(action_id)
		game_feel_controller.on_limit_break()
	
	# Spawn Floating Text based on result
	if result.get("ok"):
		var payload = _dict_get(result, "payload", {})
		var target_id = _dict_get(payload, "target_id", "")
		var target = battle_manager.get_actor_by_id(target_id)
		var attacker_id = _dict_get(payload, "attacker_id", "")
		if attacker_id != "":
			_play_action_whip(attacker_id)
		
		# Handle Damage
		if payload.has("damage_instances"):
			var instances = _dict_get(payload, "damage_instances", [])
			if target:
				_spawn_damage_numbers(target_id, instances)
				_play_hit_shake(target_id)
				var total_dmg = 0
				for hit in instances:
					total_dmg += int(hit)
				var target_sprite = actor_sprites.get(target_id, null)
				game_feel_controller.on_damage_dealt(total_dmg, target_sprite)
				if target.is_ko():
					game_feel_controller.on_finishing_blow(target_sprite)
			var total_instances = 0
			for hit in instances:
				total_instances += int(hit)
			pending_damage_messages.append("Damage: " + str(total_instances))
		elif payload.has("damage"):
			var dmg = payload["damage"]
			if target:
				_spawn_damage_numbers(target_id, [dmg])
				_play_hit_shake(target_id)
				var target_sprite = actor_sprites.get(target_id, null)
				game_feel_controller.on_damage_dealt(dmg, target_sprite)
				if target.is_ko():
					game_feel_controller.on_finishing_blow(target_sprite)
			pending_damage_messages.append("Damage: " + str(dmg))
				
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
			_create_status_indicator(_dict_get(payload, "attacker_id", _dict_get(payload, "target_id", "")))
			pending_status_messages.append("Buff: " + str(payload["buff"]))
		elif payload.has("debuff"):
			if target:
				_create_floating_text(target.position, "-" + str(payload["debuff"]), Color.ORANGE)
				_play_hit_shake(target_id)
			_create_status_indicator(_dict_get(payload, "target_id", ""))
			pending_status_messages.append("Debuff: " + str(payload["debuff"]))
		elif payload.has("stun_applied") and payload["stun_applied"]:
			if target:
				_create_floating_text(target.position, "STUNNED", Color.YELLOW)
				_play_hit_shake(target_id)
			_create_status_indicator(_dict_get(payload, "target_id", ""))
			pending_status_messages.append("Status: STUN")
				
	# Pass to log logic...
	pass


func _on_battle_ended(result: String) -> void:
	battle_over = true
	_update_status_label(["Battle ended: " + result])
	# Clean up all tweens on battle end
	for actor_id in actor_sprites.keys():
		_cleanup_actor_tweens(actor_id)
	# Clean up game feel effects
	game_feel_controller.cleanup()

func _on_status_tick(actor_id: String, amount: int, kind: String) -> void:
	var actor = battle_manager.get_actor_by_id(actor_id)
	if actor == null:
		return
	if kind == "DOT":
		_create_status_tick_text(actor.position, str(amount), Color(0.6, 0.2, 0.9))
	elif kind == "HOT":
		_create_status_tick_text(actor.position, str(amount), Color(0.2, 0.8, 0.3))

func _on_phase_changed(phase: int) -> void:
	input_locked = true
	battle_menu.set_enabled(false)
	game_feel_controller.on_phase_transition()
	_show_phase_overlay(phase)

func _show_phase_overlay(phase: int) -> void:
	ui_manager.show_phase_overlay(phase)

func _on_phase_overlay_finished() -> void:
	if state == "PLAYER_TURN":
		input_locked = false
		var actor = battle_manager.get_actor_by_id(active_player_id)
		if actor:
			battle_menu.set_enabled(true)
			battle_menu.setup(actor)

func _show_limit_overlay(action_id: String) -> void:
	ui_manager.show_limit_overlay(action_id)







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
	if _dict_get(battle_manager.battle_state, "turn_order", []).is_empty():
		return

	var actor_id = _dict_get(battle_manager.battle_state, "active_character_id", "")
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
		input_locked = false
		battle_menu.set_enabled(true)
		battle_menu.setup(actor)
		_update_menu_disables(actor)
		target_cursor.deactivate()
		# Wait for signal
	else:
		state = "ENEMY_TURN"
		message_log("Enemy turn: " + actor.display_name)
		_apply_input_cooldown(250)
		input_locked = true
		battle_menu.set_enabled(false)
		target_cursor.deactivate()
		await _telegraph_enemy_intent(actor)
		_execute_enemy_turn(actor)

func _execute_enemy_turn(actor: Boss) -> void:
	# Skip turn if AI is disabled via debug menu
	if battle_manager.battle_state.flags.get("ai_disabled", false):
		battle_manager.enqueue_action(ActionFactory.skip_turn(actor.id))
		pending_enemy_action = {}
		_execute_next_action()
		return

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
	ui_manager.show_enemy_intent(text)


func _on_menu_action_selected(action_id: String) -> void:
	if _is_input_cooldown_active():
		return
	if input_locked:
		return
	input_locked = true
	_apply_input_cooldown(200)
	var is_metamagic = action_id == ActionIds.CAT_METAMAGIC_QUICKEN or action_id == ActionIds.CAT_METAMAGIC_TWIN
	if is_metamagic and action_id == ActionIds.CAT_METAMAGIC_TWIN and battle_manager.get_alive_enemies().size() < 2:
		message_log("Twin Spell requires 2+ enemies.")
		battle_menu.visible = true
		return
	battle_menu.visible = not is_metamagic
	var template_action = ActionFactory.create_action(action_id, active_player_id, [])
	var tags = _dict_get(template_action, "tags", [])
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
		var target_ids = []
		for t in target_pool:
			target_ids.append(t.id)
		_enqueue_and_execute(action_id, target_ids)
	elif target_mode == "DOUBLE":
		target_cursor.start_selection(target_pool, "DOUBLE")
		current_pending_action_id = action_id
	else:
		current_pending_action_id = action_id
		target_cursor.start_selection(target_pool, "SINGLE")


func _on_menu_action_blocked(reason: String) -> void:
	message_log(reason)
	input_locked = false
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
	input_locked = false
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


func _determine_target_pool(tags: Array, _action_id: String) -> Array:
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
		var id = _dict_get(item, "id", "")
		if id == "ATTACK" or id == "SKILL_SUB" or id == "ITEM_SUB" or id == "META_SUB" or id == "DEFEND" or id == "GUARD_TOGGLE":
			if actor.id == "ludwig" and actor.has_status(StatusEffectIds.GUARD_STANCE) and id == "ATTACK":
				disabled[id] = "Guard Stance active."
			continue
		var action = ActionFactory.create_action(id, actor.id, [])
		if _dict_get(action, "resource_type", "") != "":
			var cost = _dict_get(action, "resource_cost", 0)
			if actor.get_resource_current(action.resource_type) < cost:
				disabled[id] = "Not enough " + action.resource_type.capitalize() + "."
				continue
		var mp_cost = _dict_get(action, "mp_cost", 0)
		if mp_cost > 0 and actor.mp_current < mp_cost:
			disabled[id] = "Not enough MP."
			continue
		if id == ActionIds.CAT_METAMAGIC_QUICKEN and battle_manager.battle_state.flags.get("quicken_used_this_round", false):
			disabled[id] = "Already used this round."
			continue
		if id == ActionIds.CAT_METAMAGIC_TWIN and battle_manager.get_alive_enemies().size() < 2:
			disabled[id] = "Requires 2+ enemies."
			continue
		if actor.id == "ludwig" and actor.has_status(StatusEffectIds.GUARD_STANCE):
			if id in [ActionIds.LUD_LUNGING, ActionIds.LUD_PRECISION, ActionIds.LUD_SHIELD_BASH]:
				disabled[id] = "Guard Stance active."
				continue
		var tags = _dict_get(action, "tags", [])
		var pool = _determine_target_pool(tags, id)
		if not tags.has(ActionTags.SELF) and pool.is_empty():
			disabled[id] = "No valid targets."
			continue
	battle_menu.set_disabled_actions(disabled)

func _execute_next_action() -> void:
	var result = battle_manager.process_next_action()
	var payload = _dict_get(result, "payload", result)
	message_log("Action Result: " + str(payload))
	if _dict_get(result, "ok", false) == false:
		input_locked = false
	if _dict_get(payload, "metamagic", "") != "":
		var actor_meta = battle_manager.get_actor_by_id(active_player_id)
		if actor_meta:
			message_log("Metamagic set: " + str(_dict_get(payload, "metamagic", "")))
			input_locked = false
			battle_menu.visible = true
			battle_menu.open_magic_submenu()
			_update_menu_disables(actor_meta)
			return
	
	# End of turn cleanup
	var actor = battle_manager.get_actor_by_id(active_player_id)
	if actor and not _dict_get(payload, "quicken", false):
		battle_manager.process_end_of_turn_effects(actor)
	if _dict_get(payload, "quicken", false) and actor and actor.id == "catraca":
		message_log("Quicken: extra action!")
		input_locked = false
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


func _load_actor_data(path: String) -> Resource:
	var data = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if data == null:
		var abs_path = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(abs_path):
			push_warning("Actor data file exists but failed to load: " + path)
		return null
	if data.get_script() == ActorDataScript:
		return data
	var raw = DataCloneUtil.resource_to_dict(data)
	if _dict_get(raw, "id", "") != "":
		return data
	return null


func _actor_data_to_dict(data: Resource) -> Dictionary:
	var raw = DataCloneUtil.resource_to_dict(data)
	var position = _dict_get(raw, "position", Vector2.ZERO)
	if position == Vector2.ZERO:
		var data_id = _dict_get(raw, "id", "")
		if renderer.HERO_POSITIONS.has(data_id):
			position = renderer.HERO_POSITIONS[data_id]
		elif _dict_get(raw, "is_boss", false):
			position = renderer.BOSS_POSITION
	return {
		"id": _dict_get(raw, "id", ""),
		"display_name": _dict_get(raw, "display_name", ""),
		"stats": DataCloneUtil.dict(_dict_get(raw, "stats", {})),
		"resources": DataCloneUtil.dict(_dict_get(raw, "resources", {})),
		"position": position,
		"color": _dict_get(raw, "color", Color.WHITE),
		"phase": _dict_get(raw, "phase", 1)
	}


func _create_actor_from_data(data: Resource) -> Node:
	var dict = _actor_data_to_dict(data)
	if _dict_get(dict, "id", "") == "":
		return null
	var raw = DataCloneUtil.resource_to_dict(data)
	if _dict_get(raw, "is_boss", false):
		return _make_boss(dict)
	return _make_character(dict)


func _dict_get(dict: Dictionary, key: Variant, fallback: Variant) -> Variant:
	if dict.has(key):
		return dict[key]
	return fallback



func _update_status_label(lines: Array) -> void:
	# Update debug log
	var text = "\n".join(lines)
	if debug_log:
		debug_log.text = text

	# Delegate all UI updates to ui_manager (AnimatedHealthBar, ResourceDotGrid, etc.)
	ui_manager.update_party_status(_apply_active_name_style)
	ui_manager.update_boss_status()
	ui_manager.update_status_effects_text()


func _update_battle_log() -> void:
	if battle_log_panel == null:
		return
	var lines = _dict_get(battle_manager.battle_state, "message_log", [])
	var start = max(0, lines.size() - 6)
	var combined = lines.slice(start, lines.size())
	if pending_damage_messages.size() > 0:
		combined.append("Damage:")
		for msg in pending_damage_messages:
			combined.append("  " + msg)
		pending_damage_messages.clear()
	if pending_status_messages.size() > 0:
		combined.append("Status:")
		for msg in pending_status_messages:
			combined.append("  " + msg)
		pending_status_messages.clear()
	var turn_header = _get_turn_header()
	if not turn_header.is_empty():
		combined.append(turn_header)
	combined.append("---------------")
	battle_log_panel.text = "Log:\n" + "\n".join(combined)


func _get_turn_header() -> String:
	var turn_id = str(_dict_get(battle_manager.battle_state, "turn_count", 0)) + ":" + \
		str(_dict_get(battle_manager.battle_state, "active_character_id", ""))
	if turn_id == last_logged_turn_id:
		return ""
	last_logged_turn_id = turn_id
	return "---- Turn " + str(_dict_get(battle_manager.battle_state, "turn_count", 0)) + \
		" (" + str(_dict_get(battle_manager.battle_state, "active_character_id", "")) + ") ----"



func _create_floating_text(pos: Vector2, text: String, color: Color) -> void:
	animation_controller.create_floating_text(pos, text, color)

func _is_party_member(actor_id: String) -> bool:
	for member in battle_manager.battle_state.party:
		if member.id == actor_id:
			return true
	return false

func _spawn_damage_numbers(target_id: String, damages: Array) -> void:
	animation_controller.spawn_damage_numbers(target_id, damages)

func _create_damage_text(pos: Vector2, text: String) -> void:
	animation_controller.create_damage_text(pos, text)

func _create_status_tick_text(pos: Vector2, text: String, color: Color) -> void:
	animation_controller.create_status_tick_text(pos, text, color)

func _update_active_idle_motion(active_id: String) -> void:
	animation_controller.update_active_idle_motion(active_id)

func _start_idle_wiggle(actor_id: String) -> void:
	animation_controller.start_idle_wiggle(actor_id)

func _stop_idle_wiggle(actor_id: String) -> void:
	animation_controller.stop_idle_wiggle(actor_id)

func _play_action_whip(actor_id: String) -> void:
	animation_controller.play_action_whip(actor_id, _is_party_member(actor_id))

func _play_hit_shake(actor_id: String) -> void:
	animation_controller.play_hit_shake(actor_id)

func _start_global_idle_all() -> void:
	animation_controller.start_global_idle_all()

func _apply_active_name_style(label: Label, is_active: bool) -> void:
	renderer.apply_name_style(label, is_active)

func _update_active_character_highlight(active_id: String) -> void:
	for actor_id in actor_name_labels.keys():
		var lbl = actor_name_labels[actor_id]
		if lbl is Label:
			_apply_active_name_style(lbl, actor_id == active_id)

func _apply_input_cooldown(ms: int) -> void:
	input_cooldown_until_ms = Time.get_ticks_msec() + ms

func _is_input_cooldown_active() -> bool:
	return Time.get_ticks_msec() < input_cooldown_until_ms


func _on_status_added(actor_id: String, status_id: String) -> void:
	if status_id == StatusEffectIds.POISON:
		_start_poison_tint(actor_id)
	ui_manager.update_status_effects_text()

func _on_status_removed(actor_id: String, status_id: String) -> void:
	if status_id == StatusEffectIds.POISON:
		_stop_poison_tint(actor_id)
	ui_manager.update_status_effects_text()

func _start_poison_tint(actor_id: String) -> void:
	animation_controller.start_poison_tint(actor_id)

func _stop_poison_tint(actor_id: String) -> void:
	animation_controller.stop_poison_tint(actor_id)

func _flash_damage_tint(actor_id: String, _amount: int) -> void:
	animation_controller.flash_damage_tint(actor_id)

func _cleanup_actor_tweens(actor_id: String) -> void:
	animation_controller.cleanup_actor_tweens(actor_id)
