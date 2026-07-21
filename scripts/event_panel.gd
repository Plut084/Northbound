extends Control
## EventPanel — 事件显示面板。
## 只负责显示事件文本和选择按钮，不修改数据。
## 玩家选择后发出 choice_selected 信号。

signal choice_selected(choice_index: int)
signal continue_pressed
signal system_event_confirmed

@onready var title_label: Label = %TitleLabel
@onready var description_label: Label = %DescriptionLabel
@onready var choices_container: VBoxContainer = %ChoicesContainer
@onready var result_label: Label = %ResultLabel
@onready var continue_button: Button = %ContinueButton

# ChoiceButton 场景，用于动态生成选择按钮
const CHOICE_BUTTON_SCENE = preload("res://scenes/choice_button.tscn")


# 显示事件：标题 + 描述 + 选择按钮（无选择时显示"确认"按钮）
func display_event(event_data: Dictionary) -> void:
	_reset_panel()

	title_label.text = event_data.get("title", "")
	description_label.text = event_data.get("description", "")

	var choices: Array = event_data.get("choices", [])
	if choices.is_empty():
		# 系统事件（无选择）：显示确认按钮
		continue_button.text = "确认"
		continue_button.show()
	else:
		for i in choices.size():
			var choice: Dictionary = choices[i]
			var button: Button = CHOICE_BUTTON_SCENE.instantiate()
			button.text = choice.get("text", "")
			button.pressed.connect(_on_choice_pressed.bind(i))
			choices_container.add_child(button)


# 显示选择结果
func display_result(result_text: String) -> void:
	# 隐藏选择按钮
	for child in choices_container.get_children():
		child.hide()

	result_label.text = result_text
	result_label.show()
	continue_button.text = "继续"
	continue_button.show()


# 绑定到按钮的回调
func _on_choice_pressed(index: int) -> void:
	choice_selected.emit(index)
	# 选择后禁用所有按钮，防止重复点击
	for child in choices_container.get_children():
		child.disabled = true


func _on_continue_button_pressed() -> void:
	if continue_button.text == "确认":
		system_event_confirmed.emit()
	else:
		continue_pressed.emit()


# 重置面板到初始状态
func _reset_panel() -> void:
	title_label.text = ""
	description_label.text = ""
	result_label.text = ""
	result_label.hide()
	continue_button.hide()

	for child in choices_container.get_children():
		child.queue_free()
