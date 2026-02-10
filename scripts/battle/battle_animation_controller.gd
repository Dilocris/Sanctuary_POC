extends RefCounted
class_name BattleAnimationController

## BattleAnimationController - Manages all tween-based animations for battle visuals
## Extracted from battle_scene.gd for single-responsibility design

# External references (set via setup)
var _scene_root: Node
var _battle_manager: BattleManager
var _actor_sprites: Dictionary  # actor_id -> Sprite2D
var _actor_base_positions: Dictionary  # actor_id -> Vector2
var _actor_base_modulates: Dictionary  # actor_id -> Color
var _actor_base_self_modulates: Dictionary  # actor_id -> Color
var _actor_nodes: Dictionary  # actor_id -> Node2D (character/boss node)
var _actor_root_positions: Dictionary  # actor_id -> Vector2

# Internal tween state
var _idle_tweens: Dictionary = {}
var _action_tweens: Dictionary = {}
var _shake_tweens: Dictionary = {}
var _flash_tweens: Dictionary = {}
var _poison_tweens: Dictionary = {}
var _last_hit_at: Dictionary = {}
var _global_idle_tokens: Dictionary = {}
var _spritesheet_actors: Dictionary = {}  # actor_id -> true; skip faux idle for these
var _attack_configs: Dictionary = {}      # actor_id -> {path, hframes, vframes, fps, impact_frame, texture}
var _idle_textures: Dictionary = {}       # actor_id -> Texture2D (idle sheet for restoration)
var _idle_configs: Dictionary = {}        # actor_id -> {hframes, vframes} for idle restoration
var _attack_playing: Dictionary = {}      # actor_id -> true while attack anim is active
var _is_shutting_down: bool = false
var _pixel_font: Font
var _pixel_font_bold: Font
var _float_font: Font
var _float_layer: CanvasLayer
var _float_lane_index: Dictionary = {}
var _float_lane_last_ms: Dictionary = {}
const FLOAT_LANE_RESET_MS := 320
const FLOAT_LANE_OFFSETS := [
	Vector2(0, 0),
	Vector2(16, -6),
	Vector2(-16, -8),
	Vector2(10, -15),
	Vector2(-10, -16)
]
const MIN_ATTACK_FRAME_DURATION_SEC := 0.03
const MAX_ATTACK_FRAME_DURATION_SEC := 2.00


func has_spritesheet_idle(actor_id: String) -> bool:
	return _spritesheet_actors.has(actor_id)


func has_attack_animation(actor_id: String) -> bool:
	return _attack_configs.has(actor_id)


func get_attack_animation_duration(actor_id: String) -> float:
	if not _attack_configs.has(actor_id):
		return 0.0
	var config = _attack_configs[actor_id]
	var timeline = _build_attack_timeline(config)
	var total := 0.0
	for step in timeline:
		if step is Dictionary:
			total += float(step.get("duration", 0.0))
	return total


func register_spritesheet_actor(actor_id: String) -> void:
	_spritesheet_actors[actor_id] = true


func register_attack_spritesheet(actor_id: String, config: Dictionary) -> void:
	var sheet_path = str(config.get("path", ""))
	if sheet_path == "" or not ResourceLoader.exists(sheet_path):
		push_warning("Attack spritesheet not found for " + actor_id + ": " + sheet_path)
		return
	var cfg = config.duplicate()
	cfg["texture"] = load(sheet_path)
	var validation = _validate_attack_config(actor_id, cfg)
	if not bool(validation.get("ok", false)):
		var issues: Array = validation.get("issues", [])
		push_warning("Skipping attack config for " + actor_id + ": " + " | ".join(issues))
		return
	_attack_configs[actor_id] = cfg


func get_attack_config_validation(actor_id: String) -> Dictionary:
	if not _attack_configs.has(actor_id):
		return {"ok": false, "issues": ["attack config not registered"]}
	return _validate_attack_config(actor_id, _attack_configs[actor_id])


