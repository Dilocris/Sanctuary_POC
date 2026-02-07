extends RefCounted
class_name BattleUIManager

## BattleUIManager - Manages all UI panels, displays, and overlays for battle
## Extracted from battle_scene.gd for single-responsibility design

const AnimatedHealthBarClass = preload("res://scripts/ui/animated_health_bar.gd")
const ResourceDotGridClass = preload("res://scripts/ui/resource_dot_grid.gd")

# Pixel font (loaded once, applied to UI elements)
var _pixel_font: Font
var _pixel_font_bold: Font

func _load_pixel_fonts() -> void:
	if ResourceLoader.exists("res://assets/fonts/Silkscreen-Regular.ttf"):
		_pixel_font = load("res://assets/fonts/Silkscreen-Regular.ttf")
	if ResourceLoader.exists("res://assets/fonts/Silkscreen-Bold.ttf"):
		_pixel_font_bold = load("res://assets/fonts/Silkscreen-Bold.ttf")


## Apply pixel font to a Label if loaded.
func _apply_pixel_font(label: Label, bold: bool = false) -> void:
	var f = _pixel_font_bold if bold else _pixel_font
	if f:
		label.add_theme_font_override("font", f)

signal phase_overlay_finished
signal limit_overlay_finished

# External references
var _scene_root: Node
var _battle_manager: BattleManager

# UI Constants - Moved lower UI closer to bottom edge
const LOWER_UI_TOP := 492
const PANEL_PADDING := 8
const ROW_SPACING := 2
const COLUMN_SPACING := 8
const ACTIVE_NAME_COLOR := Color(1.0, 0.9, 0.4)
const INACTIVE_NAME_COLOR := Color(0.9, 0.9, 0.9)
const ACTIVE_NAME_FONT_SIZE := 14
const INACTIVE_NAME_FONT_SIZE := 12
const HP_BAR_HEIGHT := 20
const MP_BAR_HEIGHT := 14
const BAR_WIDTH := 130
const NAME_WIDTH := 62
const MP_COLOR := Color(0.25, 0.45, 0.85)

# Fixed column layout positions (within party panel inner area)
const COL_NAME_X := 4
const COL_SEP1_X := 68
const COL_BARS_X := 72
const COL_SEP2_X := 206
const COL_RES_X := 210
const COL_RES_W := 78     # 8 cols * (8+2) - 2 = 78
const COL_SEP3_X := 292
const COL_LB_X := 296
const COL_LB_BAR_X := 316 # After "LB" label
const COL_LB_BAR_W := 64
const SEP_COLOR := Color(0.35, 0.35, 0.4, 0.4)
const ROW_HEIGHT := 35

# UI Elements
var debug_panel: Control
var debug_log: RichTextLabel
var debug_toggle_btn: Button
var party_status_panel: Control
var status_effects_display: Label
var turn_order_display: Label
var combat_log_display: Label
var enemy_intent_label: Label
var enemy_intent_bg: ColorRect
var phase_overlay: ColorRect
var phase_label: Label
var limit_overlay: ColorRect
var limit_label: Label
var boss_hp_bar: AnimatedHealthBar
var battle_log_panel: RichTextLabel

# Persistent party UI elements (for animation support)
var _party_hp_bars: Dictionary = {}       # actor_id -> AnimatedHealthBar
var _party_mp_bars: Dictionary = {}       # actor_id -> AnimatedHealthBar (blue)
var _party_name_labels: Dictionary = {}   # actor_id -> Label
var _party_resource_grids: Dictionary = {} # actor_id -> ResourceDotGrid
var _party_lb_bars: Dictionary = {}       # actor_id -> ProgressBar
var _party_lb_texts: Dictionary = {}      # actor_id -> Label
var _party_lb_fills: Dictionary = {}      # actor_id -> StyleBoxFlat
var _party_lb_tweens: Dictionary = {}    # actor_id -> Tween (pulse when full)
var _party_row_highlights: Dictionary = {} # actor_id -> ColorRect (active row bg)
var _party_ui_initialized: bool = false

# State
var last_logged_turn_id: String = ""
var pending_damage_messages: Array = []
var pending_status_messages: Array = []
var enemy_intent_duration: float = 2.0


func setup(scene_root: Node, battle_manager: BattleManager, intent_duration: float = 2.0) -> void:
	_scene_root = scene_root
	_battle_manager = battle_manager
	enemy_intent_duration = intent_duration
	_load_pixel_fonts()


# ============================================================================
# UI CREATION
# ============================================================================

