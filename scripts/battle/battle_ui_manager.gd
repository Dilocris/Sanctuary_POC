extends RefCounted
class_name BattleUIManager

## BattleUIManager - Manages all UI panels, displays, and overlays for battle
## Extracted from battle_scene.gd for single-responsibility design

const AnimatedHealthBarClass = preload("res://scripts/ui/animated_health_bar.gd")
const ResourceDotGridClass = preload("res://scripts/ui/resource_dot_grid.gd")
const UI_SKIN_ROOT := "res://assets/ui/battle_skin/"

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


func _load_skin() -> void:
	_skin_panel_bottom = _load_skin_tex("panel_bottom_9slice.png")
	_skin_panel_party = _load_skin_tex("panel_party_9slice.png")
	_skin_top_turn = _load_skin_tex("top_turn_order_9slice.png")
	_skin_top_status = _load_skin_tex("top_status_9slice.png")
	_skin_turn_plaque = _load_skin_tex("turn_center_plaque_9slice.png")
	_skin_menu_row_idle = _load_skin_tex("menu_row_idle_9slice.png")
	_skin_menu_row_selected = _load_skin_tex("menu_row_selected_9slice.png")
	_skin_lb_box = _load_skin_tex("lb_box_9slice.png")
	_skin_bar_bg = _load_skin_tex("bar_bg_9slice.png")
	_skin_pip_full = _load_skin_tex("pip_full.png")
	_skin_pip_empty = _load_skin_tex("pip_empty.png")
	_skin_divider_h = _load_skin_tex("divider_h.png")
	_skin_divider_v = _load_skin_tex("divider_v.png")
	_skin_ornament_tl = _load_skin_tex("ornament_corner_tl.png")
	_skin_ornament_tr = _load_skin_tex("ornament_corner_tr.png")
	_skin_ornament_bl = _load_skin_tex("ornament_corner_bl.png")
	_skin_ornament_br = _load_skin_tex("ornament_corner_br.png")


func _load_skin_tex(file_name: String) -> Texture2D:
	var path = UI_SKIN_ROOT + file_name
	if ResourceLoader.exists(path):
		return load(path)
	return null


func _make_skin_style(texture: Texture2D, margin: int = 8, content: int = 6, draw_center: bool = true) -> StyleBox:
	if texture == null:
		var fallback = StyleBoxFlat.new()
		fallback.bg_color = Color(0.06, 0.09, 0.15, 0.88)
		fallback.border_color = Color(0.66, 0.56, 0.36, 0.9)
		fallback.border_width_left = 2
		fallback.border_width_top = 2
		fallback.border_width_right = 2
		fallback.border_width_bottom = 2
		return fallback
	var style = StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = margin
	style.texture_margin_top = margin
	style.texture_margin_right = margin
	style.texture_margin_bottom = margin
	style.content_margin_left = content
	style.content_margin_top = content
	style.content_margin_right = content
	style.content_margin_bottom = content
	style.draw_center = draw_center
	return style


func _add_corner_ornaments(target: Control, prefix: String, tint: Color = Color(0.86, 0.8, 0.66, 0.5), ornament_size: int = 12) -> void:
	if target == null:
		return
	var textures := [_skin_ornament_tl, _skin_ornament_tr, _skin_ornament_bl, _skin_ornament_br]
	var suffixes := ["TL", "TR", "BL", "BR"]
	for i in range(4):
		var node_name = "SkinOrnament%s%s" % [prefix, suffixes[i]]
		var existing = target.get_node_or_null(node_name)
		if existing:
			existing.queue_free()
		if textures[i] == null:
			continue
		var ornament = TextureRect.new()
		ornament.name = node_name
		ornament.texture = textures[i]
		ornament.stretch_mode = TextureRect.STRETCH_SCALE
		ornament.size = Vector2(ornament_size, ornament_size)
		ornament.custom_minimum_size = Vector2(ornament_size, ornament_size)
		ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ornament.modulate = tint
		ornament.z_index = 5
		match i:
			0:
				ornament.position = Vector2(1, 1)
			1:
				ornament.anchor_left = 1.0
				ornament.anchor_right = 1.0
				ornament.position = Vector2(float(-ornament_size - 1), 1)
			2:
				ornament.anchor_top = 1.0
				ornament.anchor_bottom = 1.0
				ornament.position = Vector2(1, float(-ornament_size - 1))
			3:
				ornament.anchor_left = 1.0
				ornament.anchor_right = 1.0
				ornament.anchor_top = 1.0
				ornament.anchor_bottom = 1.0
				ornament.position = Vector2(float(-ornament_size - 1), float(-ornament_size - 1))
		target.add_child(ornament)

