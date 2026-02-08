extends Control
class_name BattleMenu

signal action_selected(action_id: String)
@warning_ignore("unused_signal")
signal menu_canceled
signal action_blocked(reason: String)
signal menu_changed(menu_items: Array)

enum MenuState { MAIN, SUBMENU, TARGETING, DISABLED }
var current_state = MenuState.DISABLED

var active_actor: Character
var main_options = ["Attack", "Skill", "Defend", "Item"]
var current_selection_index: int = 0
const SKIN_ROOT := "res://assets/ui/battle_skin/"

# Mock UI Elements (Will be nodes in real scene)
var action_list_container: VBoxContainer
@onready var command_panel: Panel = $Panel
@onready var action_list_scroll: ScrollContainer = $Panel/ActionListScroll
@onready var action_list_node = $Panel/ActionListScroll/ActionList
@onready var name_separator: TextureRect = $Panel/NameSeparator
@onready var description_panel: Panel = $DescriptionPanel
@onready var description_label = $DescriptionPanel/Label
@onready var actor_label = $Panel/ActorName

var menu_items: Array = []
var disabled_actions: Dictionary = {}
var input_block_until_ms: int = 0
var cursor_nodes: Array = []
var label_nodes: Array = []
var row_panels: Array = []
var pixel_font: Font
var _skin_cursor: Texture2D
var _row_style_idle: StyleBox
var _row_style_selected: StyleBox
var _ornament_tl: Texture2D
var _ornament_tr: Texture2D
var _ornament_bl: Texture2D
var _ornament_br: Texture2D

func _ready() -> void:
	visible = false
	_apply_skin()
	if action_list_scroll:
		action_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		action_list_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		action_list_scroll.clip_contents = true

func setup(actor: Character) -> void:
	active_actor = actor
	current_state = MenuState.MAIN
	current_selection_index = 0
	visible = true
	if actor_label:
		actor_label.text = actor.display_name.to_upper()
		if pixel_font:
			actor_label.add_theme_font_override("font", pixel_font)
		actor_label.add_theme_font_size_override("font_size", 13)
		actor_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	if description_label:
		if pixel_font:
			description_label.add_theme_font_override("font", pixel_font)
		description_label.add_theme_font_size_override("font_size", 12)
		description_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		description_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		description_label.add_theme_constant_override("outline_size", 2)
	_build_main_menu()
	_update_selection()
	_block_input(150)


func set_enabled(enabled: bool) -> void:
	if enabled:
		current_state = MenuState.MAIN
		visible = true
		_block_input(100)
	else:
		current_state = MenuState.DISABLED
		visible = false


func open_magic_submenu() -> void:
	current_state = MenuState.SUBMENU
	_build_submenu("SKILL_SUB")
	_block_input(150)

func _build_main_menu() -> void:
	menu_items.clear()
	if active_actor.limit_gauge >= 100:
		var limit_id = ""
		match active_actor.id:
			"kairus": limit_id = ActionIds.KAI_LIMIT
			"ludwig": limit_id = ActionIds.LUD_LIMIT
			"ninos": limit_id = ActionIds.NINOS_LIMIT
			"catraca": limit_id = ActionIds.CAT_LIMIT
		var limit_desc = ""
		match active_actor.id:
			"kairus": limit_desc = "Inferno Fist: 5 rapid strikes + devastating finisher."
			"ludwig": limit_desc = "Dragonfire Roar: Rally allies (+ATK) and charm foes."
			"ninos": limit_desc = "Siren's Call: Heal all allies, cleanse, and grant Regen."
			"catraca": limit_desc = "Genie's Wrath: Next 3 spells cost 0 MP and deal 1.5x damage."
		if limit_id != "":
			menu_items.append({"label": "Limit Break", "id": limit_id, "desc": limit_desc})
	# Common Attack (Catraca uses Fire Bolt as her basic)
	if active_actor.id == "catraca":
		menu_items.append({"label": "Fire Bolt", "id": ActionIds.CAT_FIRE_BOLT, "desc": "Single-target fire damage."})
	else:
		menu_items.append({"label": "Attack", "id": "ATTACK", "desc": "Basic physical attack."})

	# Class Specific Submenu
	match active_actor.id:
		"kairus":
			menu_items.append({"label": "Skills", "id": "SKILL_SUB", "desc": "Monk abilities. Costs Ki."})
		"ludwig":
			menu_items.append({"label": "Maneuvers", "id": "SKILL_SUB", "desc": "Battle maneuvers. Costs Dice."})
		"ninos":
			menu_items.append({"label": "Abilities", "id": "SKILL_SUB", "desc": "Bardic spells and inspiration."})
		"catraca":
			menu_items.append({"label": "Metamagic", "id": "META_SUB", "desc": "Sorcery modifiers. Costs SP."})
			menu_items.append({"label": "Magic", "id": "SKILL_SUB", "desc": "Sorcerous spells. Costs MP."})

	# Common Defend/Guard
	if active_actor.id == "ludwig":
		menu_items.append({"label": "Guard Stance", "id": "GUARD_TOGGLE", "desc": "Toggle: +DEF, half dmg, enables Riposte. No Attacks/Maneuvers."})
	else:
		menu_items.append({"label": "Defend", "id": "DEFEND", "desc": "Skip turn, reduce damage taken."})
		
	# Item system (TODO: implement inventory/consumables)
	# menu_items.append({"label": "Item", "id": "ITEM_SUB", "desc": "Use consumables."})
	
	_render_menu_items()