func create_debug_ui() -> void:
	debug_panel = Control.new()
	debug_panel.name = "DebugPanel"
	debug_panel.visible = false
	_scene_root.add_child(debug_panel)

	debug_log = RichTextLabel.new()
	debug_log.name = "DebugLog"
	debug_log.position = Vector2(0, 0)
	debug_log.size = Vector2(400, 200)
	debug_panel.add_child(debug_log)

	debug_toggle_btn = Button.new()
	debug_toggle_btn.text = "Debug"
	debug_toggle_btn.position = Vector2(10, 10)
	debug_toggle_btn.pressed.connect(func(): debug_panel.visible = !debug_panel.visible)
	_scene_root.add_child(debug_toggle_btn)


func create_game_ui() -> void:
	# Lower UI background - closer to bottom edge
	var lower_ui_bg = ColorRect.new()
	lower_ui_bg.color = Color(0, 0, 0, 0.7)
	lower_ui_bg.position = Vector2(0, LOWER_UI_TOP - 8)
	lower_ui_bg.size = Vector2(1152, 648 - LOWER_UI_TOP + 8)
	lower_ui_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene_root.add_child(lower_ui_bg)

	# Party Status Panel (Bottom Right) - tighter layout
	var panel_height = 648 - LOWER_UI_TOP
	var panel_bg = Panel.new()
	panel_bg.position = Vector2(580, LOWER_UI_TOP)
	panel_bg.size = Vector2(560, panel_height)
	_scene_root.add_child(panel_bg)

	party_status_panel = Control.new()
	party_status_panel.position = Vector2(PANEL_PADDING, PANEL_PADDING)
	party_status_panel.size = Vector2(544, panel_height - PANEL_PADDING * 2)
	panel_bg.add_child(party_status_panel)

	# Turn Order Display (Top Center)
	turn_order_display = Label.new()
	turn_order_display.position = Vector2(350, 10)
	turn_order_display.size = Vector2(400, 30)
	turn_order_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_pixel_font(turn_order_display)
	_scene_root.add_child(turn_order_display)

	# Status Effects Display (Centered below Turn Order)
	status_effects_display = Label.new()
	status_effects_display.position = Vector2(350, 40)
	status_effects_display.size = Vector2(400, 30)
	status_effects_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_pixel_font(status_effects_display)
	_scene_root.add_child(status_effects_display)

	# Combat Log Toast (Above Bottom UI)
	combat_log_display = Label.new()
	combat_log_display.position = Vector2(200, 458)
	combat_log_display.size = Vector2(700, 30)
	combat_log_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combat_log_display.text = "Battle Start!"
	_apply_pixel_font(combat_log_display)

	var bg = ColorRect.new()
	bg.show_behind_parent = true
	bg.color = Color(0, 0, 0, 0.5)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	combat_log_display.add_child(bg)
	_scene_root.add_child(combat_log_display)

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
	_apply_pixel_font(enemy_intent_label)
	enemy_intent_label.add_child(enemy_intent_bg)
	_scene_root.add_child(enemy_intent_label)

	# Phase Overlay
	phase_overlay = ColorRect.new()
	phase_overlay.color = Color(0.2, 0.0, 0.2, 0.65)
	phase_overlay.position = Vector2(0, 0)
	phase_overlay.size = Vector2(1152, 648)
	phase_overlay.visible = false
	phase_overlay.z_index = 100
	_scene_root.add_child(phase_overlay)
	phase_label = Label.new()
	phase_label.text = ""
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	phase_label.size = Vector2(1152, 648)
	phase_label.add_theme_font_size_override("font_size", 28)
	_apply_pixel_font(phase_label, true)
	phase_label.visible = false
	phase_label.z_index = 101
	_scene_root.add_child(phase_label)

	# Limit Overlay
	limit_overlay = ColorRect.new()
	limit_overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	limit_overlay.position = Vector2(0, 0)
	limit_overlay.size = Vector2(1152, 648)
	limit_overlay.visible = false
	limit_overlay.z_index = 110
	_scene_root.add_child(limit_overlay)
	limit_label = Label.new()
	limit_label.text = ""
	limit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	limit_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	limit_label.size = Vector2(1152, 648)
	limit_label.add_theme_font_size_override("font_size", 30)
	_apply_pixel_font(limit_label, true)
	limit_label.visible = false
	limit_label.z_index = 111
	_scene_root.add_child(limit_label)

	# Battle Log Panel (Left side)
	battle_log_panel = RichTextLabel.new()
	battle_log_panel.position = Vector2(10, 10)
	battle_log_panel.size = Vector2(320, 160)
	battle_log_panel.scroll_active = false
	battle_log_panel.scroll_following = true
	battle_log_panel.add_theme_font_size_override("normal_font_size", 12)
	if _pixel_font:
		battle_log_panel.add_theme_font_override("normal_font", _pixel_font)
	_scene_root.add_child(battle_log_panel)

	# F1 hint
	var f1_hint = Label.new()
	f1_hint.text = "F1: Settings"
	f1_hint.position = Vector2(1060, 632)
	f1_hint.add_theme_font_size_override("font_size", 10)
	f1_hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.6))
	_apply_pixel_font(f1_hint)
	_scene_root.add_child(f1_hint)


