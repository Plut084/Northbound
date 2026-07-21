extends Control
## VictoryPopup — 通关弹窗。
## 队伍抵达避难所时弹出。确认后返回主菜单。


func show_victory() -> void:
	if has_node("%MessageLabel"):
		var msg: Label = %MessageLabel
		msg.text = "北方仍然没有春天。\n但你们终于抵达了避难站。\n\nDemo End"
	show()


func _on_confirm_button_pressed() -> void:
	hide()
	GameManager.end_game()