signal phase_overlay_finished
signal limit_overlay_finished

# External references
var _scene_root: Node
var _battle_manager: BattleManager

# UI Constants - Moved lower UI closer to bottom edge
const LOWER_UI_TOP := 492
const PANEL_PADDING := 4
const ROW_SPACING := 2
const COLUMN_SPACING := 8
const ACTIVE_NAME_COLOR := Color(1.0, 0.9, 0.4)
const INACTIVE_NAME_COLOR := Color(0.9, 0.9, 0.9)
const ACTIVE_NAME_FONT_SIZE := 14
const INACTIVE_NAME_FONT_SIZE := 13
const HP_BAR_HEIGHT := 14
const MP_BAR_HEIGHT := 10
const BAR_WIDTH := 156
const NAME_WIDTH := 80
const MP_COLOR := Color(0.25, 0.45, 0.85)

# Fixed column layout positions (within party panel inner area)
const COL_NAME_X := 8
const COL_SEP1_X := 90
const COL_BARS_X := 96
const COL_SEP2_X := 254
const COL_RES_X := 260
const COL_SEP3_X := 324
const COL_LB_X := 326
const COL_LB_VALUE_X := 370
const LB_VALUE_BOX_W := 52
const COL_STATUS_X := 430
const STATUS_ICON_SIZE := 14
const STATUS_ICON_GAP := 3
const SEP_COLOR := Color(0.35, 0.35, 0.4, 0.4)
const ROW_HEIGHT := 34
const TOP_HUD_X := 24
const TOP_HUD_W := 1104
const ACRONYM_WORDS := {
	"atk": "ATK",
	"def": "DEF",
	"hp": "HP",
	"mp": "MP",
	"lb": "LB"
}

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
var f1_hint_label: Label
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
var _party_status_icon_rows: Dictionary = {} # actor_id -> HBoxContainer
var _party_ui_initialized: bool = false

# State
var last_logged_turn_id: String = ""
var pending_damage_messages: Array = []
var pending_status_messages: Array = []
var enemy_intent_duration: float = 2.0

# Skin textures
var _skin_panel_bottom: Texture2D
var _skin_panel_party: Texture2D
var _skin_top_turn: Texture2D
var _skin_top_status: Texture2D
var _skin_turn_plaque: Texture2D
var _skin_menu_row_idle: Texture2D
var _skin_menu_row_selected: Texture2D
var _skin_lb_box: Texture2D
var _skin_bar_bg: Texture2D
var _skin_pip_full: Texture2D
var _skin_pip_empty: Texture2D
var _skin_divider_h: Texture2D
var _skin_divider_v: Texture2D
var _skin_ornament_tl: Texture2D
var _skin_ornament_tr: Texture2D
var _skin_ornament_bl: Texture2D
var _skin_ornament_br: Texture2D


