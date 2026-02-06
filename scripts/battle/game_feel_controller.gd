extends RefCounted
class_name GameFeelController

## GameFeelController - Centralized controller for screen-space combat feedback effects.
## Includes camera shake, hit stop, screen flash, and sprite pop.

# Master toggles (for accessibility)
var shake_enabled: bool = true
var hit_stop_enabled: bool = true
var screen_flash_enabled: bool = true
var sprite_pop_enabled: bool = true

# Camera shake settings
var light_shake_amplitude: float = 2.0
var heavy_shake_amplitude: float = 5.0
var shake_duration: float = 0.15

# Hit stop settings (in frames at 60fps)
var light_hit_frames: int = 2
var heavy_hit_frames: int = 5

# Screen flash settings
var flash_duration: float = 0.12
var flash_color: Color = Color(1.0, 1.0, 1.0, 0.12)
var damage_flash_color: Color = Color(1.0, 0.95, 0.95, 0.08)

# Sprite pop settings
var pop_scale: float = 1.03  # 3% scale increase
var pop_duration: float = 0.1

# Camera nudge settings
var nudge_enabled: bool = true
var nudge_distance: float = 3.0
var nudge_duration: float = 0.08

# Heavy hit threshold (damage amount that triggers heavy effects)
var heavy_hit_threshold: int = 50

# Internal references
var _scene_root: Node
var _battle_manager: BattleManager
var _flash_overlay: ColorRect
var _flash_layer: CanvasLayer
var _shake_tween: Tween
var _original_root_position: Vector2 = Vector2.ZERO


func setup(scene_root: Node, battle_manager: BattleManager) -> void:
	_scene_root = scene_root
	_battle_manager = battle_manager
	_create_flash_overlay()
	_original_root_position = _scene_root.position if _scene_root is Node2D else Vector2.ZERO


func _create_flash_overlay() -> void:
	# Create a CanvasLayer for the flash overlay (above most content)
	_flash_layer = CanvasLayer.new()
	_flash_layer.layer = 50
	_scene_root.add_child(_flash_layer)

	# Create the flash rectangle
	_flash_overlay = ColorRect.new()
	_flash_overlay.color = Color(1, 1, 1, 0)
	_flash_overlay.size = Vector2(1152, 648)  # Match typical game resolution
	_flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_layer.add_child(_flash_overlay)


## Trigger effects based on damage amount.
## Call this from battle_scene.gd when damage is dealt.
func on_damage_dealt(damage: int, target_sprite: Node2D = null) -> void:
	if damage <= 0:
		return

	var is_heavy = damage >= heavy_hit_threshold

	# Directional camera nudge toward target
	if target_sprite and _scene_root is Node2D:
		var screen_center = Vector2(576, 324)  # Half of 1152x648
		var direction = (target_sprite.global_position - screen_center).normalized()
		var dist = nudge_distance * (2.0 if is_heavy else 1.0)
		nudge_camera(direction, dist)

	# Camera shake
	if is_heavy:
		shake_camera(heavy_shake_amplitude, shake_duration)
	else:
		shake_camera(light_shake_amplitude, shake_duration * 0.7)

	# Screen flash (only on heavy hits)
	if is_heavy:
		flash_screen(damage_flash_color, flash_duration)

	# Hit stop
	if is_heavy:
		apply_hit_stop(heavy_hit_frames)
	elif damage > 20:  # Light hit stop for medium damage
		apply_hit_stop(light_hit_frames)

	# Sprite pop on target
	if target_sprite and is_heavy:
		pop_sprite(target_sprite)


## Shake the camera/scene with random offsets.
func shake_camera(amplitude: float, duration: float) -> void:
	if not shake_enabled or _scene_root == null:
		return

	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()

	if not _scene_root is Node2D:
		return

	_shake_tween = _scene_root.create_tween()
	var steps = int(duration / 0.02)

	for i in range(steps):
		var decay = 1.0 - (float(i) / float(steps))
		var offset = Vector2(
			randf_range(-1, 1) * amplitude * decay,
			randf_range(-1, 1) * amplitude * decay
		)
		_shake_tween.tween_property(_scene_root, "position", _original_root_position + offset, 0.02)

	# Return to original position
	_shake_tween.tween_property(_scene_root, "position", _original_root_position, 0.02)


