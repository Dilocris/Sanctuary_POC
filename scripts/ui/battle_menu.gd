extends Control
class_name BattleMenu

signal action_selected(action_id: String)
signal menu_canceled
signal action_blocked(reason: String)
signal menu_changed(menu_items: Array)

enum MenuState { MAIN, SUBMENU, TARGETING, DISABLED }
var current_state = MenuState.DISABLED

var active_actor: Character
var main_options = ["Attack", "Skill", "Defend", "Item"]
var current_selection_index: int = 0

# Mock UI Elements (Will be nodes in real scene)
var action_list_container: VBoxContainer
@onready var action_list_node = $Panel/ActionList
@onready var description_label = $DescriptionPanel/Label

var menu_items: Array = []
var disabled_actions: Dictionary = {}
var input_block_until_ms: int = 0

func _ready() -> void:
	visible = false

func setup(actor: Character) -> void:
	active_actor = actor
	current_state = MenuState.MAIN
	current_selection_index = 0
	visible = true
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
	# Common Attack (Catraca uses Fire Bolt as her basic)
	if active_actor.id == "catraca":
		menu_items.append({"label": "Fire Bolt", "id": ActionIds.CAT_FIRE_BOLT, "desc": "Cantrip: Fire damage."})
	else:
		menu_items.append({"label": "Attack", "id": "ATTACK", "desc": "Basic physical attack."})
	
	# Class Specific Submenu
	match active_actor.id:
		"kairus":
			menu_items.append({"label": "Skills", "id": "SKILL_SUB", "desc": "Monk abilities using Ki."})
		"ludwig":
			menu_items.append({"label": "Maneuvers", "id": "SKILL_SUB", "desc": "Battle maneuvers using Superiority Dice."})
		"ninos":
			menu_items.append({"label": "Abilities", "id": "SKILL_SUB", "desc": "Bardic spells and inspiration."})
		"catraca":
			menu_items.append({"label": "Metamagic", "id": "META_SUB", "desc": "Sorcery modifiers (spend SP)."})
			menu_items.append({"label": "Magic", "id": "SKILL_SUB", "desc": "Sorcerous spells."})
	
	# Common Defend/Guard
	if active_actor.id == "ludwig":
		menu_items.append({"label": "Guard Stance", "id": "GUARD_TOGGLE", "desc": "Toggle defensive stance."})
	else:
		menu_items.append({"label": "Defend", "id": "DEFEND", "desc": "Skip turn and reduce damage."})
		
	# Common Item
	menu_items.append({"label": "Item", "id": "ITEM_SUB", "desc": "Use consumables."})
	
	_render_menu_items()

func _build_submenu(category: String) -> void:
	menu_items.clear()
	match active_actor.id:
		"kairus":
			if category == "SKILL_SUB":
				menu_items.append({"label": "Flurry of Blows", "id": ActionIds.KAI_FLURRY, "desc": "2 Ki: Multi-hit attack."})
				menu_items.append({"label": "Stunning Strike", "id": ActionIds.KAI_STUN_STRIKE, "desc": "1 Ki: Stun target."})
				menu_items.append({"label": "Fire Imbue", "id": ActionIds.KAI_FIRE_IMBUE, "desc": "0 Ki: Add Fire dmg to attacks."})
		"ludwig":
			if category == "SKILL_SUB":
				menu_items.append({"label": "Lunging Attack", "id": ActionIds.LUD_LUNGING, "desc": "1 Die: Reach attack + bonus dmg."})
				menu_items.append({"label": "Precision Strike", "id": ActionIds.LUD_PRECISION, "desc": "1 Die: Bonus dmg (ignores evasion)."})
				menu_items.append({"label": "Shield Bash", "id": ActionIds.LUD_SHIELD_BASH, "desc": "1 Die: Chance to stun."})
				menu_items.append({"label": "Rally", "id": ActionIds.LUD_RALLY, "desc": "1 Die: Heal ally."})
		"ninos":
			if category == "SKILL_SUB":
				menu_items.append({"label": "Inspire (Atk)", "id": ActionIds.NINOS_INSPIRE_ATTACK, "desc": "1 Insp: Buff ally attack."})
				menu_items.append({"label": "Vicious Mockery", "id": ActionIds.NINOS_VICIOUS_MOCKERY, "desc": "5 MP: Dmg + Atk Down."})
				menu_items.append({"label": "Healing Word", "id": ActionIds.NINOS_HEALING_WORD, "desc": "6 MP: Heal ally."})
				menu_items.append({"label": "Bless", "id": ActionIds.NINOS_BLESS, "desc": "10 MP: Buff party."})
		"catraca":
			if category == "SKILL_SUB":
				menu_items.append({"label": "Fireball", "id": ActionIds.CAT_FIREBALL, "desc": "18 MP: AoE Fire damage."})
				menu_items.append({"label": "Mage Armor", "id": ActionIds.CAT_MAGE_ARMOR, "desc": "4 MP: Buff defense."})
			elif category == "META_SUB":
				menu_items.append({"label": "Quicken Spell", "id": ActionIds.CAT_METAMAGIC_QUICKEN, "desc": "2 SP: Extra action after spell."})
				menu_items.append({"label": "Twin Spell", "id": ActionIds.CAT_METAMAGIC_TWIN, "desc": "1 SP: Single spell hits 2 targets."})
	
	_render_menu_items()

func _render_menu_items() -> void:
	for child in action_list_node.get_children():
		child.queue_free()
	
	for item in menu_items:
		var label = Label.new()
		var label_text = item["label"]
		if disabled_actions.has(item["id"]):
			label_text += " (X)"
		label.text = label_text
		action_list_node.add_child(label)
	
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
	for child in action_list_node.get_children():
		if idx >= menu_items.size():
			break
		if idx == current_selection_index:
			child.modulate = Color(1, 1, 0) # Highlight yellow
		else:
			var item_id = menu_items[idx].get("id", "")
			if disabled_actions.has(item_id):
				child.modulate = Color(0.6, 0.6, 0.6)
			else:
				child.modulate = Color(1, 1, 1)
		idx += 1
	
	description_label.text = menu_items[current_selection_index].get("desc", "")

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
