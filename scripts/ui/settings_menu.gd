extends CanvasLayer
class_name SettingsMenu

## Settings/Debug overlay for battle tuning.
## Toggle with F1. Three tabs: Gameplay, Visual, Debug.

var _battle_scene: Node
var _battle_manager: Node      # BattleManager
var _game_feel: RefCounted     # GameFeelController
var _ui_manager: RefCounted    # BattleUIManager
var _was_input_locked: bool = false
var _is_open: bool = false

# UI nodes
var _bg_dim: ColorRect
var _panel: Panel
var _tab_buttons: Array[Button] = []
var _tab_containers: Array[VBoxContainer] = []
var _current_tab: int = 0

# Debug tab sliders (need refresh on open)
var _debug_hp_sliders: Dictionary = {}
var _debug_mp_sliders: Dictionary = {}

const TAB_NAMES := ["Gameplay", "Visual", "Debug"]
const PANEL_SIZE := Vector2(800, 500)


func _ready() -> void:
	layer = 200
	visible = false

	# Register F1 action
	if not InputMap.has_action("toggle_settings"):
		InputMap.add_action("toggle_settings")
		var ev = InputEventKey.new()
		ev.keycode = KEY_F1
		InputMap.action_add_event("toggle_settings", ev)


func setup(battle_scene: Node, battle_manager: Node, game_feel: RefCounted, ui_manager: RefCounted) -> void:
	_battle_scene = battle_scene
	_battle_manager = battle_manager
	_game_feel = game_feel
	_ui_manager = ui_manager
	_build_ui()


func _build_ui() -> void:
	# Dim background
	_bg_dim = ColorRect.new()
	_bg_dim.color = Color(0, 0, 0, 0.5)
	_bg_dim.size = Vector2(1152, 648)
	_bg_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg_dim)

	# Main panel
	_panel = Panel.new()
	_panel.position = (Vector2(1152, 648) - PANEL_SIZE) / 2.0
	_panel.size = PANEL_SIZE

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.border_color = Color(0.4, 0.4, 0.5)
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	# Title
	var title = Label.new()
	title.text = "Settings (F1)"
	title.position = Vector2(20, 10)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	_panel.add_child(title)

	# Tab buttons
	var tab_bar = HBoxContainer.new()
	tab_bar.position = Vector2(20, 44)
	tab_bar.add_theme_constant_override("separation", 8)
	_panel.add_child(tab_bar)

	for i in range(TAB_NAMES.size()):
		var btn = Button.new()
		btn.text = TAB_NAMES[i]
		btn.custom_minimum_size = Vector2(100, 30)
		btn.pressed.connect(_on_tab_pressed.bind(i))
		tab_bar.add_child(btn)
		_tab_buttons.append(btn)

	# Tab content area
	for i in range(TAB_NAMES.size()):
		var scroll = ScrollContainer.new()
		scroll.position = Vector2(20, 84)
		scroll.size = Vector2(PANEL_SIZE.x - 40, PANEL_SIZE.y - 100)
		scroll.visible = (i == 0)
		_panel.add_child(scroll)

		var content = VBoxContainer.new()
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_theme_constant_override("separation", 6)
		scroll.add_child(content)
		_tab_containers.append(content)

	_build_gameplay_tab(_tab_containers[0])
	_build_visual_tab(_tab_containers[1])
	_build_debug_tab(_tab_containers[2])
	_update_tab_style()


func _on_tab_pressed(index: int) -> void:
	_current_tab = index
	for i in range(_tab_containers.size()):
		_tab_containers[i].get_parent().visible = (i == index)
	_update_tab_style()


func _update_tab_style() -> void:
	for i in range(_tab_buttons.size()):
		if i == _current_tab:
			_tab_buttons[i].modulate = Color(1.0, 0.9, 0.5)
		else:
			_tab_buttons[i].modulate = Color(0.7, 0.7, 0.7)


# ============================================================================
# GAMEPLAY TAB
# ============================================================================

func _build_gameplay_tab(parent: VBoxContainer) -> void:
	_add_section_header(parent, "Damage")
	_add_slider(parent, "Damage Multiplier", 0.1, 5.0, 1.0, 0.1, func(v): DamageCalculator.damage_multiplier = v)

	_add_section_header(parent, "AI")
	_add_toggle(parent, "Disable Enemy AI", false, func(v): _battle_manager.battle_state.flags["ai_disabled"] = v)

	_add_section_header(parent, "Pacing")
	_add_slider(parent, "Turn Delay", 0.1, 3.0, _battle_scene.get("enemy_intent_duration") if _battle_scene.get("enemy_intent_duration") != null else 2.0, 0.1, func(v):
		if _battle_scene:
			_battle_scene.enemy_intent_duration = v
		if _ui_manager:
			_ui_manager.enemy_intent_duration = v
	)


