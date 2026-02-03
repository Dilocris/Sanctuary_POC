extends RefCounted
class_name BattleUIManager

## BattleUIManager - Manages all UI panels, displays, and overlays for battle
## Extracted from battle_scene.gd for single-responsibility design

signal phase_overlay_finished
signal limit_overlay_finished

# External references
var _scene_root: Node
var _battle_manager: BattleManager

# UI Constants
const LOWER_UI_TOP := 492
const ACTIVE_NAME_COLOR := Color(1.0, 0.9, 0.4)
const INACTIVE_NAME_COLOR := Color(1, 1, 1)
const ACTIVE_NAME_FONT_SIZE := 16
const INACTIVE_NAME_FONT_SIZE := 13

# UI Elements
var debug_panel: Control
var debug_log: RichTextLabel
var debug_toggle_btn: Button
var party_status_panel: VBoxContainer
var status_effects_display: Label
var turn_order_display: Label
var combat_log_display: Label
var enemy_intent_label: Label
var enemy_intent_bg: ColorRect
var phase_overlay: ColorRect
var phase_label: Label
var limit_overlay: ColorRect
var limit_label: Label
var boss_hp_bar: ProgressBar
var boss_hp_bar_label: Label
var boss_hp_fill_style: StyleBoxFlat
var battle_log_panel: RichTextLabel

# State
var last_logged_turn_id: String = ""
var pending_damage_messages: Array = []
var pending_status_messages: Array = []
var enemy_intent_duration: float = 2.0


func setup(scene_root: Node, battle_manager: BattleManager, intent_duration: float = 2.0) -> void:
	_scene_root = scene_root
	_battle_manager = battle_manager
	enemy_intent_duration = intent_duration


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
	# Lower UI background
	var lower_ui_bg = ColorRect.new()
	lower_ui_bg.color = Color(0, 0, 0, 0.6)
	lower_ui_bg.position = Vector2(0, LOWER_UI_TOP - 24)
	lower_ui_bg.size = Vector2(1152, 176)
	lower_ui_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene_root.add_child(lower_ui_bg)

	# Party Status Panel (Bottom Right)
	var panel_bg = Panel.new()
	panel_bg.position = Vector2(620, LOWER_UI_TOP)
	panel_bg.size = Vector2(520, 140)
	_scene_root.add_child(panel_bg)

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
	_scene_root.add_child(turn_order_display)

	# Status Effects Display (Centered below Turn Order)
	status_effects_display = Label.new()
	status_effects_display.position = Vector2(350, 40)
	status_effects_display.size = Vector2(400, 30)
	status_effects_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scene_root.add_child(status_effects_display)

	# Combat Log Toast (Above Bottom UI)
	combat_log_display = Label.new()
	combat_log_display.position = Vector2(200, 458)
	combat_log_display.size = Vector2(700, 30)
	combat_log_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combat_log_display.text = "Battle Start!"

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
	_scene_root.add_child(battle_log_panel)


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

	for child in party_status_panel.get_children():
		child.queue_free()

	var active_id = _battle_manager.battle_state.get("active_character_id", "")
	for actor in _battle_manager.battle_state.party:
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		var name_lbl = Label.new()
		name_lbl.text = actor.display_name
		name_lbl.custom_minimum_size = Vector2(96, 0)
		apply_name_style_func.call(name_lbl, actor.id == active_id)

		var hp_container = Control.new()
		hp_container.custom_minimum_size = Vector2(140, 18)
		hp_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var hp_bar = ProgressBar.new()
		hp_bar.min_value = 0
		hp_bar.max_value = actor.stats["hp_max"]
		hp_bar.value = actor.hp_current
		hp_bar.show_percentage = false
		hp_bar.size = Vector2(140, 18)
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
		mp_lbl.custom_minimum_size = Vector2(150, 0)

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
		lb_bar.custom_minimum_size = Vector2(90, 12)
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
		lb_text.add_theme_font_size_override("font_size", 11)
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


func update_boss_status() -> void:
	if boss_hp_bar == null:
		return
	var enemies = _battle_manager.get_alive_enemies()
	if enemies.size() > 0:
		var boss = enemies[0]
		boss_hp_bar.max_value = boss.stats["hp_max"]
		boss_hp_bar.value = boss.hp_current
		if boss_hp_bar_label:
			boss_hp_bar_label.text = "%d/%d" % [boss.hp_current, boss.stats["hp_max"]]
		update_boss_hp_color(boss.hp_current, boss.stats["hp_max"])
	else:
		if boss_hp_bar_label:
			boss_hp_bar_label.text = "Victory?"


func update_boss_hp_color(current_hp: int, max_hp: int) -> void:
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

func set_boss_hp_bar(bar: ProgressBar, label: Label, fill_style: StyleBoxFlat) -> void:
	boss_hp_bar = bar
	boss_hp_bar_label = label
	boss_hp_fill_style = fill_style