func _validate_attack_config(actor_id: String, config: Dictionary) -> Dictionary:
	var issues: Array = []
	var texture = config.get("texture", null)
	if texture == null or not (texture is Texture2D):
		issues.append("missing Texture2D")
		return {"ok": false, "issues": issues}
	var hframes = int(config.get("hframes", 1))
	var vframes = int(config.get("vframes", 1))
	if hframes <= 0 or vframes <= 0:
		issues.append("hframes/vframes must be > 0")
		return {"ok": false, "issues": issues}
	var tex_w = int(texture.get_width())
	var tex_h = int(texture.get_height())
	if tex_w % hframes != 0:
		issues.append("texture width " + str(tex_w) + " not divisible by hframes " + str(hframes))
	if tex_h % vframes != 0:
		issues.append("texture height " + str(tex_h) + " not divisible by vframes " + str(vframes))
	var total_frames = max(1, hframes * vframes)
	var sequence = config.get("frame_sequence", [])
	if sequence is Array and not sequence.is_empty():
		for i in range(sequence.size()):
			var frame_idx = int(sequence[i])
			if frame_idx < 0 or frame_idx >= total_frames:
				issues.append("frame_sequence[" + str(i) + "] out of range: " + str(frame_idx))
	var frame_durations = config.get("frame_durations", [])
	if frame_durations is Array:
		for i in range(frame_durations.size()):
			var duration = float(frame_durations[i])
			if duration < MIN_ATTACK_FRAME_DURATION_SEC or duration > MAX_ATTACK_FRAME_DURATION_SEC:
				issues.append("frame_durations[" + str(i) + "] out of bounds: " + str(duration))
	var frame_y_offsets = config.get("frame_y_offsets", [])
	if frame_y_offsets is Array:
		for i in range(frame_y_offsets.size()):
			var offset = float(frame_y_offsets[i])
			if absf(offset) > 64.0:
				issues.append("frame_y_offsets[" + str(i) + "] too large: " + str(offset))
	var impact_frame = int(config.get("impact_frame", 0))
	if impact_frame < 0 or impact_frame >= total_frames:
		issues.append("impact_frame out of range: " + str(impact_frame))
	return {"ok": issues.is_empty(), "issues": issues}


func _build_attack_timeline(config: Dictionary) -> Array:
	var hframes = max(1, int(config.get("hframes", 1)))
	var vframes = max(1, int(config.get("vframes", 1)))
	var total_frames = max(1, hframes * vframes)
	var fps = max(1.0, float(config.get("fps", 12.0)))
	var default_duration = 1.0 / fps
	var sequence: Array = []
	var configured_sequence = config.get("frame_sequence", [])
	if configured_sequence is Array and not configured_sequence.is_empty():
		sequence = configured_sequence
	else:
		for frame_idx in range(total_frames):
			sequence.append(frame_idx)
	var configured_durations = config.get("frame_durations", [])
	var configured_y_offsets = config.get("frame_y_offsets", [])
	var timeline: Array = []
	for i in range(sequence.size()):
		var frame_index = clamp(int(sequence[i]), 0, total_frames - 1)
		var duration = default_duration
		if configured_durations is Array and i < configured_durations.size():
			duration = float(configured_durations[i])
		duration = clamp(duration, MIN_ATTACK_FRAME_DURATION_SEC, MAX_ATTACK_FRAME_DURATION_SEC)
		var y_offset := 0.0
		if configured_y_offsets is Array and i < configured_y_offsets.size():
			y_offset = float(configured_y_offsets[i])
		timeline.append({
			"frame": frame_index,
			"duration": duration,
			"y_offset": y_offset
		})
	return timeline


func _resolve_impact_step_index(config: Dictionary, timeline: Array) -> int:
	if timeline.is_empty():
		return 0
	var impact_frame = int(config.get("impact_frame", -1))
	for i in range(timeline.size()):
		var step = timeline[i]
		if step is Dictionary and int(step.get("frame", -1)) == impact_frame:
			return i
	return min(2, timeline.size() - 1)


func _get_attack_sheet_metrics(config: Dictionary, texture: Texture2D) -> Dictionary:
	var hframes = max(1, int(config.get("hframes", 1)))
	var vframes = max(1, int(config.get("vframes", 1)))
	var tex_w = int(texture.get_width())
	var tex_h = int(texture.get_height())
	if tex_w % hframes != 0 or tex_h % vframes != 0:
		return {"ok": false}
	return {
		"ok": true,
		"hframes": hframes,
		"vframes": vframes,
		"frame_w": tex_w / hframes,
		"frame_h": tex_h / vframes
	}