func setup(scene_root: Node, battle_manager: BattleManager, intent_duration: float = 2.0) -> void:
	_scene_root = scene_root
	_battle_manager = battle_manager
	enemy_intent_duration = intent_duration
	_load_pixel_fonts()
	_load_skin()


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
	var panel_height = 648 - LOWER_UI_TOP

	# Bottom HUD shell (ornate skin).
	var bottom_shell = Panel.new()
	bottom_shell.position = Vector2(0, 466)
	bottom_shell.size = Vector2(1152, 182)
	bottom_shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_shell.add_theme_stylebox_override("panel", _make_skin_style(_skin_panel_bottom, 9, 10))
	_scene_root.add_child(bottom_shell)
	_add_corner_ornaments(bottom_shell, "BottomShell", Color(0.82, 0.76, 0.62, 0.44), 12)

	# Party Status Panel (Bottom Right)
	var panel_bg = Panel.new()
	panel_bg.position = Vector2(576, LOWER_UI_TOP - 2)
	panel_bg.size = Vector2(568, panel_height + 2)
	panel_bg.add_theme_stylebox_override("panel", _make_skin_style(_skin_panel_party, 6, 6))
	_scene_root.add_child(panel_bg)
	_add_corner_ornaments(panel_bg, "PartyPanel", Color(0.83, 0.77, 0.63, 0.46), 11)

	party_status_panel = Control.new()
	party_status_panel.position = Vector2(PANEL_PADDING + 2, PANEL_PADDING + 2)
	party_status_panel.size = Vector2(panel_bg.size.x - PANEL_PADDING * 2, panel_height - PANEL_PADDING * 2)
	party_status_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel_bg.add_child(party_status_panel)

	# Top turn order panel.
	var top_turn_panel = Panel.new()
	top_turn_panel.position = Vector2(258, 6)
	top_turn_panel.size = Vector2(636, 34)
	top_turn_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_turn_panel.add_theme_stylebox_override("panel", _make_skin_style(_skin_top_turn, 12, 10))
	_scene_root.add_child(top_turn_panel)
	_add_corner_ornaments(top_turn_panel, "TopTurn", Color(0.9, 0.84, 0.7, 0.58), 10)

	# Turn order text.
	turn_order_display = Label.new()
	turn_order_display.position = Vector2(12, 6)
	turn_order_display.size = Vector2(top_turn_panel.size.x - 24, 22)
	turn_order_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_order_display.add_theme_font_size_override("font_size", 13)
	turn_order_display.add_theme_color_override("font_color", Color(0.96, 0.94, 0.85))
	turn_order_display.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	turn_order_display.add_theme_constant_override("outline_size", 2)
	turn_order_display.clip_text = true
	_apply_pixel_font(turn_order_display)
	top_turn_panel.add_child(turn_order_display)

	# Top status panel.
	var top_status_panel = Panel.new()
	top_status_panel.position = Vector2(332, 39)
	top_status_panel.size = Vector2(488, 28)
	top_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_status_panel.add_theme_stylebox_override("panel", _make_skin_style(_skin_top_status, 10, 7))
	_scene_root.add_child(top_status_panel)
	_add_corner_ornaments(top_status_panel, "TopStatus", Color(0.9, 0.84, 0.7, 0.56), 9)

	# Status text.
	status_effects_display = Label.new()
	status_effects_display.position = Vector2(10, 3)
	status_effects_display.size = Vector2(top_status_panel.size.x - 20, 22)
	status_effects_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_effects_display.add_theme_font_size_override("font_size", 12)
	status_effects_display.add_theme_color_override("font_color", Color(0.88, 0.9, 0.95))
	status_effects_display.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	status_effects_display.add_theme_constant_override("outline_size", 2)
	status_effects_display.clip_text = true
	_apply_pixel_font(status_effects_display)
	top_status_panel.add_child(status_effects_display)

	# Center turn plaque.
	var turn_plaque_panel = Panel.new()
	turn_plaque_panel.position = Vector2(432, 454)
	turn_plaque_panel.size = Vector2(288, 34)
	turn_plaque_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	turn_plaque_panel.add_theme_stylebox_override("panel", _make_skin_style(_skin_turn_plaque, 14, 9))
	_scene_root.add_child(turn_plaque_panel)
	_add_corner_ornaments(turn_plaque_panel, "TurnPlaque", Color(0.9, 0.84, 0.7, 0.58), 10)

	# Combat log toast text on turn plaque.
	combat_log_display = Label.new()
	combat_log_display.position = Vector2(10, 6)
	combat_log_display.size = Vector2(268, 22)
	combat_log_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combat_log_display.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	combat_log_display.text = "PLAYER TURN"
	combat_log_display.add_theme_font_size_override("font_size", 13)
	combat_log_display.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))
	combat_log_display.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	combat_log_display.add_theme_constant_override("outline_size", 2)
	_apply_pixel_font(combat_log_display)
	turn_plaque_panel.add_child(combat_log_display)

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
	f1_hint_label = Label.new()
	f1_hint_label.text = "F1: SETTINGS"
	f1_hint_label.position = Vector2(1008, 626)
	f1_hint_label.size = Vector2(144, 20)
	f1_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	f1_hint_label.add_theme_font_size_override("font_size", 11)
	f1_hint_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.85))
	f1_hint_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	f1_hint_label.add_theme_constant_override("outline_size", 2)
	_apply_pixel_font(f1_hint_label)
	_scene_root.add_child(f1_hint_label)


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

	var readable_order: Array[String] = []
	for actor_id in display_order:
		readable_order.append(_format_actor_display_name(str(actor_id)))
	turn_order_display.text = _truncate_with_ellipsis("TURN ORDER: " + " > ".join(readable_order), 150)


