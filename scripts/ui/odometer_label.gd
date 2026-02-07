extends Control
class_name OdometerLabel

## Odometer-style label that rolls digits in place.
## Damage: digits roll DOWN. Healing: digits roll UP.

# Tuning parameters
@export var roll_duration: float = 0.15   # Per-digit settle time (0.12-0.2s)
@export var font_size: int = 13
@export var digit_width: int = 9          # Width per digit (monospace)
@export var digit_height: int = 16
@export var max_digits: int = 4           # Support up to 9999
@export var text_color: Color = Color.WHITE
@export var flash_on_damage: Color = Color(1.0, 0.3, 0.3, 0.3)
@export var flash_on_heal: Color = Color(0.3, 1.0, 0.3, 0.3)

# Internal state
var _current_value: int = 0
var _target_value: int = 0
var _digit_strips: Array[Control] = []
var _digit_tweens: Array[Tween] = []
var _clip_container: Control
var _flash_rect: ColorRect


func _ready() -> void:
	custom_minimum_size = Vector2(digit_width * max_digits, digit_height)
	size = custom_minimum_size
	clip_children = Control.CLIP_CHILDREN_AND_DRAW
	_create_display()


func _create_display() -> void:
	# Flash overlay (behind digits)
	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(0, 0, 0, 0)
	_flash_rect.size = size
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash_rect)

	# Clip container to hide off-screen digits
	_clip_container = Control.new()
	_clip_container.clip_children = Control.CLIP_CHILDREN_AND_DRAW
	_clip_container.size = size
	_clip_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip_container)

	# Create digit strips (right to left: ones, tens, hundreds, thousands)
	for i in range(max_digits):
		var strip = _create_digit_strip()
		# Position: rightmost digit at x = (max_digits - 1) * digit_width
		strip.position = Vector2((max_digits - 1 - i) * digit_width, 0)
		_clip_container.add_child(strip)
		_digit_strips.append(strip)
		_digit_tweens.append(null)


## Creates a vertical strip containing digits 0-9 (and wrapping 0 at end for smooth roll).
func _create_digit_strip() -> Control:
	var strip = Control.new()
	strip.size = Vector2(digit_width, digit_height * 11)  # 0-9 + wrap
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Create labels for digits 0-9, plus a wrapping 0 at position 10
	for d in range(11):
		var lbl = Label.new()
		lbl.text = str(d % 10)
		lbl.add_theme_font_size_override("font_size", font_size)
		lbl.add_theme_color_override("font_color", text_color)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.position = Vector2(0, d * digit_height)
		lbl.size = Vector2(digit_width, digit_height)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.add_child(lbl)

	return strip


## Set the displayed value with optional animation.
func set_value(new_value: int, animate: bool = true) -> void:
	new_value = maxi(0, new_value)
	var old_value = _current_value
	_target_value = new_value

	if not animate or old_value == new_value:
		_current_value = new_value
		_snap_to_value(new_value)
		return

	# Determine direction: damage (down) or healing (up)
	var direction = 1 if new_value < old_value else -1  # down = positive strip movement

	# Flash effect
	if new_value < old_value:
		_flash(flash_on_damage)
	else:
		_flash(flash_on_heal)

	# Roll each digit
	for i in range(max_digits):
		var old_digit = _get_digit(old_value, i)
		var new_digit = _get_digit(new_value, i)

		if old_digit != new_digit:
			_roll_digit(i, old_digit, new_digit, direction)

	_current_value = new_value


 ## Get the digit at position i (0 = ones, 1 = tens, etc.)
func _get_digit(value: int, position: int) -> int:
	var divisor = int(pow(10, position))
	return (value / divisor) % 10


## Snap all digits to show the value without animation.
func _snap_to_value(value: int) -> void:
	for i in range(max_digits):
		var digit = _get_digit(value, i)
		if i < _digit_strips.size():
			_digit_strips[i].position.y = -digit * digit_height


## Roll a single digit from one value to another.
func _roll_digit(strip_index: int, _from_digit: int, to_digit: int, _direction: int) -> void:
	if strip_index >= _digit_strips.size():
		return

	var strip = _digit_strips[strip_index]

	# Kill any existing tween for this strip
	if _digit_tweens[strip_index] and _digit_tweens[strip_index].is_valid():
		_digit_tweens[strip_index].kill()

	# Calculate target Y position
	var target_y = -to_digit * digit_height

	# Create smooth roll animation
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(strip, "position:y", float(target_y), roll_duration)
	_digit_tweens[strip_index] = tween


## Flash the background briefly.
func _flash(color: Color) -> void:
	_flash_rect.color = color
	var tween = create_tween()
	tween.tween_property(_flash_rect, "color:a", 0.0, 0.15)


## Initialize with a starting value (no animation).
func initialize(value: int) -> void:
	_current_value = value
	_target_value = value
	_snap_to_value(value)


## Update text color for all digits.
func set_text_color(color: Color) -> void:
	text_color = color
	for strip in _digit_strips:
		for child in strip.get_children():
			if child is Label:
				child.add_theme_color_override("font_color", color)