func register_idle_texture(actor_id: String, texture: Texture2D, config: Dictionary) -> void:
	_idle_textures[actor_id] = texture
	_idle_configs[actor_id] = config


func setup(
	scene_root: Node,
	battle_manager: BattleManager,
	actor_sprites: Dictionary,
	actor_base_positions: Dictionary,
	actor_base_modulates: Dictionary,
	actor_base_self_modulates: Dictionary,
	actor_nodes: Dictionary,
	actor_root_positions: Dictionary
) -> void:
	_scene_root = scene_root
	_battle_manager = battle_manager
	_actor_sprites = actor_sprites
	_actor_base_positions = actor_base_positions
	_actor_base_modulates = actor_base_modulates
	_actor_base_self_modulates = actor_base_self_modulates
	_actor_nodes = actor_nodes
	_actor_root_positions = actor_root_positions
	_is_shutting_down = false
	_load_float_fonts()
	_ensure_float_layer()


func _load_float_fonts() -> void:
	if ResourceLoader.exists("res://assets/fonts/Silkscreen-Regular.ttf"):
		_pixel_font = load("res://assets/fonts/Silkscreen-Regular.ttf")
	if ResourceLoader.exists("res://assets/fonts/Silkscreen-Bold.ttf"):
		_pixel_font_bold = load("res://assets/fonts/Silkscreen-Bold.ttf")
	# Floating combat text uses the same sans-serif fallback used by standard UI controls.
	if ThemeDB.fallback_font != null:
		_float_font = ThemeDB.fallback_font
	else:
		_float_font = _pixel_font_bold if _pixel_font_bold != null else _pixel_font


func shutdown() -> void:
	_is_shutting_down = true
	# Invalidate global idle loop tokens so delayed callbacks no-op.
	_global_idle_tokens.clear()
	_float_lane_index.clear()
	_float_lane_last_ms.clear()
	if _float_layer != null and is_instance_valid(_float_layer):
		_float_layer.queue_free()
	_float_layer = null
	# Kill any live tweens we own.
	for actor_id in _actor_sprites.keys():
		cleanup_actor_tweens(actor_id)


func _can_use_scene_root() -> bool:
	return not _is_shutting_down and _scene_root != null and is_instance_valid(_scene_root) and _scene_root.is_inside_tree()


func _safe_add_to_scene(node: Node) -> bool:
	if not _can_use_scene_root():
		return false
	_ensure_float_layer()
	if _float_layer != null and is_instance_valid(_float_layer):
		_float_layer.add_child(node)
	else:
		_scene_root.add_child(node)
	return true


func _ensure_float_layer() -> void:
	if not _can_use_scene_root():
		return
	if _float_layer != null and is_instance_valid(_float_layer):
		return
	_float_layer = CanvasLayer.new()
	_float_layer.name = "CombatFloatLayer"
	_float_layer.layer = 30
	_scene_root.add_child(_float_layer)


# ============================================================================
# FLOATING TEXT
# ============================================================================

func create_floating_text(pos: Vector2, text: String, color: Color, anchor_id: String = "") -> void:
	if not _can_use_scene_root():
		return
	var label = Label.new()
	label.text = text
	label.modulate = color
	label.position = _reserve_float_position(anchor_id, pos + Vector2(0, -50))
	label.add_theme_font_size_override("font_size", 22)
	if _float_font:
		label.add_theme_font_override("font", _float_font)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_as_relative = false
	label.z_index = 500
	if not _safe_add_to_scene(label):
		return

	var tween = _scene_root.create_tween()
	tween.parallel().tween_property(label, "position:y", label.position.y - 46, 1.22)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.22)
	tween.tween_callback(label.queue_free)


func spawn_damage_numbers(target_id: String, damages: Array) -> void:
	if not _can_use_scene_root():
		return
	var actor = _battle_manager.get_actor_by_id(target_id)
	if actor == null:
		return
	for i in range(damages.size()):
		var dmg_val = int(damages[i])
		var delay = float(i) * 0.45
		var offset = Vector2(10 * i, -6 * i)
		var timer = _scene_root.get_tree().create_timer(delay)
		var pos = actor.position + offset
		timer.timeout.connect(func ():
			if not _can_use_scene_root():
				return
			if dmg_val <= 0:
				create_miss_text(pos, target_id)
			else:
				create_damage_text(pos, str(dmg_val), dmg_val, target_id)
		)