func update_status_effects_text() -> void:
	var active_statuses = []
	for member in _battle_manager.battle_state.party:
		if member.status_effects.size() > 0:
			var effect_names = []
			for effect in member.status_effects:
				effect_names.append(_format_status_effect_name(_status_id_from_variant(effect)))
			active_statuses.append(member.display_name + ": [" + ", ".join(effect_names) + "]")

	for enemy in _battle_manager.battle_state.enemies:
		if enemy.status_effects.size() > 0:
			var effect_names = []
			for effect in enemy.status_effects:
				effect_names.append(_format_status_effect_name(_status_id_from_variant(effect)))
			active_statuses.append(enemy.display_name + ": [" + ", ".join(effect_names) + "]")

	if status_effects_display:
		if active_statuses.is_empty():
			status_effects_display.text = ""
		else:
			status_effects_display.text = _truncate_with_ellipsis("STATUSES: " + " | ".join(active_statuses), 150)


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
			_party_hp_bars[actor_id].tooltip_text = "HP: %d/%d" % [actor.hp_current, actor.stats["hp_max"]]

		# Update MP bar (animated)
		if _party_mp_bars.has(actor_id) and actor.stats["mp_max"] > 0:
			_party_mp_bars[actor_id].set_hp(actor.mp_current, actor.stats["mp_max"])
			_party_mp_bars[actor_id].tooltip_text = "MP: %d/%d" % [actor.mp_current, actor.stats["mp_max"]]

		# Update resource grid
		if _party_resource_grids.has(actor_id):
			var grid = _party_resource_grids[actor_id]
			var res_val = _get_actor_resource_current(actor)
			grid.set_value(res_val)
			grid.tooltip_text = _resource_tooltip(actor)
		_refresh_status_icons(actor)

		# Update LB value box text.
		if _party_lb_bars.has(actor_id):
			_party_lb_bars[actor_id].value = actor.limit_gauge
		if _party_lb_texts.has(actor_id):
			if actor.limit_gauge >= 100:
				_party_lb_texts[actor_id].text = "READY"
				_party_lb_texts[actor_id].add_theme_color_override("font_color", Color(0.95, 1.0, 1.0))
				_start_lb_pulse(actor_id)
			else:
				_party_lb_texts[actor_id].text = "%d%%" % actor.limit_gauge
				_party_lb_texts[actor_id].add_theme_color_override("font_color", Color(0.96, 0.96, 0.96))
				_stop_lb_pulse(actor_id)
				if _party_lb_fills.has(actor_id):
					_party_lb_fills[actor_id].bg_color = Color(0.26, 0.58, 0.92, 0.95)
			_party_lb_texts[actor_id].tooltip_text = "Limit Break Gauge: %d%%" % actor.limit_gauge


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
	_party_hp_bars.clear()
	_party_mp_bars.clear()
	_party_name_labels.clear()
	_party_resource_grids.clear()
	_party_lb_bars.clear()
	_party_lb_texts.clear()
	_party_lb_fills.clear()
	_party_lb_tweens.clear()
	_party_row_highlights.clear()
	_party_status_icon_rows.clear()

	var active_id = _battle_manager.battle_state.get("active_character_id", "")

	# Draw column separators (span full panel height)
	var panel_h = party_status_panel.size.y
	var panel_w = party_status_panel.size.x
	for sep_x in [COL_SEP1_X, COL_SEP2_X, COL_SEP3_X]:
		if _skin_divider_v:
			var sep_tex = TextureRect.new()
			sep_tex.texture = _skin_divider_v
			sep_tex.position = Vector2(sep_x, 0)
			sep_tex.size = Vector2(1, panel_h)
			sep_tex.stretch_mode = TextureRect.STRETCH_SCALE
			sep_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sep_tex.modulate = Color(0.88, 0.82, 0.66, 0.2)
			party_status_panel.add_child(sep_tex)
		else:
			var sep = ColorRect.new()
			sep.color = SEP_COLOR
			sep.position = Vector2(sep_x, 0)
			sep.size = Vector2(1, panel_h)
			sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
			party_status_panel.add_child(sep)

	# Draw row separators between character lines
	var party_size = _battle_manager.battle_state.party.size()
	for i in range(1, party_size):
		if _skin_divider_h:
			var row_sep_tex = TextureRect.new()
			row_sep_tex.texture = _skin_divider_h
			row_sep_tex.position = Vector2(0, i * ROW_HEIGHT)
			row_sep_tex.size = Vector2(panel_w, 1)
			row_sep_tex.stretch_mode = TextureRect.STRETCH_SCALE
			row_sep_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row_sep_tex.modulate = Color(0.88, 0.82, 0.66, 0.2)
			party_status_panel.add_child(row_sep_tex)
		else:
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

		# --- Row shading ---
		var row_base = ColorRect.new()
		row_base.position = Vector2(0, row_y)
		row_base.size = Vector2(panel_w, ROW_HEIGHT)
		row_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_base.color = Color(0.02, 0.05, 0.09, 0.28)
		party_status_panel.add_child(row_base)

		var row_bg = ColorRect.new()
		row_bg.position = Vector2(0, row_y)
		row_bg.size = Vector2(panel_w, ROW_HEIGHT)
		row_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_bg.color = Color(0.55, 0.45, 0.18, 0.1)
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
		name_lbl.tooltip_text = actor.display_name
		name_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
		_party_name_labels[actor_id] = name_lbl
		party_status_panel.add_child(name_lbl)

		# --- HP/MP bars (fixed column) ---
		var hp_bar = AnimatedHealthBarClass.new()
		hp_bar.bar_size = Vector2(BAR_WIDTH, HP_BAR_HEIGHT)
		hp_bar.custom_minimum_size = Vector2(BAR_WIDTH, HP_BAR_HEIGHT)
		hp_bar.use_odometer = false
		hp_bar.corner_radius = 2
		hp_bar.custom_font = _pixel_font_bold if _pixel_font_bold else _pixel_font
		hp_bar.static_text_font_size = 11
		hp_bar.static_text_outline_size = 2
		hp_bar.static_text_vertical_offset = 0
		hp_bar.background_color = Color(0.09, 0.12, 0.17, 0.96)
		var bars_total_h = HP_BAR_HEIGHT + MP_BAR_HEIGHT + 2
		var bars_start_y = row_y + int((ROW_HEIGHT - bars_total_h) / 2)
		hp_bar.position = Vector2(COL_BARS_X, bars_start_y)
		_party_hp_bars[actor_id] = hp_bar
		party_status_panel.add_child(hp_bar)

		if actor.stats["mp_max"] > 0:
			var mp_bar = AnimatedHealthBarClass.new()
			mp_bar.bar_size = Vector2(BAR_WIDTH, MP_BAR_HEIGHT)
			mp_bar.custom_minimum_size = Vector2(BAR_WIDTH, MP_BAR_HEIGHT)
			mp_bar.main_color = MP_COLOR
			mp_bar.low_hp_color = MP_COLOR
			mp_bar.low_hp_threshold = -1.0
			mp_bar.use_odometer = false
			mp_bar.corner_radius = 2
			mp_bar.custom_font = _pixel_font
			mp_bar.static_text_font_size = 10
			mp_bar.static_text_outline_size = 1
			mp_bar.static_text_vertical_offset = 0
			mp_bar.background_color = Color(0.08, 0.1, 0.16, 0.95)
			mp_bar.position = Vector2(COL_BARS_X, bars_start_y + HP_BAR_HEIGHT + 2)
			_party_mp_bars[actor_id] = mp_bar
			party_status_panel.add_child(mp_bar)

		# --- Resource dot grid (compact fixed column to avoid heavy footprint) ---
		var res_max = _get_actor_resource_max(actor)
		if res_max > 0:
			var res_grid = ResourceDotGridClass.new()
			res_grid.max_value = res_max
			res_grid.fixed_columns = 4
			res_grid.dot_size = 8
			res_grid.dot_spacing = 2
			res_grid.row_spacing = 1
			res_grid.full_texture = _skin_pip_full
			res_grid.empty_texture = _skin_pip_empty
			res_grid.mouse_filter = Control.MOUSE_FILTER_STOP
			var grid_h = 2 * res_grid.dot_size + res_grid.row_spacing
			res_grid.position = Vector2(COL_RES_X, row_y + int((ROW_HEIGHT - grid_h) / 2))
			_party_resource_grids[actor_id] = res_grid
			party_status_panel.add_child(res_grid)

		# --- LB section (label + value box, matching the lighter reference) ---
		var lb_label = Label.new()
		lb_label.text = "LIMIT\nBREAK"
		lb_label.add_theme_font_size_override("font_size", 8)
		lb_label.add_theme_color_override("font_color", Color(0.72, 0.78, 0.9))
		lb_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		lb_label.add_theme_constant_override("outline_size", 1)
		lb_label.position = Vector2(COL_LB_X, row_y)
		lb_label.size = Vector2(42, ROW_HEIGHT)
		lb_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lb_label.tooltip_text = "Limit Break Gauge"
		lb_label.mouse_filter = Control.MOUSE_FILTER_STOP
		_apply_pixel_font(lb_label)
		party_status_panel.add_child(lb_label)

		var lb_box = Panel.new()
		lb_box.position = Vector2(COL_LB_VALUE_X, row_y + int((ROW_HEIGHT - 18) / 2))
		lb_box.size = Vector2(LB_VALUE_BOX_W, 18)
		lb_box.mouse_filter = Control.MOUSE_FILTER_STOP
		lb_box.tooltip_text = "Limit Break Gauge"
		lb_box.add_theme_stylebox_override("panel", _make_skin_style(_skin_lb_box, 5, 2))
		party_status_panel.add_child(lb_box)

		var lb_bar = ProgressBar.new()
		lb_bar.min_value = 0
		lb_bar.max_value = 100
		lb_bar.value = actor.limit_gauge
		lb_bar.show_percentage = false
		lb_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
		lb_bar.offset_left = 2
		lb_bar.offset_top = 2
		lb_bar.offset_right = -2
		lb_bar.offset_bottom = -2
		lb_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lb_bg = StyleBoxFlat.new()
		lb_bg.bg_color = Color(0.09, 0.11, 0.15, 0.9)
		lb_bg.corner_radius_top_left = 2
		lb_bg.corner_radius_top_right = 2
		lb_bg.corner_radius_bottom_left = 2
		lb_bg.corner_radius_bottom_right = 2
		var lb_fill = StyleBoxFlat.new()
		lb_fill.bg_color = Color(0.26, 0.58, 0.92, 0.95)
		lb_fill.corner_radius_top_left = 2
		lb_fill.corner_radius_top_right = 2
		lb_fill.corner_radius_bottom_left = 2
		lb_fill.corner_radius_bottom_right = 2
		lb_bar.add_theme_stylebox_override("background", lb_bg)
		lb_bar.add_theme_stylebox_override("fill", lb_fill)
		lb_bar.add_theme_stylebox_override("fg", lb_fill)
		lb_box.add_child(lb_bar)
		_party_lb_bars[actor_id] = lb_bar
		_party_lb_fills[actor_id] = lb_fill

		var lb_text = Label.new()
		lb_text.text = "READY" if actor.limit_gauge >= 100 else "%d%%" % actor.limit_gauge
		lb_text.add_theme_font_size_override("font_size", 11)
		lb_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lb_text.add_theme_color_override("font_color", Color(0.96, 0.96, 0.96))
		lb_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		lb_text.add_theme_constant_override("outline_size", 1)
		lb_text.set_anchors_preset(Control.PRESET_FULL_RECT)
		_apply_pixel_font(lb_text)
		lb_box.add_child(lb_text)
		_party_lb_texts[actor_id] = lb_text

		var status_row = HBoxContainer.new()
		status_row.position = Vector2(COL_STATUS_X, row_y + int((ROW_HEIGHT - STATUS_ICON_SIZE) / 2))
		status_row.size = Vector2(130, STATUS_ICON_SIZE)
		status_row.clip_contents = true
		status_row.add_theme_constant_override("separation", STATUS_ICON_GAP)
		status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_party_status_icon_rows[actor_id] = status_row
		party_status_panel.add_child(status_row)
		_refresh_status_icons(actor)

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