func _build_submenu(category: String) -> void:
	menu_items.clear()
	match active_actor.id:
		"kairus":
			if category == "SKILL_SUB":
				menu_items.append({"label": "Flurry of Blows", "id": ActionIds.KAI_FLURRY, "desc": "2 Ki. Multi-hit physical attack."})
				menu_items.append({"label": "Stunning Strike", "id": ActionIds.KAI_STUN_STRIKE, "desc": "1 Ki. Strike with chance to stun."})
				menu_items.append({"label": "Fire Imbue", "id": ActionIds.KAI_FIRE_IMBUE, "desc": "Toggle. Add fire dmg to attacks; drains 1 Ki/turn."})
		"ludwig":
			if category == "SKILL_SUB":
				menu_items.append({"label": "Lunging Attack", "id": ActionIds.LUD_LUNGING, "desc": "1 Dice. Reach attack with bonus damage."})
				menu_items.append({"label": "Precision Strike", "id": ActionIds.LUD_PRECISION, "desc": "1 Dice. High damage, ignores evasion."})
				menu_items.append({"label": "Shield Bash", "id": ActionIds.LUD_SHIELD_BASH, "desc": "1 Dice. Strike with chance to stun."})
				menu_items.append({"label": "Rally", "id": ActionIds.LUD_RALLY, "desc": "1 Dice. Heal an ally."})
				menu_items.append({"label": "Taunt", "id": ActionIds.LUD_TAUNT, "desc": "1 Dice. Force enemy single-target actions to target Ludwig for 2 turns."})
		"ninos":
			if category == "SKILL_SUB":
				menu_items.append({"label": "Inspire (Atk)", "id": ActionIds.NINOS_INSPIRE_ATTACK, "desc": "1 Insp. Ally's next attack deals +1d8 bonus dmg."})
				menu_items.append({"label": "Vicious Mockery", "id": ActionIds.NINOS_VICIOUS_MOCKERY, "desc": "5 MP. Damage target and apply ATK Down."})
				menu_items.append({"label": "Healing Word", "id": ActionIds.NINOS_HEALING_WORD, "desc": "6 MP. Restore HP to an ally."})
				menu_items.append({"label": "Bless", "id": ActionIds.NINOS_BLESS, "desc": "10 MP. All allies gain bonus damage for 2 turns."})
				menu_items.append({"label": "Cleanse", "id": ActionIds.NINOS_CLEANSE, "desc": "8 MP. Remove cleansable debuffs from an ally and heal 20 HP."})
		"catraca":
			if category == "SKILL_SUB":
				menu_items.append({"label": "Fireball", "id": ActionIds.CAT_FIREBALL, "desc": "18 MP. Fire damage to all enemies."})
				menu_items.append({"label": "Mage Armor", "id": ActionIds.CAT_MAGE_ARMOR, "desc": "4 MP. Boost DEF for 3 turns."})
			elif category == "META_SUB":
				menu_items.append({"label": "Quicken Spell", "id": ActionIds.CAT_METAMAGIC_QUICKEN, "desc": "2 SP. Gain an extra action after next spell."})
				menu_items.append({"label": "Twin Spell", "id": ActionIds.CAT_METAMAGIC_TWIN, "desc": "1 SP. Next single-target spell hits 2 targets."})
	
	_render_menu_items()