# ============================================================================
# UI UPDATES
# ============================================================================

func update_turn_order_visual() -> void:
	if not turn_order_display:
		return
	var order = _battle_manager.battle_state.get("turn_order", [])
	var active = _battle_manager.battle_state.get("active_character_id", "")
	if order.is_empty():
		return

	var display_order = []
	var start_index = order.find(active)
	if start_index == -1:
		display_order = order
	else:
		display_order = order.slice(start_index, order.size()) + order.slice(0, start_index)

	turn_order_display.text = "Turn Order: " + " > ".join(display_order)


func update_status_effects_text() -> void:
	var active_statuses = []
	for member in _battle_manager.battle_state.party:
		if member.status_effects.size() > 0:
			var effect_names = []
			for effect in member.status_effects:
				effect_names.append(effect.id)
			active_statuses.append(member.display_name + ": [" + ", ".join(effect_names) + "]")

	for enemy in _battle_manager.battle_state.enemies:
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


func update_party_status(apply_name_style_func: Callable) -> void:
	if party_status_panel == null:
		return

	var active_id = _battle_manager.battle_state.get("active_character_id", "")

	# First call: create persistent UI elements
	if not _party_ui_initialized:
		_create_party_ui()
		_party_ui_initialized = true

	# Update existing elements with current values
	for actor in _battle_manager.battle_state.party:
		var actor_id = actor.id

		# Update name label style (color only — no font size change to prevent overflow)
		if _party_name_labels.has(actor_id):
			var is_active = actor_id == active_id
			_party_name_labels[actor_id].modulate = ACTIVE_NAME_COLOR if is_active else INACTIVE_NAME_COLOR
		# Toggle row highlight
		if _party_row_highlights.has(actor_id):
			_party_row_highlights[actor_id].visible = actor_id == active_id

		# Update HP bar (animated)
		if _party_hp_bars.has(actor_id):
			_party_hp_bars[actor_id].set_hp(actor.hp_current, actor.stats["hp_max"])

		# Update MP bar (animated)
		if _party_mp_bars.has(actor_id) and actor.stats["mp_max"] > 0:
			_party_mp_bars[actor_id].set_hp(actor.mp_current, actor.stats["mp_max"])

		# Update resource grid
		if _party_resource_grids.has(actor_id):
			var grid = _party_resource_grids[actor_id]
			var res_val = _get_actor_resource_current(actor)
			grid.set_value(res_val)

		# Update LB bar + flash effect
		if _party_lb_bars.has(actor_id):
			_party_lb_bars[actor_id].value = actor.limit_gauge
			if _party_lb_texts.has(actor_id):
				_party_lb_texts[actor_id].text = "%d%%" % actor.limit_gauge
			if _party_lb_fills.has(actor_id):
				if actor.limit_gauge >= 100:
					_party_lb_fills[actor_id].bg_color = Color(0.2, 0.6, 1.0)
					_start_lb_pulse(actor_id)
				else:
					_party_lb_fills[actor_id].bg_color = Color(0.4, 0.4, 0.4)
					_stop_lb_pulse(actor_id)


## Get the current value of an actor's special resource.
func _get_actor_resource_current(actor) -> int:
	if actor.resources.has("ki"):
		return actor.get_resource_current("ki")
	if actor.resources.has("superiority_dice"):
		return actor.get_resource_current("superiority_dice")
	if actor.resources.has("bardic_inspiration"):
		return actor.get_resource_current("bardic_inspiration")
	if actor.resources.has("sorcery_points"):
		return actor.get_resource_current("sorcery_points")
	return 0