func _refresh_status_icons(actor: Character) -> void:
	if actor == null:
		return
	if not _party_status_icon_rows.has(actor.id):
		return
	var row = _party_status_icon_rows[actor.id] as HBoxContainer
	if row == null:
		return
	for child in row.get_children():
		child.queue_free()
	for status in actor.status_effects:
		var status_id = ""
		if status is StatusEffect:
			status_id = str(status.id)
		elif status is Dictionary:
			status_id = str(status.get("id", ""))
		if status_id.is_empty():
			continue
		var icon = _build_status_icon(status_id, status)
		row.add_child(icon)
	row.tooltip_text = _status_row_tooltip(actor)


func _build_status_icon(status_id: String, status: Variant = null) -> Control:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(STATUS_ICON_SIZE, STATUS_ICON_SIZE)
	panel.size = Vector2(STATUS_ICON_SIZE, STATUS_ICON_SIZE)
	panel.add_theme_stylebox_override("panel", _status_icon_style(status_id))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.tooltip_text = _status_tooltip_text(status_id, status)

	var txt = Label.new()
	txt.text = _status_icon_text(status_id)
	txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	txt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	txt.add_theme_font_size_override("font_size", 8)
	txt.add_theme_color_override("font_color", Color(0.98, 0.98, 0.98))
	txt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	txt.add_theme_constant_override("outline_size", 1)
	txt.set_anchors_preset(Control.PRESET_FULL_RECT)
	txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_pixel_font(txt, true)
	panel.add_child(txt)
	return panel


