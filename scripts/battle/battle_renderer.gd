extends RefCounted
class_name BattleRenderer

## BattleRenderer - Manages creation of battle visuals (characters, bosses, background)
## Extracted from battle_scene.gd for single-responsibility design

const AnimatedHealthBarClass = preload("res://scripts/ui/animated_health_bar.gd")

# Constants
const ACTOR_SCALE := 2.0
const BOSS_SCALE := 2.0
const ACTIVE_NAME_COLOR := Color(1.0, 0.9, 0.4)
const INACTIVE_NAME_COLOR := Color(1, 1, 1)
const ACTIVE_NAME_FONT_SIZE := 16
const INACTIVE_NAME_FONT_SIZE := 13

const HERO_POSITIONS := {
	"kairus": Vector2(735, 326),
	"ludwig": Vector2(607, 250),
	"ninos": Vector2(802, 208),
	"catraca": Vector2(895, 280)
}
const BOSS_POSITION := Vector2(286, 248)

const CHARACTER_SPRITES := {
	"kairus": "res://assets/sprites/characters/kairus_sprite_main.png",
	"catraca": "res://assets/sprites/characters/catraca_sprite_main.png",
	"ninos": "res://assets/sprites/characters/ninos_sprite_main.png",
	"ludwig": "res://assets/sprites/characters/Ludwig_sprite_main.png"
}
# Spritesheet configs: actor_id -> {path, hframes, vframes, fps, scale}
# Characters with spritesheets use frame animation instead of static sprites
const IDLE_SPRITESHEETS := {
	"kairus": {
		"path": "res://assets/sprites/characters/kairus-idle-anim-2.png",
		"hframes": 6, "vframes": 1, "fps": 6, "scale": 0.40
	}
}
const ATTACK_SPRITESHEETS := {
	"kairus": {
		"path": "res://assets/sprites/characters/kairus-attack-anim.png",
		"hframes": 4, "vframes": 3, "fps": 14, "impact_frame": 8
	}
}
const BOSS_SPRITE := "res://assets/sprites/characters/marcus_sprite_main.png"
const BACKGROUND_SPRITE := "res://assets/sprites/environment/env_sprite_dungeon_corridor.png"

# External references
var _scene_root: Node
var pixel_font: Font

# Output dictionaries (populated during creation)
var actor_sprites: Dictionary = {}
var actor_nodes: Dictionary = {}
var actor_name_labels: Dictionary = {}
var actor_base_positions: Dictionary = {}
var actor_base_modulates: Dictionary = {}
var actor_base_self_modulates: Dictionary = {}
var actor_root_positions: Dictionary = {}

# Boss HP bar references
var boss_hp_bar: AnimatedHealthBar


func setup(scene_root: Node) -> void:
	_scene_root = scene_root


func create_background() -> void:
	if not ResourceLoader.exists(BACKGROUND_SPRITE):
		return
	var bg = Sprite2D.new()
	var tex = load(BACKGROUND_SPRITE)
	bg.texture = tex
	bg.position = Vector2(0, 0)
	bg.centered = false
	bg.z_index = -10
	_scene_root.add_child(bg)


