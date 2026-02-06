extends Control
class_name AnimatedHealthBar

## Animated HP bar with delayed "yellow bar" damage feedback.
## Yellow bar holds at pre-damage value, then drains to current HP.
## HP numbers use odometer-style rolling digits.

const OdometerLabelClass = preload("res://scripts/ui/odometer_label.gd")

# Tuning parameters
@export var hold_time: float = 0.5         # Time yellow bar holds before draining (longer for visibility)
@export var drain_duration: float = 0.6    # Time for yellow bar to drain to current HP
@export var yellow_color: Color = Color(0.95, 0.8, 0.15)
@export var main_color: Color = Color(0.2, 0.75, 0.2)
@export var background_color: Color = Color(0.12, 0.12, 0.12, 0.95)
@export var corner_radius: int = 6
@export var bar_size: Vector2 = Vector2(140, 18)
@export var use_odometer: bool = true      # Rolling digit display for HP numbers
@export var low_hp_threshold: float = 0.25 # Fraction of max HP to trigger warning
@export var low_hp_color: Color = Color(0.85, 0.2, 0.2)

# State machine
enum State { IDLE, HOLD, DRAIN }
var _state: int = State.IDLE
var _hold_timer: float = 0.0
var _drain_tween: Tween

# Current values
var _current_hp: int = 0
var _max_hp: int = 1
var _yellow_value: float = 0.0
var _previous_hp: int = 0  # For detecting damage vs heal
var _is_low_hp: bool = false
var _heartbeat_tween: Tween

# Node references
var _yellow_bar: ProgressBar
var _main_bar: ProgressBar
var _hp_text: RichTextLabel          # Fallback static text
var _hp_odometer: Control            # OdometerLabel for current HP
var _hp_separator: Label             # "/" separator
var _hp_max_label: Label             # Static max HP label
var _hp_container: HBoxContainer     # Container for odometer display


func _ready() -> void:
	custom_minimum_size = bar_size
	size = bar_size
	clip_children = Control.CLIP_CHILDREN_AND_DRAW
	_create_bars()


func _create_bars() -> void:
	# Yellow bar (behind main bar) - has the background
	_yellow_bar = ProgressBar.new()
	_yellow_bar.min_value = 0
	_yellow_bar.max_value = 100
	_yellow_bar.value = 100
	_yellow_bar.show_percentage = false
	_yellow_bar.position = Vector2.ZERO
	# Use explicit size instead of anchors - anchors don't work reliably in VBoxContainers
	_yellow_bar.size = bar_size
	_yellow_bar.custom_minimum_size = bar_size

	var yellow_bg = StyleBoxFlat.new()
	yellow_bg.bg_color = background_color
	yellow_bg.corner_radius_top_left = corner_radius
	yellow_bg.corner_radius_top_right = corner_radius
	yellow_bg.corner_radius_bottom_left = corner_radius
	yellow_bg.corner_radius_bottom_right = corner_radius

	var yellow_fill = StyleBoxFlat.new()
	yellow_fill.bg_color = yellow_color
	yellow_fill.corner_radius_top_left = corner_radius
	yellow_fill.corner_radius_top_right = corner_radius
	yellow_fill.corner_radius_bottom_left = corner_radius
	yellow_fill.corner_radius_bottom_right = corner_radius

	_yellow_bar.add_theme_stylebox_override("background", yellow_bg)
	_yellow_bar.add_theme_stylebox_override("fill", yellow_fill)
	_yellow_bar.add_theme_stylebox_override("fg", yellow_fill)
	add_child(_yellow_bar)

	# Main bar (in front) - transparent background so yellow shows through
	_main_bar = ProgressBar.new()
	_main_bar.min_value = 0
	_main_bar.max_value = 100
	_main_bar.value = 100
	_main_bar.show_percentage = false
	_main_bar.position = Vector2.ZERO
	# Use explicit size instead of anchors - anchors don't work reliably in VBoxContainers
	_main_bar.size = bar_size
	_main_bar.custom_minimum_size = bar_size

	# Fully transparent StyleBox for background - allows yellow to show through
	var main_bg = StyleBoxEmpty.new()

	var main_fill = StyleBoxFlat.new()
	main_fill.bg_color = main_color
	main_fill.corner_radius_top_left = corner_radius
	main_fill.corner_radius_top_right = corner_radius
	main_fill.corner_radius_bottom_left = corner_radius
	main_fill.corner_radius_bottom_right = corner_radius

	_main_bar.add_theme_stylebox_override("background", main_bg)
	_main_bar.add_theme_stylebox_override("fill", main_fill)
	_main_bar.add_theme_stylebox_override("fg", main_fill)
	add_child(_main_bar)

	# HP text overlay
	if use_odometer:
		_create_odometer_display()
	else:
		_create_static_text()


