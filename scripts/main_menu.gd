extends Control
## MainMenu — 主菜单界面。
## 对应 GDD 线框图第 71–109 行。

@onready var continue_button: Button = $VBoxContainer/ContinueButton


func _ready() -> void:
	# 无存档时禁用"继续游戏"
	if not SaveManager.has_save():
		continue_button.disabled = true


func _on_start_button_pressed() -> void:
	SaveManager.clear_loading_save()
	GameManager.start_new_game()


func _on_continue_button_pressed() -> void:
	var data = SaveManager.load_game()
	if data.is_empty():
		return
	# 将完整存档数据交给 SaveManager 暂存
	SaveManager.prepare_load(data)
	# 恢复 GameManager（AutoLoad 部分）
	GameManager.restore_from_save(data)
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_settings_pressed() -> void:
	if has_node("SettingsPanel"):
		$SettingsPanel.show()


func _on_quit_button_pressed() -> void:
	get_tree().quit()