func _render_menu_items() -> void:
	for child in action_list_node.get_children():
		child.queue_free()
	cursor_nodes.clear()
	label_nodes.clear()
	row_panels.clear()

	if action_list_scroll:
		var list_width := 190.0
		if action_list_scroll.size.x > 0.0:
			list_width = maxi(0.0, action_list_scroll.size.x - 4.0)
		action_list_node.custom_minimum_size = Vector2(list_width, 0.0)
	
	for item in menu_items:
		var row_panel = PanelContainer.new()
		row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_panel.custom_minimum_size = Vector2(0, 21)
		row_panel.add_theme_stylebox_override("panel", _row_style_idle)
		action_list_node.add_child(row_panel)
		row_panels.append(row_panel)

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_panel.add_child(row)

		var cursor = TextureRect.new()
		cursor.texture = _skin_cursor
		cursor.custom_minimum_size = Vector2(16, 16)
		cursor.size = Vector2(16, 16)
		cursor.stretch_mode = TextureRect.STRETCH_SCALE
		cursor.modulate = Color(0.92, 0.84, 0.56, 0.95)
		cursor.visible = false
		row.add_child(cursor)
		cursor_nodes.append(cursor)

		var label = Label.new()
		var label_text = item["label"]
		if disabled_actions.has(item["id"]):
			label_text += " (X)"
		label.text = label_text.to_upper()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.clip_text = true
		if pixel_font:
			label.add_theme_font_override("font", pixel_font)
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		label.add_theme_constant_override("outline_size", 2)
		row.add_child(label)
		label_nodes.append(label)
	
	if menu_items.is_empty():
		current_selection_index = 0
	else:
		current_selection_index = clamp(current_selection_index, 0, menu_items.size() - 1)
	_update_selection()
	emit_signal("menu_changed", menu_items)

func _update_selection() -> void:
	if menu_items.is_empty(): 
		description_label.text = ""
		return
	current_selection_index = clamp(current_selection_index, 0, menu_items.size() - 1)
	
	var idx = 0
	for label in label_nodes:
		if idx >= menu_items.size():
			break
		var item_id = menu_items[idx].get("id", "")
		if idx == current_selection_index:
			label.modulate = Color(0.95, 0.88, 0.62)
			if idx < cursor_nodes.size():
				cursor_nodes[idx].visible = true
			if idx < row_panels.size():
				row_panels[idx].add_theme_stylebox_override("panel", _row_style_selected)
		else:
			if idx < cursor_nodes.size():
				cursor_nodes[idx].visible = false
			if idx < row_panels.size():
				row_panels[idx].add_theme_stylebox_override("panel", _row_style_idle)
			if disabled_actions.has(item_id):
				label.modulate = Color(0.6, 0.6, 0.6)
			else:
				label.modulate = Color(1, 1, 1)
		idx += 1
	
	description_label.text = menu_items[current_selection_index].get("desc", "")
	if action_list_scroll and current_selection_index < row_panels.size():
		action_list_scroll.ensure_control_visible(row_panels[current_selection_index])

func _input(event: InputEvent) -> void:
	if not visible or current_state == MenuState.DISABLED:
		return
	if _is_input_blocked():
		return
	if menu_items.is_empty():
		return
	
	if event.is_action_pressed("ui_down"):
		current_selection_index = (current_selection_index + 1) % menu_items.size()
		_update_selection()
	elif event.is_action_pressed("ui_up"):
		current_selection_index = (current_selection_index - 1 + menu_items.size()) % menu_items.size()
		_update_selection()
	elif event.is_action_pressed("ui_accept"):
		_handle_selection()
	elif event.is_action_pressed("ui_cancel"):
		if current_state == MenuState.SUBMENU:
			current_state = MenuState.MAIN
			_build_main_menu()
		else:
			# Can't cancel main menu in battle usually?
			pass

func _handle_selection() -> void:
	var item = menu_items[current_selection_index]
	var id = item["id"]
	if disabled_actions.has(id):
		emit_signal("action_blocked", disabled_actions[id])
		_block_input(150)
		return
	
	if id == "SKILL_SUB" or id == "ITEM_SUB" or id == "META_SUB":
		current_state = MenuState.SUBMENU
		_build_submenu(id)
		_block_input(150)
	elif id == "ATTACK":
		emit_signal("action_selected", ActionIds.BASIC_ATTACK)
	elif id == "DEFEND":
		emit_signal("action_selected", ActionIds.SKIP_TURN) # Placeholder for Defend
	elif id == "GUARD_TOGGLE":
		emit_signal("action_selected", ActionIds.LUD_GUARD_STANCE)
	else:
		# ID is likely a specific ActionId (e.g. KAI_FLURRY)
		emit_signal("action_selected", id)