func _create_static_text() -> void:
	_hp_text = RichTextLabel.new()
	_hp_text.bbcode_enabled = true
	_hp_text.scroll_active = false
	_hp_text.fit_content = false
	_hp_text.add_theme_font_size_override("normal_font_size", 13)
	_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Use explicit size instead of anchors
	_hp_text.position = Vector2.ZERO
	_hp_text.size = bar_size
	_hp_text.z_index = 1
	add_child(_hp_text)


func _create_odometer_display() -> void:
	# Container for the odometer display, centered on the bar
	_hp_container = HBoxContainer.new()
	_hp_container.alignment = BoxContainer.ALIGNMENT_CENTER
	# Use explicit size instead of anchors
	_hp_container.position = Vector2.ZERO
	_hp_container.size = bar_size
	_hp_container.z_index = 1
	_hp_container.clip_children = Control.CLIP_CHILDREN_AND_DRAW
	_hp_container.add_theme_constant_override("separation", 0)
	add_child(_hp_container)

	# Scale odometer sizes to fit bar height
	var d_height = mini(int(bar_size.y), 16)
	var d_font = maxi(8, d_height - 3)
	var d_width = maxi(6, int(d_height * 0.55))
	var text_font = maxi(7, d_height - 4)

	# Current HP (odometer)
	_hp_odometer = OdometerLabelClass.new()
	_hp_odometer.font_size = d_font
	_hp_odometer.digit_width = d_width
	_hp_odometer.digit_height = d_height
	_hp_odometer.max_digits = 4
	_hp_odometer.custom_minimum_size = Vector2(d_width * 4, d_height)
	_hp_container.add_child(_hp_odometer)

	# Separator "/"
	_hp_separator = Label.new()
	_hp_separator.text = "/"
	_hp_separator.add_theme_font_size_override("font_size", text_font)
	_hp_separator.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_hp_container.add_child(_hp_separator)

	# Max HP (static label)
	_hp_max_label = Label.new()
	_hp_max_label.text = "0"
	_hp_max_label.add_theme_font_size_override("font_size", text_font)
	_hp_max_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_hp_container.add_child(_hp_max_label)


func _process(delta: float) -> void:
	if _state == State.HOLD:
		_hold_timer -= delta
		if _hold_timer <= 0:
			_start_drain()


## Main entry point for HP updates.
## Detects damage vs heal and triggers appropriate animation.
func set_hp(current: int, max_hp: int) -> void:
	_max_hp = max(1, max_hp)
	var old_hp = _current_hp
	_current_hp = clampi(current, 0, _max_hp)

	# Update bar max values
	_yellow_bar.max_value = _max_hp
	_main_bar.max_value = _max_hp

	# Determine if this is damage or healing
	if _current_hp < old_hp:
		_on_damage(old_hp, _current_hp)
	elif _current_hp > old_hp:
		_on_heal(_current_hp)

	# Always update main bar and text immediately
	_main_bar.value = _current_hp
	_update_text()

	# Check low HP state
	_check_low_hp()

	_previous_hp = _current_hp