const HEAVY_DAMAGE_THRESHOLD := 50
const NORMAL_DAMAGE_FONT := 30
const HEAVY_DAMAGE_FONT := 38
const MISS_FONT := 28

func create_damage_text(pos: Vector2, text: String, damage_value: int = 0, anchor_id: String = "") -> void:
	if not _can_use_scene_root():
		return
	var is_heavy = damage_value >= HEAVY_DAMAGE_THRESHOLD
	var font_size = HEAVY_DAMAGE_FONT if is_heavy else NORMAL_DAMAGE_FONT
	var color = Color(1.0, 0.3, 0.1) if is_heavy else Color(1.0, 0.55, 0.1)

	var label = Label.new()
	label.text = text
	label.modulate = color
	label.position = _reserve_float_position(anchor_id, pos + Vector2(0, -64))
	label.add_theme_font_size_override("font_size", font_size)
	if _float_font:
		label.add_theme_font_override("font", _float_font)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_as_relative = false
	label.z_index = 500
	if not _safe_add_to_scene(label):
		return

	var tween = _scene_root.create_tween()
	if is_heavy:
		# Pop-in scale effect for heavy hits
		label.pivot_offset = label.size / 2.0
		label.scale = Vector2(1.3, 1.3)
		tween.parallel().tween_property(label, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(label, "position:y", label.position.y - 48, 1.26)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.26)
	tween.tween_callback(label.queue_free)


func spawn_miss_text(target_id: String) -> void:
	if not _can_use_scene_root():
		return
	var actor = _battle_manager.get_actor_by_id(target_id)
	if actor == null:
		return
	create_miss_text(actor.position, target_id)


func create_miss_text(pos: Vector2, anchor_id: String = "") -> void:
	if not _can_use_scene_root():
		return
	var label = Label.new()
	label.text = "MISS"
	label.modulate = Color(0.9, 0.95, 1.0)
	label.position = _reserve_float_position(anchor_id, pos + Vector2(0, -64))
	label.add_theme_font_size_override("font_size", MISS_FONT)
	if _float_font:
		label.add_theme_font_override("font", _float_font)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_as_relative = false
	label.z_index = 500
	if not _safe_add_to_scene(label):
		return

	var tween = _scene_root.create_tween()
	label.pivot_offset = label.size / 2.0
	label.scale = Vector2(1.2, 1.2)
	tween.parallel().tween_property(label, "scale", Vector2.ONE, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(label, "position:y", label.position.y - 40, 1.15)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.15)
	tween.tween_callback(label.queue_free)


func create_status_tick_text(pos: Vector2, text: String, color: Color, anchor_id: String = "") -> void:
	if not _can_use_scene_root():
		return
	var label = Label.new()
	label.text = text
	label.modulate = color
	label.position = _reserve_float_position(anchor_id, pos + Vector2(0, -40))
	label.add_theme_font_size_override("font_size", 22)
	if _float_font:
		label.add_theme_font_override("font", _float_font)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_as_relative = false
	label.z_index = 500
	if not _safe_add_to_scene(label):
		return
	var tween = _scene_root.create_tween()
	tween.parallel().tween_property(label, "position:y", label.position.y - 28, 1.12)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.12)
	tween.tween_callback(label.queue_free)


func spawn_damage_components(target_id: String, components: Array) -> int:
	if not _can_use_scene_root():
		return 0
	if components.is_empty():
		return 0
	var actor = _battle_manager.get_actor_by_id(target_id)
	if actor == null:
		return 0
	var index := 0
	var created := 0
	for component in components:
		if not (component is Dictionary):
			continue
		var amount = int(component.get("amount", 0))
		if amount <= 0:
			continue
		var source_type = str(component.get("type", "normal"))
		var color = _component_color(source_type)
		var text = str(amount) if source_type == "normal" else "+" + str(amount)
		var delay = 0.08 * float(index)
		var offset = Vector2(46 + (10 * index), -84 - (8 * index))
		var timer = _scene_root.get_tree().create_timer(delay)
		var pos = actor.position + offset
		timer.timeout.connect(func():
			_create_component_text(pos, text, color, target_id)
		)
		index += 1
		created += 1
	return created


