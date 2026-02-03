extends Node2D

signal target_selected(target_ids: Array)
signal selection_canceled

var valid_targets: Array = []
var current_index: int = 0
var is_active: bool = false
var selector_mode: String = "SINGLE" # SINGLE, ALL, SELF
var mode_label: Label
var selected_ids: Array = []

func _ready() -> void:
	visible = false
	mode_label = Label.new()
	mode_label.text = "ALL"
	mode_label.visible = false
	mode_label.position = Vector2(-10, -90)
	add_child(mode_label)

func start_selection(targets: Array, mode: String = "SINGLE") -> void:
	valid_targets = targets
	selector_mode = mode
	if valid_targets.is_empty():
		print("TargetCursor: No valid targets!")
		emit_signal("selection_canceled")
		return
	
	current_index = 0
	selected_ids.clear()
	is_active = true
	visible = true
	mode_label.visible = selector_mode == "ALL" or selector_mode == "DOUBLE"
	if selector_mode == "DOUBLE":
		mode_label.text = "DOUBLE"
	else:
		mode_label.text = "ALL"
	_update_position()


func deactivate() -> void:
	is_active = false
	visible = false
	mode_label.visible = false

func _input(event: InputEvent) -> void:
	if not is_active:
		return
	
	if event.is_action_pressed("ui_left"):
		current_index = (current_index - 1 + valid_targets.size()) % valid_targets.size()
		_update_position()
	elif event.is_action_pressed("ui_right"):
		current_index = (current_index + 1) % valid_targets.size()
		_update_position()
	elif event.is_action_pressed("ui_accept"):
		_confirm_selection()
	elif event.is_action_pressed("ui_cancel"):
		_cancel_selection()

func _update_position() -> void:
	if valid_targets.is_empty():
		return
	
	# If mode is ALL, maybe position center or highlight all? 
	# For simplicity in Phase 4 POC, we just point to the "primary" target (index 0 or current)
	# even if we select all.
	
	if selector_mode == "ALL":
		var sum = Vector2.ZERO
		var count = 0
		for t in valid_targets:
			if t is Node2D:
				sum += t.global_position
				count += 1
		if count > 0:
			global_position = (sum / float(count)) + Vector2(0, -50)
			return

	var target = valid_targets[current_index]
	# Assuming target is a Node2D/Node3D with a position. 
	# In our harness, Characters are Nodes. If they don't have position, we might need a workaround.
	# The Character.gd extends Node. It does NOT have position unless we add it or it extends Node2D/3D.
	# Let's check Character structure.
	
	if target is Node2D:
		var visual = target.get_node_or_null("Visual")
		if visual is Node2D:
			global_position = visual.global_position + Vector2(0, -20)
		else:
			global_position = target.global_position + Vector2(0, -50) # Point above head
	else:
		# Fallback if characters aren't spatial, just print for now or use mock positions
		# Since the harness is pure logic Node based, we might not have positions!
		# We need to give them mocked positions in the BattleScene for the cursor to work visually.
		print("Cursor targeting: ", target.name) 

func _confirm_selection() -> void:
	if selector_mode == "ALL":
		is_active = false
		visible = false
		var ids = []
		for t in valid_targets:
			ids.append(t.id)
		emit_signal("target_selected", ids)
		return
	if selector_mode == "DOUBLE":
		var current_id = valid_targets[current_index].id
		if selected_ids.has(current_id):
			return
		selected_ids.append(current_id)
		if selected_ids.size() >= 2:
			is_active = false
			visible = false
			emit_signal("target_selected", selected_ids)
		return
	# Single Target
	is_active = false
	visible = false
	emit_signal("target_selected", [valid_targets[current_index].id])

func _cancel_selection() -> void:
	is_active = false
	visible = false
	selected_ids.clear()
	emit_signal("selection_canceled")