func create_character(data: Dictionary) -> Character:
	var character = Character.new()
	character.setup(data)

	var actor_id = data.get("id", "")
	if data.has("position"):
		character.position = data["position"]
	character.z_index = int(character.position.y)

	actor_nodes[actor_id] = character
	actor_root_positions[actor_id] = character.position

	# Add Visuals — check for spritesheet first, fall back to static sprite
	var sheet_config = IDLE_SPRITESHEETS.get(actor_id, {})
	var sprite_path = ""
	var use_spritesheet = false
	if not sheet_config.is_empty() and ResourceLoader.exists(sheet_config.get("path", "")):
		sprite_path = sheet_config["path"]
		use_spritesheet = true
	else:
		sprite_path = CHARACTER_SPRITES.get(actor_id, "")
	var sprite_size = Vector2(40, 40)

	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		var sprite = Sprite2D.new()
		sprite.name = "Visual"
		sprite.texture = load(sprite_path)
		sprite.centered = false
		sprite.position = Vector2(0, 0)

		if use_spritesheet:
			var sheet_scale = sheet_config.get("scale", 0.35)
			sprite.scale = Vector2(sheet_scale, sheet_scale)
			# Use region_rect for pixel-perfect frames (avoids fractional hframes)
			var hf = sheet_config.get("hframes", 1)
			var vf = sheet_config.get("vframes", 1)
			var tex_w = int(sprite.texture.get_width())
			var tex_h = int(sprite.texture.get_height())
			var frame_w = tex_w / hf  # integer division — no fractional bleed
			var frame_h = tex_h / vf
			sprite.region_enabled = true
			sprite.region_rect = Rect2(0, 0, frame_w, frame_h)
			# Bottom-anchor: offset so feet (frame bottom) stay fixed
			sprite.offset = Vector2(0, -frame_h)
			# Place feet at same Y as static sprite foot line
			var static_path = CHARACTER_SPRITES.get(actor_id, "")
			var foot_y := 64.0 * ACTOR_SCALE  # fallback: default 64px sprite at 2x
			if static_path != "" and ResourceLoader.exists(static_path):
				var static_tex = load(static_path)
				foot_y = static_tex.get_height() * ACTOR_SCALE
			sprite.position = Vector2(0, foot_y)
			sprite_size = Vector2(frame_w * sheet_scale, foot_y)
			# Start frame cycling via Timer (uses region_rect per frame)
			_start_frame_animation(character, sprite, sheet_config)
		else:
			sprite.scale = Vector2(ACTOR_SCALE, ACTOR_SCALE)
			if sprite.texture:
				sprite_size = sprite.texture.get_size() * ACTOR_SCALE

		actor_base_modulates[actor_id] = sprite.modulate
		character.add_child(sprite)
		actor_sprites[actor_id] = sprite
		actor_base_positions[actor_id] = sprite.position
		actor_base_self_modulates[actor_id] = sprite.self_modulate
	else:
		var color = data.get("color", Color.WHITE)
		var visual = ColorRect.new()
		visual.name = "Visual"
		visual.size = Vector2(40, 40)
		visual.position = Vector2(-20, -20)
		visual.color = color
		character.add_child(visual)
		sprite_size = visual.size
		actor_sprites[actor_id] = visual
		actor_base_modulates[actor_id] = visual.modulate
		actor_base_positions[actor_id] = visual.position
		actor_base_self_modulates[actor_id] = visual.self_modulate

	# Add Name Label
	var name_lbl = Label.new()
	name_lbl.text = data.get("display_name", "")
	name_lbl.position = Vector2(0, sprite_size.y + 4)
	name_lbl.size = Vector2(max(sprite_size.x, 80), 20)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if pixel_font:
		name_lbl.add_theme_font_override("font", pixel_font)
	apply_name_style(name_lbl, false)
	character.add_child(name_lbl)
	actor_name_labels[actor_id] = name_lbl

	_scene_root.add_child(character)
	return character


func create_boss(data: Dictionary) -> Boss:
	var boss = Boss.new()
	boss.setup(data)

	var actor_id = data.get("id", "")
	if data.has("position"):
		boss.position = data["position"]
	boss.z_index = int(boss.position.y)

	actor_nodes[actor_id] = boss
	actor_root_positions[actor_id] = boss.position

	# Add Visuals
	if ResourceLoader.exists(BOSS_SPRITE):
		var sprite = Sprite2D.new()
		sprite.name = "Visual"
		sprite.texture = load(BOSS_SPRITE)
		var tex_size = sprite.texture.get_size()
		sprite.centered = false
		sprite.position = Vector2(0, 0)
		sprite.scale = Vector2(BOSS_SCALE, BOSS_SCALE)
		actor_base_modulates[actor_id] = sprite.modulate
		boss.add_child(sprite)
		actor_sprites[actor_id] = sprite
		actor_base_positions[actor_id] = sprite.position
		actor_base_self_modulates[actor_id] = sprite.self_modulate

		var scaled_size = tex_size * BOSS_SCALE
		_create_boss_name_label(boss, data, scaled_size, actor_id)
		_create_boss_hp_bar(boss, data)
	else:
		var color = data.get("color", Color.BLACK)
		var visual = ColorRect.new()
		visual.name = "Visual"
		visual.size = Vector2(80, 80)
		visual.position = Vector2(0, 0)
		visual.color = color
		boss.add_child(visual)
		actor_sprites[actor_id] = visual
		actor_base_modulates[actor_id] = visual.modulate
		actor_base_positions[actor_id] = visual.position
		actor_base_self_modulates[actor_id] = visual.self_modulate

		_create_boss_name_label(boss, data, visual.size, actor_id)
		_create_boss_hp_bar(boss, data)

	_scene_root.add_child(boss)
	return boss