func _component_color(source_type: String) -> Color:
	match source_type:
		"crit":
			return Color(1.0, 0.22, 0.15)
		"buff":
			return Color(1.0, 0.9, 0.25)
		"poison":
			return Color(0.72, 0.35, 0.95)
		"burn":
			return Color(1.0, 0.5, 0.18)
		_:
			return Color(1.0, 0.56, 0.18)


func _create_component_text(pos: Vector2, text: String, color: Color, anchor_id: String = "") -> void:
	if not _can_use_scene_root():
		return
	var label = Label.new()
	label.text = text
	label.modulate = color
	label.position = _reserve_float_position(anchor_id, pos)
	label.add_theme_font_size_override("font_size", 18)
	if _float_font:
		label.add_theme_font_override("font", _float_font)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_as_relative = false
	label.z_index = 500
	if not _safe_add_to_scene(label):
		return
	var tween = _scene_root.create_tween()
	tween.parallel().tween_property(label, "position:y", label.position.y - 24, 0.84)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.84)
	tween.tween_callback(label.queue_free)


func _reserve_float_position(anchor_id: String, base_position: Vector2) -> Vector2:
	if anchor_id == "":
		return base_position
	var now_ms = Time.get_ticks_msec()
	var last_ms = int(_float_lane_last_ms.get(anchor_id, 0))
	if now_ms - last_ms > FLOAT_LANE_RESET_MS:
		_float_lane_index[anchor_id] = 0
	var lane = int(_float_lane_index.get(anchor_id, 0))
	var lane_offset = FLOAT_LANE_OFFSETS[lane % FLOAT_LANE_OFFSETS.size()]
	_float_lane_index[anchor_id] = lane + 1
	_float_lane_last_ms[anchor_id] = now_ms
	return base_position + lane_offset


# ============================================================================
# IDLE WIGGLE (Active character sway)
# ============================================================================