func _status_tooltip_text(status_id: String, status: Variant) -> String:
	var name = _format_status_effect_name(status_id)
	var details = ""
	match status_id:
		StatusEffectIds.POISON:
			details = "Takes damage each turn."
		StatusEffectIds.BURN:
			details = "Burning damage each turn."
		StatusEffectIds.BLESS:
			details = "Increases outgoing damage by a percent."
		StatusEffectIds.REGEN:
			details = "Recovers HP each turn."
		StatusEffectIds.ATK_UP:
			details = "Increases ATK."
		StatusEffectIds.ATK_DOWN:
			details = "Reduces ATK."
		StatusEffectIds.STUN:
			details = "Cannot act."
		StatusEffectIds.CHARM:
			details = "Temporarily unable to act."
		StatusEffectIds.GUARD_STANCE:
			details = "Higher defense, reduced damage taken, enables riposte."
		StatusEffectIds.MAGE_ARMOR:
			details = "Increases defense."
		StatusEffectIds.FIRE_IMBUE:
			details = "Attacks add fire damage and can inflict burn."
		StatusEffectIds.INSPIRE_ATTACK:
			details = "Next damage action gains bonus percent damage."
		StatusEffectIds.GENIES_WRATH:
			details = "Damaging spells are empowered and cost no MP for remaining charges."
		StatusEffectIds.PATIENT_DEFENSE:
			details = "Higher evasion."
		StatusEffectIds.TAUNT:
			details = "Draws enemy single-target attacks."
		StatusEffectIds.DEFENDING:
			details = "Temporarily reduces incoming damage."
		_:
			details = "Status effect."
	var turns = _status_duration(status)
	var turns_text = ""
	if turns >= 0:
		turns_text = "\nTurns: %d" % turns
	return name + "\n" + details + turns_text


