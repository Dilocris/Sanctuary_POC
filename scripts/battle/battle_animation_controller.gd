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


# ============================================================================
# FLOATING TEXT
# ============================================================================

func create_floating_text(pos: Vector2, text: String, color: Color) -> void:
	var label = Label.new()
	label.text = text
	label.modulate = color
	label.position = pos + Vector2(0, -50)
	label.add_theme_font_size_override("font_size", 24)
	_scene_root.add_child(label)

	var tween = _scene_root.create_tween()
	tween.parallel().tween_property(label, "position:y", label.position.y - 50, 1.0)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)


func spawn_damage_numbers(target_id: String, damages: Array) -> void:
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
			create_damage_text(pos, str(dmg_val), dmg_val)
		)


const HEAVY_DAMAGE_THRESHOLD := 50
const NORMAL_DAMAGE_FONT := 32
const HEAVY_DAMAGE_FONT := 44

func create_damage_text(pos: Vector2, text: String, damage_value: int = 0) -> void:
	var is_heavy = damage_value >= HEAVY_DAMAGE_THRESHOLD
	var font_size = HEAVY_DAMAGE_FONT if is_heavy else NORMAL_DAMAGE_FONT
	var color = Color(1.0, 0.3, 0.1) if is_heavy else Color(1.0, 0.55, 0.1)

	var label = Label.new()
	label.text = text
	label.modulate = color
	label.position = pos + Vector2(0, -64)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 3 if is_heavy else 2)
	_scene_root.add_child(label)

	var tween = _scene_root.create_tween()
	if is_heavy:
		# Pop-in scale effect for heavy hits
		label.pivot_offset = label.size / 2.0
		label.scale = Vector2(1.3, 1.3)
		tween.parallel().tween_property(label, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(label, "position:y", label.position.y - 50, 1.0)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)


func create_status_tick_text(pos: Vector2, text: String, color: Color) -> void:
	var label = Label.new()
	label.text = text
	label.modulate = color
	label.position = pos + Vector2(0, -40)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 2)
	_scene_root.add_child(label)
	var tween = _scene_root.create_tween()
	tween.parallel().tween_property(label, "position:y", label.position.y - 30, 0.9)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.9)
	tween.tween_callback(label.queue_free)


# ============================================================================
# IDLE WIGGLE (Active character sway)
# ============================================================================

func start_idle_wiggle(actor_id: String) -> void:
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
	var timer = _scene_root.get_tree().create_timer(delay)
	timer.timeout.connect(func ():
		if _battle_manager.battle_state.get("active_character_id", "") == actor_id:
			start_idle_wiggle(actor_id)
	)


func delay_idle_after_recent_hit(actor_id: String) -> void:
	if _shake_tweens.has(actor_id):
		var timer = _scene_root.get_tree().create_timer(0.15)
		timer.timeout.connect(func ():
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
# HIT SHAKE (Damage recoil)
# ============================================================================

func play_hit_shake(actor_id: String) -> void:
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
	for actor_id in _actor_nodes.keys():
		start_global_idle(actor_id)


func start_global_idle(actor_id: String) -> void:
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
		_global_idle_tick(actor_id, base_pos, token, true)
	)


func _global_idle_tick(actor_id: String, base_pos: Vector2, token: int, to_right: bool) -> void:
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