func start_idle_wiggle(actor_id: String) -> void:
	if not _can_use_scene_root():
		return
	if has_spritesheet_idle(actor_id):
		return
	var sprite = _actor_sprites.get(actor_id, null)
	if sprite == null:
		return
	if _idle_tweens.has(actor_id):
		var existing = _idle_tweens[actor_id]
		if existing:
			existing.kill()
	var base_pos = _actor_base_positions.get(actor_id, Vector2.ZERO)
	sprite.position = base_pos
	var tween = _scene_root.create_tween()
	tween.set_loops()
	tween.tween_property(sprite, "position:x", base_pos.x + 3, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "position:x", base_pos.x - 3, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "position:x", base_pos.x, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tweens[actor_id] = tween


func stop_idle_wiggle(actor_id: String) -> void:
	if _idle_tweens.has(actor_id):
		var tween = _idle_tweens[actor_id]
		if tween:
			tween.kill()
		_idle_tweens.erase(actor_id)
	var sprite = _actor_sprites.get(actor_id, null)
	if sprite == null:
		return
	var base_pos = _actor_base_positions.get(actor_id, sprite.position)
	sprite.position = base_pos


func update_active_idle_motion(active_id: String) -> void:
	for actor_id in _actor_sprites.keys():
		if actor_id == active_id:
			if should_delay_idle_after_hit(actor_id):
				stop_idle_wiggle(actor_id)
				delay_idle_after_recent_hit(actor_id)
			else:
				start_idle_wiggle(actor_id)
		else:
			stop_idle_wiggle(actor_id)


func resume_idle_if_active(actor_id: String, delay: float) -> void:
	if not _can_use_scene_root():
		return
	var timer = _scene_root.get_tree().create_timer(delay)
	timer.timeout.connect(func ():
		if not _can_use_scene_root():
			return
		if _battle_manager.battle_state.get("active_character_id", "") == actor_id:
			start_idle_wiggle(actor_id)
	)


func delay_idle_after_recent_hit(actor_id: String) -> void:
	if not _can_use_scene_root():
		return
	if _shake_tweens.has(actor_id):
		var timer = _scene_root.get_tree().create_timer(0.15)
		timer.timeout.connect(func ():
			if not _can_use_scene_root():
				return
			if _battle_manager.battle_state.get("active_character_id", "") == actor_id:
				start_idle_wiggle(actor_id)
		)


func should_delay_idle_after_hit(actor_id: String) -> bool:
	if not _last_hit_at.has(actor_id):
		return false
	return Time.get_ticks_msec() - int(_last_hit_at[actor_id]) < 500


# ============================================================================
# ACTION WHIP (Attack motion)
# ============================================================================

func play_action_whip(actor_id: String, is_party_member: bool) -> void:
	if not _can_use_scene_root():
		return
	var sprite = _actor_sprites.get(actor_id, null)
	if sprite == null:
		return
	stop_idle_wiggle(actor_id)
	if _action_tweens.has(actor_id):
		var existing = _action_tweens[actor_id]
		if existing:
			existing.kill()
	var base_pos = _actor_base_positions.get(actor_id, sprite.position)
	var dir = -1.0 if is_party_member else 1.0
	var tween = _scene_root.create_tween()
	tween.tween_property(sprite, "position:x", base_pos.x + (dir * 10.0), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "position:x", base_pos.x, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_action_tweens[actor_id] = tween
	resume_idle_if_active(actor_id, 0.45)


# ============================================================================
# ATTACK ANIMATION (Spritesheet playback)
# ============================================================================

func play_attack_animation(actor_id: String, on_impact: Callable, on_complete: Callable) -> void:
	if not _can_use_scene_root():
		on_impact.call()
		on_complete.call()
		return
	if not _attack_configs.has(actor_id):
		on_impact.call()
		on_complete.call()
		return
	var sprite = _actor_sprites.get(actor_id, null)
	if sprite == null or not (sprite is Sprite2D):
		on_impact.call()
		on_complete.call()
		return

	var config = _attack_configs[actor_id]
	var attack_tex = config.get("texture", null)
	if attack_tex == null or not (attack_tex is Texture2D):
		on_impact.call()
		on_complete.call()
		return
	var metrics = _get_attack_sheet_metrics(config, attack_tex)
	if not bool(metrics.get("ok", false)):
		push_warning("Invalid attack sheet metrics for " + actor_id)
		on_impact.call()
		on_complete.call()
		return
	var hf = int(metrics.get("hframes", 1))
	var frame_w = int(metrics.get("frame_w", 1))
	var frame_h = int(metrics.get("frame_h", 1))
	var timeline = _build_attack_timeline(config)
	if timeline.is_empty():
		on_impact.call()
		on_complete.call()
		return
	var impact_step = _resolve_impact_step_index(config, timeline)

	# Pause idle frame timer
	var character_node = _actor_nodes.get(actor_id, null)
	if character_node:
		var idle_timer = character_node.get_node_or_null("FrameTimer")
		if idle_timer:
			idle_timer.paused = true

	stop_idle_wiggle(actor_id)
	_attack_playing[actor_id] = true

	# Store idle texture for restoration
	var idle_tex = sprite.texture
	var idle_region_enabled = sprite.region_enabled

	# Swap to attack spritesheet
	sprite.texture = attack_tex
	sprite.region_enabled = true

	# Adjust offset for attack frames (bottom-anchored with per-step correction).
	var idle_offset = sprite.offset
	var first_step = timeline[0]
	_apply_attack_step(sprite, first_step, hf, frame_w, frame_h)

	# Animate through configured timeline
	var frame_timer = Timer.new()
	frame_timer.name = "AttackFrameTimer"
	frame_timer.wait_time = float(first_step.get("duration", 0.08))
	frame_timer.one_shot = false
	frame_timer.autostart = false
	frame_timer.set_meta("step", 0)
	frame_timer.set_meta("impact_fired", false)
	frame_timer.set_meta("impact_step", impact_step)

	var impact_cb = on_impact
	var complete_cb = on_complete
	var restore_tex = idle_tex
	var restore_offset = idle_offset

	frame_timer.timeout.connect(func():
		if _is_shutting_down or not is_instance_valid(frame_timer):
			return
		if not _can_use_scene_root() or sprite == null or not is_instance_valid(sprite):
			frame_timer.stop()
			frame_timer.queue_free()
			_attack_playing.erase(actor_id)
			return
		var step = int(frame_timer.get_meta("step")) + 1
		frame_timer.set_meta("step", step)

		if step >= timeline.size():
			# Animation complete, restore idle
			frame_timer.stop()
			frame_timer.queue_free()
			sprite.texture = restore_tex
			sprite.region_enabled = idle_region_enabled
			sprite.offset = restore_offset
			# Restore idle region_rect to frame 0
			if _idle_configs.has(actor_id):
				var ic = _idle_configs[actor_id]
				var idle_fw = int(restore_tex.get_width()) / ic.get("hframes", 1)
				var idle_fh = int(restore_tex.get_height()) / ic.get("vframes", 1)
				sprite.region_rect = Rect2(0, 0, idle_fw, idle_fh)
			# Resume idle timer
			if character_node:
				var idle_t = character_node.get_node_or_null("FrameTimer")
				if idle_t:
					idle_t.paused = false
			_attack_playing.erase(actor_id)
			if not frame_timer.get_meta("impact_fired"):
				impact_cb.call()
			complete_cb.call()
			return

		var current_step = timeline[step]
		_apply_attack_step(sprite, current_step, hf, frame_w, frame_h)

		# Fire impact callback at configured timeline step
		if step == int(frame_timer.get_meta("impact_step")) and not frame_timer.get_meta("impact_fired"):
			frame_timer.set_meta("impact_fired", true)
			impact_cb.call()
		frame_timer.wait_time = float(current_step.get("duration", 0.08))
	)
	if not _safe_add_to_scene(frame_timer):
		_attack_playing.erase(actor_id)
		sprite.texture = restore_tex
		sprite.region_enabled = idle_region_enabled
		sprite.offset = restore_offset
		on_impact.call()
		on_complete.call()
		return
	frame_timer.start()


func _apply_attack_step(sprite: Sprite2D, step: Dictionary, hframes: int, frame_w: int, frame_h: int) -> void:
	var frame_index = int(step.get("frame", 0))
	var col = frame_index % hframes
	var row = frame_index / hframes
	var y_offset = float(step.get("y_offset", 0.0))
	sprite.offset = Vector2(0, -frame_h + y_offset)
	sprite.region_rect = Rect2(col * frame_w, row * frame_h, frame_w, frame_h)

# ============================================================================
# HIT SHAKE (Damage recoil)
# ============================================================================

func play_hit_shake(actor_id: String) -> void:
	if not _can_use_scene_root():
		return
	var sprite = _actor_sprites.get(actor_id, null)
	if sprite == null:
		return
	_last_hit_at[actor_id] = Time.get_ticks_msec()
	stop_idle_wiggle(actor_id)
	if _shake_tweens.has(actor_id):
		var existing = _shake_tweens[actor_id]
		if existing:
			existing.kill()
	var base_pos = _actor_base_positions.get(actor_id, sprite.position)

	# Determine recoil direction: party members recoil left, enemies recoil right
	var is_party = _is_party_member(actor_id)
	var recoil_dir = -1.0 if is_party else 1.0

	var tween = _scene_root.create_tween()
	# Initial directional recoil (pushed away from attacker)
	tween.tween_property(sprite, "position", base_pos + Vector2(recoil_dir * 8, -2), 0.03).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Lateral shake
	tween.tween_property(sprite, "position:x", base_pos.x - recoil_dir * 4, 0.04)
	tween.tween_property(sprite, "position:y", base_pos.y, 0.03)
	tween.tween_property(sprite, "position:x", base_pos.x + recoil_dir * 2, 0.04)
	# Settle back
	tween.tween_property(sprite, "position", base_pos, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_shake_tweens[actor_id] = tween
	if _battle_manager.battle_state.get("active_character_id", "") == actor_id:
		resume_idle_if_active(actor_id, 0.35)
	else:
		resume_idle_if_active(actor_id, 0.6)


func _is_party_member(actor_id: String) -> bool:
	for member in _battle_manager.battle_state.party:
		if member.id == actor_id:
			return true
	return false


# ============================================================================
# GLOBAL IDLE (Subtle breathing for all actors)
# ============================================================================

func start_global_idle_all() -> void:
	if not _can_use_scene_root():
		return
	for actor_id in _actor_nodes.keys():
		start_global_idle(actor_id)


func start_global_idle(actor_id: String) -> void:
	if not _can_use_scene_root():
		return
	if has_spritesheet_idle(actor_id):
		return
	var actor = _actor_nodes.get(actor_id, null)
	if actor == null:
		return
	if _global_idle_tokens.has(actor_id):
		_global_idle_tokens[actor_id] += 1
	else:
		_global_idle_tokens[actor_id] = 1
	var token = _global_idle_tokens[actor_id]
	var base_pos = _actor_root_positions.get(actor_id, actor.position)
	actor.position = base_pos
	var phase_seed = abs(hash(actor_id)) % 100
	var delay = float(phase_seed) / 100.0 * 1.2
	var timer = _scene_root.get_tree().create_timer(delay)
	timer.timeout.connect(func ():
		if not _can_use_scene_root():
			return
		_global_idle_tick(actor_id, base_pos, token, true)
	)


func _global_idle_tick(actor_id: String, base_pos: Vector2, token: int, to_right: bool) -> void:
	if not _can_use_scene_root():
		return
	if _global_idle_tokens.get(actor_id, 0) != token:
		return
	var actor = _actor_nodes.get(actor_id, null)
	if actor == null:
		return
	actor.position = base_pos + Vector2(1 if to_right else -1, 0)
	var timer = _scene_root.get_tree().create_timer(1.2)
	timer.timeout.connect(func ():
		_global_idle_tick(actor_id, base_pos, token, not to_right)
	)


# ============================================================================
# POISON TINT (Green color cycle)
# ============================================================================

func start_poison_tint(actor_id: String) -> void:
	if not _can_use_scene_root():
		return
	var sprite = _actor_sprites.get(actor_id, null)
	if sprite == null:
		return
	if not (sprite is CanvasItem):
		return
	if _poison_tweens.has(actor_id):
		var existing = _poison_tweens[actor_id]
		if existing:
			existing.kill()
	var visual = sprite as CanvasItem
	var base = _actor_base_self_modulates.get(actor_id, Color(1, 1, 1))
	var tween = _scene_root.create_tween()
	tween.set_loops()
	tween.tween_property(visual, "self_modulate", Color(0.7, 1.0, 0.7), 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(visual, "self_modulate", base, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_poison_tweens[actor_id] = tween


func stop_poison_tint(actor_id: String) -> void:
	if _poison_tweens.has(actor_id):
		var tween = _poison_tweens[actor_id]
		if tween:
			tween.kill()
		_poison_tweens.erase(actor_id)
	var sprite = _actor_sprites.get(actor_id, null)
	if sprite is CanvasItem:
		var base = _actor_base_self_modulates.get(actor_id, Color(1, 1, 1))
		(sprite as CanvasItem).self_modulate = base


# ============================================================================
# DAMAGE FLASH (Red tint on hit)
# ============================================================================

func flash_damage_tint(actor_id: String) -> void:
	if not _can_use_scene_root():
		return
	var sprite = _actor_sprites.get(actor_id, null)
	if sprite == null:
		return
	if not (sprite is CanvasItem):
		return
	var visual = sprite as CanvasItem
	if _flash_tweens.has(actor_id):
		var existing = _flash_tweens[actor_id]
		if existing:
			existing.kill()
	var original = _actor_base_modulates.get(actor_id, visual.modulate)
	visual.modulate = Color(1.0, 0.25, 0.25)
	var tween = _scene_root.create_tween()
	tween.tween_interval(0.06)
	tween.tween_property(visual, "modulate", original, 0.14)
	_flash_tweens[actor_id] = tween
	# Check if character is now KO'd and clean up tweens
	var actor = _battle_manager.get_actor_by_id(actor_id)
	if actor != null and actor.is_ko():
		cleanup_actor_tweens(actor_id)


# ============================================================================
# CLEANUP
# ============================================================================

func cleanup_actor_tweens(actor_id: String) -> void:
	## Stop and clean up all tweens for a KO'd actor to prevent memory leaks
	stop_idle_wiggle(actor_id)
	stop_poison_tint(actor_id)
	if _action_tweens.has(actor_id):
		var tween = _action_tweens[actor_id]
		if tween:
			tween.kill()
		_action_tweens.erase(actor_id)
	if _shake_tweens.has(actor_id):
		var tween = _shake_tweens[actor_id]
		if tween:
			tween.kill()
		_shake_tweens.erase(actor_id)
	if _flash_tweens.has(actor_id):
		var tween = _flash_tweens[actor_id]
		if tween:
			tween.kill()
		_flash_tweens.erase(actor_id)
	if _global_idle_tokens.has(actor_id):
		_global_idle_tokens.erase(actor_id)
	_float_lane_index.erase(actor_id)
	_float_lane_last_ms.erase(actor_id)
	_attack_playing.erase(actor_id)