func set_disabled_actions(map: Dictionary) -> void:
	disabled_actions = map
	_update_selection()


func _block_input(ms: int) -> void:
	input_block_until_ms = Time.get_ticks_msec() + ms


func _is_input_blocked() -> bool:
	return Time.get_ticks_msec() < input_block_until_ms


func _apply_skin() -> void:
	_skin_cursor = _load_skin_tex("cursor_menu_arrow.png")
	_row_style_idle = _build_skin_style(_load_skin_tex("menu_row_idle_9slice.png"), 2, 1)
	_row_style_selected = _build_skin_style(_load_skin_tex("menu_row_selected_9slice.png"), 2, 1)
	_ornament_tl = _load_skin_tex("ornament_corner_tl.png")
	_ornament_tr = _load_skin_tex("ornament_corner_tr.png")
	_ornament_bl = _load_skin_tex("ornament_corner_bl.png")
	_ornament_br = _load_skin_tex("ornament_corner_br.png")

	if command_panel:
		command_panel.add_theme_stylebox_override("panel", _build_skin_style(_load_skin_tex("panel_command_9slice.png"), 6, 8))
		_add_corner_ornaments(command_panel, "Command")
	if description_panel:
		description_panel.add_theme_stylebox_override("panel", _build_skin_style(_load_skin_tex("panel_description_9slice.png"), 6, 8))
		_add_corner_ornaments(description_panel, "Description")
	var divider_tex = _load_skin_tex("divider_h.png")
	if name_separator and divider_tex:
		name_separator.texture = divider_tex
		name_separator.stretch_mode = TextureRect.STRETCH_SCALE
		name_separator.modulate = Color(0.86, 0.8, 0.66, 0.45)
	if action_list_node:
		action_list_node.add_theme_constant_override("separation", 2)


func _add_corner_ornaments(panel: Control, key: String) -> void:
	if panel == null:
		return
	var suffixes := ["TL", "TR", "BL", "BR"]
	var textures := [_ornament_tl, _ornament_tr, _ornament_bl, _ornament_br]
	for i in range(suffixes.size()):
		var node_name = "Ornament%s%s" % [key, suffixes[i]]
		var existing = panel.get_node_or_null(node_name)
		if existing:
			existing.queue_free()
		var tex = textures[i]
		if tex == null:
			continue
		var ornament = TextureRect.new()
		ornament.name = node_name
		ornament.texture = tex
		ornament.size = Vector2(12, 12)
		ornament.custom_minimum_size = Vector2(12, 12)
		ornament.stretch_mode = TextureRect.STRETCH_SCALE
		ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ornament.modulate = Color(0.84, 0.78, 0.65, 0.55)
		ornament.z_index = 3
		match i:
			0:
				ornament.position = Vector2(1, 1)
			1:
				ornament.anchor_left = 1.0
				ornament.anchor_right = 1.0
				ornament.position = Vector2(-13, 1)
			2:
				ornament.anchor_top = 1.0
				ornament.anchor_bottom = 1.0
				ornament.position = Vector2(1, -13)
			3:
				ornament.anchor_left = 1.0
				ornament.anchor_right = 1.0
				ornament.anchor_top = 1.0
				ornament.anchor_bottom = 1.0
				ornament.position = Vector2(-13, -13)
		panel.add_child(ornament)


func _load_skin_tex(file_name: String) -> Texture2D:
	var path = SKIN_ROOT + file_name
	if ResourceLoader.exists(path):
		return load(path)
	return null


func _build_skin_style(texture: Texture2D, margin: int = 8, content: int = 6) -> StyleBox:
	if texture == null:
		var fallback = StyleBoxFlat.new()
		fallback.bg_color = Color(0.06, 0.09, 0.15, 0.86)
		fallback.border_color = Color(0.66, 0.56, 0.36, 0.9)
		fallback.border_width_left = 2
		fallback.border_width_top = 2
		fallback.border_width_right = 2
		fallback.border_width_bottom = 2
		return fallback
	var style = StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = margin
	style.texture_margin_top = margin
	style.texture_margin_right = margin
	style.texture_margin_bottom = margin
	style.content_margin_left = content
	style.content_margin_top = content
	style.content_margin_right = content
	style.content_margin_bottom = content
	return style
