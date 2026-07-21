extends Control
## StoryIntro — 故事开场界面。
## 第一天开始前显示的发场画面。
## 对应 GDD 线框图第 121–131 行。

signal intro_finished


func show_intro() -> void:
	show()


func _on_confirm_pressed() -> void:
	hide()
	intro_finished.emit()
