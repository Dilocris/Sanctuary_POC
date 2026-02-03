extends RefCounted
class_name BattleRenderer

## BattleRenderer - Manages creation of battle visuals (characters, bosses, background)
## Extracted from battle_scene.gd for single-responsibility design

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
const BOSS_SPRITE := "res://assets/sprites/characters/marcus_sprite_main.png"
const BACKGROUND_SPRITE := "res://assets/sprites/environment/env_sprite_dungeon_corridor.png"

# External references
var _scene_root: Node

# Output dictionaries (populated during creation)
var actor_sprites: Dictionary = {}
var actor_nodes: Dictionary = {}
var actor_name_labels: Dictionary = {}
var actor_base_positions: Dictionary = {}
var actor_base_modulates: Dictionary = {}
var actor_base_self_modulates: Dictionary = {}
var actor_root_positions: Dictionary = {}

# Boss HP bar references
var boss_hp_bar: ProgressBar
var boss_hp_bar_label: Label
var boss_hp_fill_style: StyleBoxFlat


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

	actor_nodes[actor_id] = character
	actor_root_positions[actor_id] = character.position

	# Add Visuals
	var sprite_path = CHARACTER_SPRITES.get(actor_id, "")
	var sprite_size = Vector2(40, 40)

	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		var sprite = Sprite2D.new()
		sprite.name = "Visual"
		sprite.texture = load(sprite_path)
		sprite.centered = false
		sprite.position = Vector2(0, 0)
		sprite.scale = Vector2(ACTOR_SCALE, ACTOR_SCALE)
		actor_base_modulates[actor_id] = sprite.modulate
		if sprite.texture:
			sprite_size = sprite.texture.get_size() * ACTOR_SCALE
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
	apply_name_style(name_lbl, false)
	boss.add_child(name_lbl)
	actor_name_labels[actor_id] = name_lbl


func _create_boss_hp_bar(boss: Boss, data: Dictionary) -> void:
	var name_lbl = actor_name_labels.get(data.get("id", ""), null)
	if name_lbl == null:
		return

	boss_hp_bar = ProgressBar.new()
	boss_hp_bar.min_value = 0
	boss_hp_bar.max_value = data.get("stats", {}).get("hp_max", 1)
	boss_hp_bar.value = boss_hp_bar.max_value
	boss_hp_bar.show_percentage = false
	boss_hp_bar.position = Vector2(name_lbl.position.x, name_lbl.position.y + name_lbl.size.y + 2)
	boss_hp_bar.size = Vector2(name_lbl.size.x, 26)

	boss_hp_bar_label = Label.new()
	boss_hp_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_hp_bar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boss_hp_bar_label.anchor_right = 1.0
	boss_hp_bar_label.anchor_bottom = 1.0
	boss_hp_bar_label.offset_left = 0.0
	boss_hp_bar_label.offset_top = 0.0
	boss_hp_bar_label.offset_right = 0.0
	boss_hp_bar_label.offset_bottom = 0.0
	boss_hp_bar.add_child(boss_hp_bar_label)

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	bg_style.corner_radius_top_left = 8
	bg_style.corner_radius_top_right = 8
	bg_style.corner_radius_bottom_left = 8
	bg_style.corner_radius_bottom_right = 8

	boss_hp_fill_style = StyleBoxFlat.new()
	boss_hp_fill_style.bg_color = Color(0.2, 0.8, 0.2)
	boss_hp_fill_style.corner_radius_top_left = 8
	boss_hp_fill_style.corner_radius_top_right = 8
	boss_hp_fill_style.corner_radius_bottom_left = 8
	boss_hp_fill_style.corner_radius_bottom_right = 8

	boss_hp_bar.add_theme_stylebox_override("background", bg_style)
	boss_hp_bar.add_theme_stylebox_override("fill", boss_hp_fill_style)
	boss_hp_bar.add_theme_stylebox_override("fg", boss_hp_fill_style)
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