# ============================================================================
# VISUAL TAB
# ============================================================================

func _build_visual_tab(parent: VBoxContainer) -> void:
	_add_section_header(parent, "Effect Toggles")
	_add_toggle(parent, "Camera Shake", _game_feel.shake_enabled, func(v): _game_feel.shake_enabled = v)
	_add_toggle(parent, "Hit Stop", _game_feel.hit_stop_enabled, func(v): _game_feel.hit_stop_enabled = v)
	_add_toggle(parent, "Screen Flash", _game_feel.screen_flash_enabled, func(v): _game_feel.screen_flash_enabled = v)
	_add_toggle(parent, "Sprite Pop", _game_feel.sprite_pop_enabled, func(v): _game_feel.sprite_pop_enabled = v)
	_add_toggle(parent, "Camera Nudge", _game_feel.nudge_enabled, func(v): _game_feel.nudge_enabled = v)

	_add_section_header(parent, "Shake Settings")
	_add_slider(parent, "Light Shake Amplitude", 0.0, 10.0, _game_feel.light_shake_amplitude, 0.5, func(v): _game_feel.light_shake_amplitude = v)
	_add_slider(parent, "Heavy Shake Amplitude", 0.0, 20.0, _game_feel.heavy_shake_amplitude, 0.5, func(v): _game_feel.heavy_shake_amplitude = v)
	_add_slider(parent, "Shake Duration", 0.01, 1.0, _game_feel.shake_duration, 0.01, func(v): _game_feel.shake_duration = v)

	_add_section_header(parent, "Hit Stop")
	_add_slider(parent, "Light Hit Frames", 0, 10, _game_feel.light_hit_frames, 1, func(v): _game_feel.light_hit_frames = int(v))
	_add_slider(parent, "Heavy Hit Frames", 0, 20, _game_feel.heavy_hit_frames, 1, func(v): _game_feel.heavy_hit_frames = int(v))

	_add_section_header(parent, "Flash")
	_add_slider(parent, "Flash Duration", 0.01, 1.0, _game_feel.flash_duration, 0.01, func(v): _game_feel.flash_duration = v)

	_add_section_header(parent, "Sprite Pop")
	_add_slider(parent, "Pop Scale", 1.0, 1.2, _game_feel.pop_scale, 0.01, func(v): _game_feel.pop_scale = v)
	_add_slider(parent, "Pop Duration", 0.01, 0.5, _game_feel.pop_duration, 0.01, func(v): _game_feel.pop_duration = v)

	_add_section_header(parent, "Camera Nudge")
	_add_slider(parent, "Nudge Distance", 0.0, 20.0, _game_feel.nudge_distance, 0.5, func(v): _game_feel.nudge_distance = v)
	_add_slider(parent, "Nudge Duration", 0.01, 0.5, _game_feel.nudge_duration, 0.01, func(v): _game_feel.nudge_duration = v)

	_add_section_header(parent, "Threshold")
	_add_slider(parent, "Heavy Hit Threshold", 10, 200, _game_feel.heavy_hit_threshold, 5, func(v): _game_feel.heavy_hit_threshold = int(v))


# ============================================================================
# DEBUG TAB
# ============================================================================

func _build_debug_tab(parent: VBoxContainer) -> void:
	_add_section_header(parent, "Quick Actions")

	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	parent.add_child(btn_row)

	_add_button(btn_row, "Heal All", func():
		for actor in _battle_manager.battle_state.party:
			actor.hp_current = actor.stats["hp_max"]
			actor.mp_current = actor.stats["mp_max"]
		_ui_manager.update_party_status(_battle_scene._apply_active_name_style)
	)

	_add_button(btn_row, "Fill Limits", func():
		for actor in _battle_manager.battle_state.party:
			actor.limit_gauge = 100
		_ui_manager.update_party_status(_battle_scene._apply_active_name_style)
	)

	_add_button(btn_row, "Kill Boss", func():
		for enemy in _battle_manager.battle_state.enemies:
			enemy.hp_current = 0
		_ui_manager.update_boss_status()
	)

	var btn_row2 = HBoxContainer.new()
	btn_row2.add_theme_constant_override("separation", 8)
	parent.add_child(btn_row2)

	_add_button(btn_row2, "Boss → Phase 2", func():
		var enemies = _battle_manager.get_alive_enemies()
		if enemies.size() > 0:
			var boss = enemies[0]
			var threshold = boss.stats["hp_max"] * 0.66
			if boss.hp_current > threshold:
				boss.hp_current = int(threshold) - 1
			_ui_manager.update_boss_status()
	)

	_add_button(btn_row2, "Boss → Phase 3", func():
		var enemies = _battle_manager.get_alive_enemies()
		if enemies.size() > 0:
			var boss = enemies[0]
			var threshold = boss.stats["hp_max"] * 0.33
			if boss.hp_current > threshold:
				boss.hp_current = int(threshold) - 1
			_ui_manager.update_boss_status()
	)


