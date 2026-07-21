extends Control
## TravelPanel — 行进途中界面。
## 在 Travel 状态下显示，只有日志和下一天按钮。
## 不显示事件、队伍、地图面板。

signal travel_next_day_pressed
signal journal_pressed

@onready var day_label: Label = $Panel/VBoxContainer/DayLabel
@onready var route_label: Label = $Panel/VBoxContainer/RouteLabel


func show_travel() -> void:
	var from_name: String = GameManager.get_location_name(GameManager.current_location)
	var to_name: String = GameManager.get_location_name(GameManager.destination)
	day_label.text = "第 %d 天" % GameManager.current_day
	route_label.text = "从 %s 前往 %s" % [from_name, to_name]
	show()


func _on_journal_pressed() -> void:
	journal_pressed.emit()


func _on_next_day_pressed() -> void:
	travel_next_day_pressed.emit()
