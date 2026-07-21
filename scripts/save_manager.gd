extends Node
## SaveManager — 存档管理（AutoLoad）。
## 统一存档入口，使用 Dictionary → JSON 序列化。
## 支持跨场景的数据传递（用于读档恢复）。

const SAVE_PATH := "user://save_game.json"

# 跨场景数据传递
var _pending_em_state: Dictionary = {}
var _pending_restore_data: Dictionary = {}
var _is_loading_save: bool = false


func save_game(data: Dictionary) -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: 无法写入存档")
		return
	file.store_string(JSON.stringify(data, "\t"))


func load_game() -> Dictionary:
	if not has_save():
		return {}
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text = file.get_as_text()
	var data = JSON.parse_string(text)
	if data == null:
		push_error("SaveManager: 存档格式损坏")
		return {}
	return data


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


# 读档时，将完整存档数据暂存，供主场景恢复
func prepare_load(data: Dictionary) -> void:
	_pending_restore_data = data
	_is_loading_save = true
	_pending_em_state = data.get("event_save_state", {})


# 主场景检查是否需要恢复存档数据
func is_loading_save() -> bool:
	return _is_loading_save


# 获取并清除待恢复数据
func consume_restore_data() -> Dictionary:
	var data = _pending_restore_data
	_pending_restore_data = {}
	_is_loading_save = false
	return data


# EventManager 存档状态的临时传递（跨 reload_current_scene）
func store_em_state(state: Dictionary) -> void:
	_pending_em_state = state


# 清除读档标志（新游戏时调用）
func clear_loading_save() -> void:
	_pending_restore_data = {}
	_pending_em_state = {}
	_is_loading_save = false


func consume_em_state() -> Dictionary:
	var s = _pending_em_state
	_pending_em_state = {}
	return s