## Get the max value of an actor's special resource.
func _get_actor_resource_max(actor) -> int:
	if actor.resources.has("ki"):
		return actor.resources["ki"].get("max", 0)
	if actor.resources.has("superiority_dice"):
		return actor.resources["superiority_dice"].get("max", 0)
	if actor.resources.has("bardic_inspiration"):
		return actor.resources["bardic_inspiration"].get("max", 0)
	if actor.resources.has("sorcery_points"):
		return actor.resources["sorcery_points"].get("max", 0)
	return 0


## Creates the persistent party UI elements (called once).
## Uses fixed-position Control layout for consistent column alignment.
func _create_party_ui() -> void:
	# Clear any existing children
	for child in party_status_panel.get_children():
		child.queue_free()

	var active_id = _battle_manager.battle_state.get("active_character_id", "")

	# Draw column separators (span full panel height)
	var panel_h = party_status_panel.size.y
	var panel_w = party_status_panel.size.x
	for sep_x in [COL_SEP1_X, COL_SEP2_X, COL_SEP3_X]:
		var sep = ColorRect.new()
		sep.color = SEP_COLOR
		sep.position = Vector2(sep_x, 0)
		sep.size = Vector2(1, panel_h)
		sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		party_status_panel.add_child(sep)

	# Draw row separators between character lines
	var party_size = _battle_manager.battle_state.party.size()
	for i in range(1, party_size):
		var row_sep = ColorRect.new()
		row_sep.color = SEP_COLOR
		row_sep.position = Vector2(0, i * ROW_HEIGHT)
		row_sep.size = Vector2(panel_w, 1)
		row_sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		party_status_panel.add_child(row_sep)

	var row_idx := 0
	for actor in _battle_manager.battle_state.party:
		var actor_id = actor.id
		var row_y = row_idx * ROW_HEIGHT

		# --- Row highlight background (subtle tint for active character) ---
		var row_bg = ColorRect.new()
		row_bg.color = Color(1.0, 0.9, 0.4, 0.08)
		row_bg.position = Vector2(0, row_y)
		row_bg.size = Vector2(panel_w, ROW_HEIGHT)
		row_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_bg.visible = actor_id == active_id
		_party_row_highlights[actor_id] = row_bg
		party_status_panel.add_child(row_bg)

		# --- Name label (fixed column, no size scaling) ---
		var name_lbl = Label.new()
		name_lbl.text = actor.display_name
		name_lbl.position = Vector2(COL_NAME_X, row_y)
		name_lbl.size = Vector2(NAME_WIDTH, ROW_HEIGHT)
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", INACTIVE_NAME_FONT_SIZE)
		name_lbl.clip_text = true
		_apply_pixel_font(name_lbl)
		name_lbl.modulate = ACTIVE_NAME_COLOR if actor_id == active_id else INACTIVE_NAME_COLOR
		_party_name_labels[actor_id] = name_lbl
		party_status_panel.add_child(name_lbl)

		# --- HP/MP bars (fixed column) ---
		var hp_bar = AnimatedHealthBarClass.new()
		hp_bar.bar_size = Vector2(BAR_WIDTH, HP_BAR_HEIGHT)
		hp_bar.custom_minimum_size = Vector2(BAR_WIDTH, HP_BAR_HEIGHT)
		hp_bar.use_odometer = false
		hp_bar.corner_radius = 3
		hp_bar.custom_font = _pixel_font
		hp_bar.position = Vector2(COL_BARS_X, row_y)
		_party_hp_bars[actor_id] = hp_bar
		party_status_panel.add_child(hp_bar)

		if actor.stats["mp_max"] > 0:
			var mp_bar = AnimatedHealthBarClass.new()
			mp_bar.bar_size = Vector2(BAR_WIDTH, MP_BAR_HEIGHT)
			mp_bar.custom_minimum_size = Vector2(BAR_WIDTH, MP_BAR_HEIGHT)
			mp_bar.main_color = MP_COLOR
			mp_bar.use_odometer = false
			mp_bar.corner_radius = 2
			mp_bar.custom_font = _pixel_font
			mp_bar.position = Vector2(COL_BARS_X, row_y + HP_BAR_HEIGHT + 1)
			_party_mp_bars[actor_id] = mp_bar
			party_status_panel.add_child(mp_bar)

		# --- Resource dot grid (fixed column, 2 rows x 8 cols) ---
		var res_max = _get_actor_resource_max(actor)
		if res_max > 0:
			var res_grid = ResourceDotGridClass.new()
			res_grid.max_value = res_max
			res_grid.fixed_columns = 8
			res_grid.dot_size = 8
			res_grid.dot_spacing = 2
			res_grid.row_spacing = 2
			var grid_h = 2 * 8 + 1 * 2  # 18px
			res_grid.position = Vector2(COL_RES_X, row_y + int((ROW_HEIGHT - grid_h) / 2))
			_party_resource_grids[actor_id] = res_grid
			party_status_panel.add_child(res_grid)

		# --- LB section (fixed column, all aligned) ---
		var lb_label = Label.new()
		lb_label.text = "LB"
		lb_label.add_theme_font_size_override("font_size", 9)
		lb_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.8))
		lb_label.position = Vector2(COL_LB_X, row_y)
		lb_label.size = Vector2(18, ROW_HEIGHT)
		lb_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_apply_pixel_font(lb_label)
		party_status_panel.add_child(lb_label)

		var lb_bar = ProgressBar.new()
		lb_bar.min_value = 0
		lb_bar.max_value = 100
		lb_bar.value = actor.limit_gauge
		lb_bar.position = Vector2(COL_LB_BAR_X, row_y + int((ROW_HEIGHT - 14) / 2))
		lb_bar.size = Vector2(COL_LB_BAR_W, 14)
		lb_bar.custom_minimum_size = Vector2(COL_LB_BAR_W, 14)
		lb_bar.show_percentage = false

		var lb_bg = StyleBoxFlat.new()
		lb_bg.bg_color = Color(0.15, 0.15, 0.15, 0.9)
		lb_bg.set_corner_radius_all(4)

		var lb_fill = StyleBoxFlat.new()
		lb_fill.bg_color = Color(0.4, 0.4, 0.4)
		if actor.limit_gauge >= 100:
			lb_fill.bg_color = Color(0.2, 0.6, 1.0)
		lb_fill.set_corner_radius_all(4)

		lb_bar.add_theme_stylebox_override("background", lb_bg)
		lb_bar.add_theme_stylebox_override("fill", lb_fill)
		lb_bar.add_theme_stylebox_override("fg", lb_fill)
		_party_lb_bars[actor_id] = lb_bar
		_party_lb_fills[actor_id] = lb_fill

		var lb_text = Label.new()
		lb_text.text = "%d%%" % actor.limit_gauge
		lb_text.add_theme_font_size_override("font_size", 11)
		lb_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lb_text.set_anchors_preset(Control.PRESET_FULL_RECT)
		_apply_pixel_font(lb_text)
		lb_bar.add_child(lb_text)
		_party_lb_texts[actor_id] = lb_text

		party_status_panel.add_child(lb_bar)
		row_idx += 1

	# Initialize all bars with current values (no animation on first display)
	await _scene_root.get_tree().process_frame
	for actor in _battle_manager.battle_state.party:
		var actor_id = actor.id
		if _party_hp_bars.has(actor_id):
			_party_hp_bars[actor_id].initialize(actor.hp_current, actor.stats["hp_max"])
		if _party_mp_bars.has(actor_id):
			_party_mp_bars[actor_id].initialize(actor.mp_current, actor.stats["mp_max"])
		if _party_resource_grids.has(actor_id):
			var res_max = _get_actor_resource_max(actor)
			var res_cur = _get_actor_resource_current(actor)
			_party_resource_grids[actor_id].initialize(res_cur, res_max)


