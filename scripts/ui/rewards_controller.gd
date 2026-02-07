extends Control
class_name RewardsController

@onready var title_label: Label = $Panel/Content/Title
@onready var exp_label: Label = $Panel/Content/ExpLabel
@onready var gil_label: Label = $Panel/Content/GilLabel
@onready var items_label: Label = $Panel/Content/ItemsLabel
@onready var hint_label: Label = $Panel/Content/HintLabel


func show_rewards(rewards: Dictionary) -> void:
	var exp_value = int(rewards.get("exp", 0))
	var gil_value = int(rewards.get("gil", 0))
	var items: Array = rewards.get("items", [])
	var item_text = "None"
	if not items.is_empty():
		item_text = ", ".join(items)

	title_label.text = "Victory Rewards"
	exp_label.text = "EXP  +%d" % exp_value
	gil_label.text = "Gil  +%d" % gil_value
	items_label.text = "Items: %s" % item_text
	hint_label.text = "Press Enter to continue"
	visible = true