func _status_duration(status: Variant) -> int:
	if status is StatusEffect:
		return int(status.duration)
	if status is Dictionary:
		return int(status.get("duration", -1))
	return -1


func _status_row_tooltip(actor: Character) -> String:
	if actor == null or actor.status_effects.is_empty():
		return "No active statuses."
	var labels: Array[String] = []
	for status in actor.status_effects:
		var status_id = _status_id_from_variant(status)
		if status_id != "":
			labels.append(_format_status_effect_name(status_id))
	return "Statuses: " + ", ".join(labels)


func _resource_tooltip(actor: Character) -> String:
	if actor == null:
		return ""
	if actor.resources.has("ki"):
		return "Ki: %d/%d" % [actor.get_resource_current("ki"), actor.resources["ki"].get("max", 0)]
	if actor.resources.has("superiority_dice"):
		return "Superiority Dice: %d/%d" % [actor.get_resource_current("superiority_dice"), actor.resources["superiority_dice"].get("max", 0)]
	if actor.resources.has("bardic_inspiration"):
		return "Bardic Inspiration: %d/%d" % [actor.get_resource_current("bardic_inspiration"), actor.resources["bardic_inspiration"].get("max", 0)]
	if actor.resources.has("sorcery_points"):
		return "Sorcery Points: %d/%d" % [actor.get_resource_current("sorcery_points"), actor.resources["sorcery_points"].get("max", 0)]
	return ""


