extends Control
## PauseMenu — 暂停菜单。
## 只负责显示选项按钮，通过信号通知 Main 执行操作。

signal resume_game
signal save_game
signal load_game
signal quit_to_menu


func show_menu() -> void:
	show()


func hide_menu() -> void:
	hide()


func _on_resume_pressed() -> void:
	resume_game.emit()


func _on_save_pressed() -> void:
	save_game.emit()


func _on_load_pressed() -> void:
	load_game.emit()


func _on_quit_pressed() -> void:
	quit_to_menu.emit()