func update_boss_status() -> void:
	if boss_hp_bar == null:
		return
	var enemies = _battle_manager.get_alive_enemies()
	if enemies.size() > 0:
		var boss = enemies[0]
		boss_hp_bar.set_hp(boss.hp_current, boss.stats["hp_max"])


func update_battle_log() -> void:
	if battle_log_panel == null:
		return
	var lines = _battle_manager.battle_state.get("message_log", [])
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
	var turn_id = str(_battle_manager.battle_state.get("turn_count", 0)) + ":" + \
		str(_battle_manager.battle_state.get("active_character_id", ""))
	if turn_id == last_logged_turn_id:
		return ""
	last_logged_turn_id = turn_id
	return "---- Turn " + str(_battle_manager.battle_state.get("turn_count", 0)) + \
		" (" + str(_battle_manager.battle_state.get("active_character_id", "")) + ") ----"


func update_debug_log(text: String) -> void:
	if debug_log:
		debug_log.text = text


func show_combat_log_toast(msg: String) -> void:
	if combat_log_display:
		combat_log_display.text = msg
		var tween = _scene_root.create_tween()
		combat_log_display.modulate.a = 1.0
		tween.tween_interval(3.0)
		tween.tween_property(combat_log_display, "modulate:a", 0.0, 1.5)


