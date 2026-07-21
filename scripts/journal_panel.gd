extends Control
## JournalPanel — 日志面板。
## 记录每日发生的事件，通过滚动列表展示。
## 只负责显示，不修改数据。

signal close_pressed

@onready var log_list: RichTextLabel = %LogList


func _ready() -> void:
	hide()


func show_journal(entries: Array) -> void:
	# 提高 z_index 确保在 TravelPanel 等全屏面板之上
	#z_index = 10
	log_list.clear()
	if entries.is_empty():
		log_list.append_text("还没有任何记录。\n")
	else:
		for entry in entries:
			log_list.append_text("[Day %d] %s\n" % [entry.get("day", 0), entry.get("text", "")])
	show()


func add_entry(day: int, text: String) -> void:
	log_list.append_text("[Day %d] %s\n" % [day, text])


func _on_close_pressed() -> void:
	hide()
	close_pressed.emit()