## Initialize the bar with starting values (no animation).
func initialize(current: int, max_hp: int) -> void:
	_max_hp = max(1, max_hp)
	_current_hp = clampi(current, 0, _max_hp)
	_previous_hp = _current_hp
	_yellow_value = float(_current_hp)

	_yellow_bar.max_value = _max_hp
	_main_bar.max_value = _max_hp
	_yellow_bar.value = _current_hp
	_main_bar.value = _current_hp

	_state = State.IDLE

	# Initialize odometer without animation
	if use_odometer and _hp_odometer:
		_hp_odometer.initialize(_current_hp)
		if _hp_max_label:
			_hp_max_label.text = str(_max_hp)
	else:
		_update_text(false)


func _on_damage(old_hp: int, _new_hp: int) -> void:
	# Cancel existing drain if in progress
	if _drain_tween and _drain_tween.is_valid():
		_drain_tween.kill()

	# If already in HOLD or DRAIN, keep yellow at current position (don't re-anchor higher)
	# This handles multi-hit: yellow stays at highest pre-damage value
	if _state == State.IDLE:
		_yellow_value = float(old_hp)
		_yellow_bar.value = _yellow_value

	# Quick modulate flash on the bar to draw attention
	_pulse_on_damage()

	# Start/restart hold timer
	_state = State.HOLD
	_hold_timer = hold_time


func _pulse_on_damage() -> void:
	var tween = create_tween()
	modulate = Color(1.4, 0.9, 0.9)
	tween.tween_property(self, "modulate", Color.WHITE, 0.25).set_ease(Tween.EASE_OUT)


func _on_heal(new_hp: int) -> void:
	# Cancel any drain in progress
	if _drain_tween and _drain_tween.is_valid():
		_drain_tween.kill()

	# Snap yellow bar up immediately (no trailing yellow on heal)
	_yellow_value = float(new_hp)
	_yellow_bar.value = _yellow_value
	_state = State.IDLE


func _start_drain() -> void:
	_state = State.DRAIN

	if _drain_tween and _drain_tween.is_valid():
		_drain_tween.kill()

	_drain_tween = create_tween()
	_drain_tween.tween_property(_yellow_bar, "value", float(_current_hp), drain_duration)
	_drain_tween.tween_callback(_on_drain_complete)


func _on_drain_complete() -> void:
	_yellow_value = float(_current_hp)
	_state = State.IDLE


func _update_text(animate: bool = true) -> void:
	if use_odometer and _hp_odometer:
		_hp_odometer.set_value(_current_hp, animate)
		if _hp_max_label:
			_hp_max_label.text = str(_max_hp)
	elif _hp_text:
		_hp_text.text = "[b]%d[/b][font_size=11]/%d[/font_size]" % [_current_hp, _max_hp]


## Check if HP has crossed the low-HP threshold and update visuals.
func _check_low_hp() -> void:
	var ratio = float(_current_hp) / float(_max_hp) if _max_hp > 0 else 1.0
	var now_low = ratio <= low_hp_threshold and _current_hp > 0

	if now_low and not _is_low_hp:
		_is_low_hp = true
		set_main_color(low_hp_color)
		_start_heartbeat()
	elif not now_low and _is_low_hp:
		_is_low_hp = false
		set_main_color(main_color)
		_stop_heartbeat()


func _start_heartbeat() -> void:
	_stop_heartbeat()
	_heartbeat_tween = create_tween().set_loops()
	_heartbeat_tween.tween_property(self, "modulate", Color(1.3, 0.85, 0.85), 0.3).set_ease(Tween.EASE_IN)
	_heartbeat_tween.tween_property(self, "modulate", Color.WHITE, 0.5).set_ease(Tween.EASE_OUT)


func _stop_heartbeat() -> void:
	if _heartbeat_tween and _heartbeat_tween.is_valid():
		_heartbeat_tween.kill()
	modulate = Color.WHITE


## Update bar colors (e.g., for low HP warning).
func set_main_color(color: Color) -> void:
	if _main_bar:
		var fill_style = _main_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fill_style:
			fill_style.bg_color = color
