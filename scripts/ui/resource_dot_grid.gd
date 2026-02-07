extends Control
class_name ResourceDotGrid

## Displays a resource as a 2-row grid of dots.
## Empty = hollow grey outline, Full = solid yellow fill.

# Configuration
@export var max_value: int = 6
@export var fixed_columns: int = 0  # If > 0, always reserve this many columns for alignment
@export var dot_size: int = 6
@export var dot_spacing: int = 2
@export var row_spacing: int = 1
@export var empty_color: Color = Color(0.4, 0.4, 0.4, 0.8)
@export var full_color: Color = Color(0.95, 0.85, 0.2)
@export var outline_width: float = 1.0

# Internal state
var _current_value: int = 0
var _dots: Array[ColorRect] = []
var _outlines: Array[ColorRect] = []


func _ready() -> void:
	_rebuild_grid()


func _rebuild_grid() -> void:
	# Clear existing dots
	for child in get_children():
		child.queue_free()
	_dots.clear()
	_outlines.clear()

	if max_value <= 0:
		return

	# Calculate grid dimensions: 2 rows, ceil(max/2) columns
	var cols = ceili(float(max_value) / 2.0)
	var rows = mini(2, max_value)

	# Use fixed_columns for sizing if set (ensures consistent width across rows)
	var size_cols = fixed_columns if fixed_columns > 0 else cols
	var total_width = size_cols * dot_size + (size_cols - 1) * dot_spacing
	var total_height = rows * dot_size + (rows - 1) * row_spacing

	custom_minimum_size = Vector2(total_width, total_height)
	size = custom_minimum_size

	# Create dots in column-major order (fill top-to-bottom, then left-to-right)
	for i in range(max_value):
		var col = i / 2
		var row = i % 2

		var x = col * (dot_size + dot_spacing)
		var y = row * (dot_size + row_spacing)

		# Outline (always visible)
		var outline = ColorRect.new()
		outline.color = empty_color
		outline.position = Vector2(x, y)
		outline.size = Vector2(dot_size, dot_size)
		outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(outline)
		_outlines.append(outline)

		# Fill (inner, smaller)
		var fill = ColorRect.new()
		fill.color = full_color
		fill.position = Vector2(x + outline_width, y + outline_width)
		fill.size = Vector2(dot_size - outline_width * 2, dot_size - outline_width * 2)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill.visible = false  # Start hidden
		add_child(fill)
		_dots.append(fill)

	_update_display()


## Set the current resource value.
func set_value(current: int) -> void:
	_current_value = clampi(current, 0, max_value)
	_update_display()


## Set the maximum resource value (rebuilds grid if changed).
func set_max_value(new_max: int) -> void:
	if new_max != max_value:
		max_value = new_max
		_rebuild_grid()


## Initialize with current and max values.
func initialize(current: int, max_val: int) -> void:
	max_value = max_val
	_current_value = clampi(current, 0, max_value)
	_rebuild_grid()


func _update_display() -> void:
	for i in range(_dots.size()):
		_dots[i].visible = (i < _current_value)
