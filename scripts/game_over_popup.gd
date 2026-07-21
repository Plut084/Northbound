extends Control
## GameOverPopup — 游戏失败弹窗。
## 对应 GDD 线框图第 231–245 行。

signal restart_pressed
signal quit_to_menu_pressed


func show_game_over(final_day: int, alive_count: int) -> void:
	# 更新显示内容
	if has_node("%MessageLabel"):
		var msg: Label = %MessageLabel
		msg.text = "你知道你做到了最好。\n但是谁能违抗命运呢？\n你写下这段日记，\n希望不被世界遗忘。\n\n——第 %d 天，队伍剩余 %d 人" % [final_day, alive_count]
	show()


func _on_restart_pressed() -> void:
	hide()
	restart_pressed.emit()


func _on_quit_pressed() -> void:
	hide()
	quit_to_menu_pressed.emit()