## Short positional nudge toward the impact direction, then snap back.
func nudge_camera(direction: Vector2, distance: float = -1.0) -> void:
	if not nudge_enabled or _scene_root == null or not _scene_root is Node2D:
		return
	if distance < 0:
		distance = nudge_distance
	var offset = direction * distance
	var nudge_tween = _scene_root.create_tween()
	nudge_tween.tween_property(_scene_root, "position", _original_root_position + offset, nudge_duration * 0.4)
	nudge_tween.tween_property(_scene_root, "position", _original_root_position, nudge_duration * 0.6).set_ease(Tween.EASE_OUT)


## Flash the screen with a color overlay.
func flash_screen(color: Color, duration: float) -> void:
	if not screen_flash_enabled or _flash_overlay == null:
		return

	_flash_overlay.color = color
	var tween = _scene_root.create_tween()
	tween.tween_property(_flash_overlay, "color:a", 0.0, duration)


## Pause the game briefly for impact (hit stop / freeze frame).
func apply_hit_stop(frames: int) -> void:
	if not hit_stop_enabled:
		return

	var pause_time = float(frames) / 60.0
	Engine.time_scale = 0.0

	# Use a timer that ignores time scale to restore normal speed
	var timer = _scene_root.get_tree().create_timer(pause_time, true, false, true)
	timer.timeout.connect(_restore_time_scale)


func _restore_time_scale() -> void:
	Engine.time_scale = 1.0


## Scale a sprite up briefly for impact feedback.
func pop_sprite(sprite: Node2D, scale_multiplier: float = -1.0) -> void:
	if not sprite_pop_enabled or sprite == null:
		return

	if scale_multiplier < 0:
		scale_multiplier = pop_scale

	var original_scale = sprite.scale
	var pop_tween = _scene_root.create_tween()
	pop_tween.tween_property(sprite, "scale", original_scale * scale_multiplier, pop_duration * 0.4)
	pop_tween.tween_property(sprite, "scale", original_scale, pop_duration * 0.6)


## Trigger a critical hit effect (stronger than heavy).
func on_critical_hit(_damage: int, target_sprite: Node2D = null) -> void:
	# Extra strong effects for crits
	shake_camera(heavy_shake_amplitude * 1.5, shake_duration * 1.2)
	flash_screen(Color(1.0, 0.95, 0.8, 0.3), flash_duration * 1.2)
	apply_hit_stop(heavy_hit_frames + 2)

	if target_sprite:
		pop_sprite(target_sprite, pop_scale * 1.02)


## Trigger boss phase transition effect.
func on_phase_transition() -> void:
	shake_camera(heavy_shake_amplitude * 2.0, 0.3)
	flash_screen(Color(0.8, 0.2, 0.2, 0.25), 0.25)


## Brief slow-motion dip when an actor is KO'd (finishing blow).
func on_finishing_blow(target_sprite: Node2D = null) -> void:
	# Dramatic slowdown
	Engine.time_scale = 0.3
	flash_screen(Color(1.0, 1.0, 1.0, 0.15), 0.3)
	shake_camera(heavy_shake_amplitude * 1.3, 0.2)

	if target_sprite:
		pop_sprite(target_sprite, pop_scale * 1.04)

	# Restore after brief pause (using process-independent timer)
	var timer = _scene_root.get_tree().create_timer(0.35, true, false, true)
	timer.timeout.connect(_restore_time_scale)


## Trigger limit break activation effect.
func on_limit_break() -> void:
	flash_screen(Color(1.0, 0.8, 0.4, 0.3), 0.2)
	apply_hit_stop(4)


## Clean up when battle ends.
func cleanup() -> void:
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	Engine.time_scale = 1.0
	if _scene_root is Node2D:
		_scene_root.position = _original_root_position