func _create_boss_name_label(boss: Boss, data: Dictionary, visual_size: Vector2, actor_id: String) -> void:
	var name_lbl = Label.new()
	name_lbl.text = data.get("display_name", "")
	name_lbl.position = Vector2(0, visual_size.y + 6)
	name_lbl.size = Vector2(max(visual_size.x, 120), 20)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if pixel_font:
		name_lbl.add_theme_font_override("font", pixel_font)
	apply_name_style(name_lbl, false)
	boss.add_child(name_lbl)
	actor_name_labels[actor_id] = name_lbl


func _create_boss_hp_bar(boss: Boss, data: Dictionary) -> void:
	var name_lbl = actor_name_labels.get(data.get("id", ""), null)
	if name_lbl == null:
		return

	boss_hp_bar = AnimatedHealthBarClass.new()
	boss_hp_bar.bar_size = Vector2(name_lbl.size.x, 26)
	boss_hp_bar.use_odometer = false
	boss_hp_bar.corner_radius = 8
	boss_hp_bar.position = Vector2(name_lbl.position.x, name_lbl.position.y + name_lbl.size.y + 2)
	boss.add_child(boss_hp_bar)


func apply_name_style(label: Label, is_active: bool) -> void:
	if is_active:
		label.modulate = ACTIVE_NAME_COLOR
		label.add_theme_font_size_override("font_size", ACTIVE_NAME_FONT_SIZE)
	else:
		label.modulate = INACTIVE_NAME_COLOR
		label.add_theme_font_size_override("font_size", INACTIVE_NAME_FONT_SIZE)


func get_actor_sprite(actor_id: String) -> Node:
	return actor_sprites.get(actor_id, null)


func get_actor_node(actor_id: String) -> Node:
	return actor_nodes.get(actor_id, null)


func get_actor_position(actor_id: String) -> Vector2:
	return actor_root_positions.get(actor_id, Vector2.ZERO)


func get_name_label(actor_id: String) -> Label:
	return actor_name_labels.get(actor_id, null)


## Start frame cycling on a spritesheet sprite via region_rect.
## Uses integer-division frame widths to avoid fractional pixel bleed.
func _start_frame_animation(parent: Node, sprite: Sprite2D, config: Dictionary) -> void:
	var hf = config.get("hframes", 1)
	var vf = config.get("vframes", 1)
	var total_frames = hf * vf
	var fps = config.get("fps", 6)
	var tex_w = int(sprite.texture.get_width())
	var tex_h = int(sprite.texture.get_height())
	var frame_w = tex_w / hf
	var frame_h = tex_h / vf
	var timer = Timer.new()
	timer.name = "FrameTimer"
	timer.wait_time = 1.0 / fps
	timer.one_shot = false
	timer.autostart = true
	# Store frame counter on the timer node (closures can't mutate local vars)
	timer.set_meta("frame", 0)
	timer.timeout.connect(func():
		var f = (timer.get_meta("frame") + 1) % total_frames
		timer.set_meta("frame", f)
		var col = f % hf
		var row = f / hf
		sprite.region_rect = Rect2(col * frame_w, row * frame_h, frame_w, frame_h)
	)
	parent.add_child(timer)