func populate_debug_party() -> void:
	var parent = _tab_containers[2]

	_add_section_header(parent, "Party HP/MP")

	for actor in _battle_manager.battle_state.party:
		var actor_id = actor.id
		var name_lbl = Label.new()
		name_lbl.text = actor.display_name
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0))
		parent.add_child(name_lbl)

		var hp_slider = _add_slider(parent, "HP", 0, actor.stats["hp_max"], actor.hp_current, 1, func(v, a = actor):
			a.hp_current = int(v)
			_ui_manager.update_party_status(_battle_scene._apply_active_name_style)
		)
		_debug_hp_sliders[actor_id] = hp_slider

		if actor.stats["mp_max"] > 0:
			var mp_slider = _add_slider(parent, "MP", 0, actor.stats["mp_max"], actor.mp_current, 1, func(v, a = actor):
				a.mp_current = int(v)
				_ui_manager.update_party_status(_battle_scene._apply_active_name_style)
			)
			_debug_mp_sliders[actor_id] = mp_slider


# ============================================================================
# OPEN / CLOSE
# ============================================================================

func open() -> void:
	if _is_open:
		return
	_is_open = true
	visible = true
	_was_input_locked = _battle_scene.input_locked
	_battle_scene.input_locked = true
	if _battle_scene.battle_menu:
		_battle_scene.battle_menu.set_enabled(false)
	_refresh_debug_values()


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	_battle_scene.input_locked = _was_input_locked
	if not _was_input_locked and _battle_scene.battle_menu:
		if _battle_scene.state == "PLAYER_TURN":
			_battle_scene.battle_menu.set_enabled(true)


func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func _refresh_debug_values() -> void:
	for actor in _battle_manager.battle_state.party:
		var actor_id = actor.id
		if _debug_hp_sliders.has(actor_id):
			_debug_hp_sliders[actor_id].value = actor.hp_current
		if _debug_mp_sliders.has(actor_id):
			_debug_mp_sliders[actor_id].value = actor.mp_current


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_settings"):
		toggle()
		get_viewport().set_input_as_handled()
		return

	if _is_open:
		# Consume all input while open (except F1 handled above)
		if event is InputEventKey or event is InputEventJoypadButton:
			if event.is_action_pressed("ui_cancel"):
				close()
			elif event.is_action_pressed("ui_left"):
				_current_tab = (_current_tab - 1 + TAB_NAMES.size()) % TAB_NAMES.size()
				_on_tab_pressed(_current_tab)
			elif event.is_action_pressed("ui_right"):
				_current_tab = (_current_tab + 1) % TAB_NAMES.size()
				_on_tab_pressed(_current_tab)
			get_viewport().set_input_as_handled()


# ============================================================================
# HELPER BUILDERS
# ============================================================================

func _add_section_header(parent: VBoxContainer, text: String) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	parent.add_child(lbl)

	var sep = HSeparator.new()
	sep.custom_minimum_size = Vector2(0, 2)
	parent.add_child(sep)


func _add_slider(parent: Control, label_text: String, min_val: float, max_val: float, initial: float, step: float, callback: Callable) -> HSlider:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(180, 0)
	lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(lbl)

	var slider = HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.value = initial
	slider.step = step
	slider.custom_minimum_size = Vector2(300, 20)
	row.add_child(slider)

	var val_lbl = Label.new()
	val_lbl.text = _format_value(initial, step)
	val_lbl.custom_minimum_size = Vector2(60, 0)
	val_lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(val_lbl)

	slider.value_changed.connect(func(v):
		val_lbl.text = _format_value(v, step)
		callback.call(v)
	)

	return slider


func _add_toggle(parent: Control, label_text: String, initial: bool, callback: Callable) -> CheckButton:
	var check = CheckButton.new()
	check.text = label_text
	check.button_pressed = initial
	check.add_theme_font_size_override("font_size", 12)
	parent.add_child(check)
	check.toggled.connect(callback)
	return check


func _add_button(parent: Control, label_text: String, callback: Callable) -> Button:
	var btn = Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(120, 30)
	btn.pressed.connect(callback)
	parent.add_child(btn)
	return btn


func _format_value(value: float, step: float) -> String:
	if step >= 1.0:
		return str(int(value))
	elif step >= 0.1:
		return "%.1f" % value
	else:
		return "%.2f" % value