# ============================================================================
# OVERLAYS
# ============================================================================

func show_enemy_intent(text: String) -> void:
	if enemy_intent_label == null:
		return
	enemy_intent_label.text = text
	enemy_intent_label.visible = true
	var tween = _scene_root.create_tween()
	enemy_intent_label.modulate.a = 1.0
	tween.tween_interval(enemy_intent_duration)
	tween.tween_property(enemy_intent_label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): enemy_intent_label.visible = false)


func show_phase_overlay(phase: int) -> void:
	var text = "PHASE " + str(phase)
	if phase == 2:
		text = "PHASE 2 - THE SYMBIOTE AWAKENS"
	elif phase == 3:
		text = "PHASE 3 - DESPERATION"
	if phase_label:
		phase_label.text = text
	if phase_overlay:
		phase_overlay.visible = true
	if phase_label:
		phase_label.visible = true
	var tween = _scene_root.create_tween()
	phase_overlay.modulate.a = 0.0
	phase_label.modulate.a = 0.0
	tween.tween_property(phase_overlay, "modulate:a", 1.0, 0.4)
	tween.tween_property(phase_label, "modulate:a", 1.0, 0.4)
	tween.tween_interval(1.6)
	tween.tween_property(phase_overlay, "modulate:a", 0.0, 0.5)
	tween.tween_property(phase_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func():
		if phase_overlay:
			phase_overlay.visible = false
		if phase_label:
			phase_label.visible = false
		emit_signal("phase_overlay_finished")
	)


func show_limit_overlay(action_id: String) -> void:
	var text = "LIMIT BREAK"
	var color = Color(1, 0.6, 0.2)
	match action_id:
		ActionIds.KAI_LIMIT:
			text = "INFERNO FIST"
			color = Color(1.0, 0.4, 0.2)
		ActionIds.LUD_LIMIT:
			text = "DRAGONFIRE ROAR"
			color = Color(1.0, 0.5, 0.1)
		ActionIds.NINOS_LIMIT:
			text = "SIREN'S CALL"
			color = Color(0.2, 0.7, 1.0)
		ActionIds.CAT_LIMIT:
			text = "GENIE'S WRATH"
			color = Color(1.0, 0.2, 0.8)
	if limit_label:
		limit_label.text = text
		limit_label.modulate = color
	if limit_overlay:
		limit_overlay.visible = true
	if limit_label:
		limit_label.visible = true
	var tween = _scene_root.create_tween()
	limit_overlay.modulate.a = 0.0
	limit_label.modulate.a = 0.0
	tween.tween_property(limit_overlay, "modulate:a", 0.8, 0.25)
	tween.tween_property(limit_label, "modulate:a", 1.0, 0.25)
	tween.tween_interval(0.6)
	tween.tween_property(limit_overlay, "modulate:a", 0.0, 0.35)
	tween.tween_property(limit_label, "modulate:a", 0.0, 0.35)
	tween.tween_callback(func():
		if limit_overlay:
			limit_overlay.visible = false
		if limit_label:
			limit_label.visible = false
		emit_signal("limit_overlay_finished")
	)


# ============================================================================
# BOSS HP BAR (Set externally when boss is created)
# ============================================================================

func set_boss_hp_bar(bar: AnimatedHealthBar) -> void:
	boss_hp_bar = bar


# ============================================================================
# LB BAR PULSE EFFECT
# ============================================================================

func _start_lb_pulse(actor_id: String) -> void:
	if _party_lb_tweens.has(actor_id):
		return  # Already pulsing
	if not _party_lb_fills.has(actor_id):
		return
	var fill = _party_lb_fills[actor_id]
	var tween = _scene_root.create_tween().set_loops()
	tween.tween_method(func(t: float):
		fill.bg_color = Color(0.2, 0.6, 1.0).lerp(Color(0.5, 0.85, 1.0), t)
	, 0.0, 1.0, 0.5).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(t: float):
		fill.bg_color = Color(0.5, 0.85, 1.0).lerp(Color(0.2, 0.6, 1.0), t)
	, 0.0, 1.0, 0.5).set_ease(Tween.EASE_IN_OUT)
	_party_lb_tweens[actor_id] = tween


func _stop_lb_pulse(actor_id: String) -> void:
	if not _party_lb_tweens.has(actor_id):
		return
	var tween = _party_lb_tweens[actor_id]
	if tween and tween.is_valid():
		tween.kill()
	_party_lb_tweens.erase(actor_id)