func _status_icon_style(status_id: String) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = _status_icon_color(status_id)
	style.border_color = Color(0.08, 0.08, 0.1, 0.95)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	return style


func _status_icon_color(status_id: String) -> Color:
	match status_id:
		StatusEffectIds.POISON:
			return Color(0.48, 0.2, 0.72)
		StatusEffectIds.BURN:
			return Color(0.9, 0.36, 0.12)
		StatusEffectIds.BLESS:
			return Color(0.84, 0.72, 0.24)
		StatusEffectIds.REGEN:
			return Color(0.2, 0.72, 0.34)
		StatusEffectIds.ATK_UP:
			return Color(0.96, 0.64, 0.22)
		StatusEffectIds.ATK_DOWN:
			return Color(0.36, 0.44, 0.9)
		StatusEffectIds.STUN:
			return Color(0.95, 0.8, 0.2)
		StatusEffectIds.CHARM:
			return Color(0.9, 0.3, 0.66)
		StatusEffectIds.GUARD_STANCE:
			return Color(0.3, 0.62, 0.92)
		StatusEffectIds.MAGE_ARMOR:
			return Color(0.26, 0.54, 0.92)
		StatusEffectIds.FIRE_IMBUE:
			return Color(0.88, 0.34, 0.12)
		StatusEffectIds.INSPIRE_ATTACK:
			return Color(0.84, 0.42, 0.86)
		StatusEffectIds.GENIES_WRATH:
			return Color(0.96, 0.28, 0.74)
		StatusEffectIds.PATIENT_DEFENSE:
			return Color(0.34, 0.68, 0.86)
		StatusEffectIds.TAUNT:
			return Color(0.86, 0.24, 0.2)
		StatusEffectIds.DEFENDING:
			return Color(0.22, 0.72, 0.9)
		_:
			return Color(0.34, 0.34, 0.42)


func _status_icon_text(status_id: String) -> String:
	match status_id:
		StatusEffectIds.POISON:
			return "PO"
		StatusEffectIds.BURN:
			return "BU"
		StatusEffectIds.BLESS:
			return "BL"
		StatusEffectIds.REGEN:
			return "RG"
		StatusEffectIds.ATK_UP:
			return "AU"
		StatusEffectIds.ATK_DOWN:
			return "AD"
		StatusEffectIds.STUN:
			return "ST"
		StatusEffectIds.CHARM:
			return "CH"
		StatusEffectIds.GUARD_STANCE:
			return "GS"
		StatusEffectIds.MAGE_ARMOR:
			return "MA"
		StatusEffectIds.FIRE_IMBUE:
			return "FI"
		StatusEffectIds.INSPIRE_ATTACK:
			return "IN"
		StatusEffectIds.GENIES_WRATH:
			return "GW"
		StatusEffectIds.PATIENT_DEFENSE:
			return "PD"
		StatusEffectIds.TAUNT:
			return "TA"
		StatusEffectIds.DEFENDING:
			return "DF"
		_:
			return "??"


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


func _format_actor_display_name(actor_id: String) -> String:
	var actor = _battle_manager.get_actor_by_id(actor_id)
	if actor == null:
		actor = _battle_manager.get_actor_by_id(actor_id.to_lower())
	if actor != null and actor.display_name != "":
		return actor.display_name
	return _format_identifier(actor_id)


func _format_status_effect_name(effect_id: String) -> String:
	return _format_identifier(effect_id)


func _status_id_from_variant(effect: Variant) -> String:
	if effect is StatusEffect:
		return str(effect.id)
	if effect is Dictionary:
		return str(effect.get("id", ""))
	return ""


func _format_identifier(raw_value: String) -> String:
	var cleaned = raw_value.strip_edges()
	if cleaned == "":
		return ""
	var words = cleaned.to_lower().split("_", false)
	for i in range(words.size()):
		var word = words[i]
		if ACRONYM_WORDS.has(word):
			words[i] = ACRONYM_WORDS[word]
		elif word != "":
			words[i] = word.capitalize()
	return " ".join(words)


func _truncate_with_ellipsis(text: String, max_chars: int) -> String:
	if text.length() <= max_chars:
		return text
	if max_chars <= 3:
		return text.substr(0, max_chars)
	return text.substr(0, max_chars - 3) + "..."
