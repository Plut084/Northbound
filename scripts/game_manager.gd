extends Node
## GameManager — 游戏流程控制（AutoLoad）。
## 负责：游戏状态、天数推进、地点系统、存档快照、胜利/失败判定。
## 不负责：资源数据（交给 ResourceManager）、角色数据（交给 CharacterManager）。

enum GameState { MENU, PLAYING, PAUSED, GAME_OVER }

# --- 地点系统 ---
enum LocationState { STAY, TRAVEL }
enum LocationID { PLAIN, FOREST, BASIN, VALLEY, GLACIER, SHELTER }

# 地点连线图：每个地点可通往的相邻地点
const LOCATION_CONNECTIONS: Dictionary = {
	LocationID.PLAIN: [LocationID.FOREST],
	LocationID.FOREST: [LocationID.PLAIN, LocationID.BASIN, LocationID.VALLEY],
	LocationID.BASIN: [LocationID.FOREST],
	LocationID.VALLEY: [LocationID.FOREST, LocationID.GLACIER],
	LocationID.GLACIER: [LocationID.VALLEY, LocationID.SHELTER],
	LocationID.SHELTER: [],
}

# 地点中文名映射
const LOCATION_NAMES: Dictionary = {
	LocationID.PLAIN: "平原",
	LocationID.FOREST: "森林",
	LocationID.BASIN: "盆地",
	LocationID.VALLEY: "山谷",
	LocationID.GLACIER: "冰川",
	LocationID.SHELTER: "避难所",
}

signal game_won
signal game_lost
signal day_advanced(new_day: int)
signal location_changed(new_location: int)

var state: GameState = GameState.MENU
var current_day: int = 1

# 旗标系统——用于事件链
var flags: Dictionary = {}

# 预警系统——用于定时触发事件
var pending_events: Array = []

# Demo 最大天数（第 21 天开始时仍未抵达避难所则失败）
const MAX_DAYS: int = 20

# --- 地点状态 ---
var location_state: LocationState = LocationState.STAY
var current_location: LocationID = LocationID.PLAIN
var destination: LocationID = LocationID.PLAIN
var stay_days: int = 1

# 资源默认值——由 ResourceManager 初始化，此处仅作存档回退
const DEFAULT_FOOD: int = 20
const DEFAULT_FIRE: int = 20
const DEFAULT_MORALE: int = 20
const DEFAULT_PEOPLE: int = 6


func start_new_game() -> void:
	flags.clear()
	pending_events.clear()
	current_day = 1
	location_state = LocationState.STAY
	current_location = LocationID.PLAIN
	destination = LocationID.PLAIN
	stay_days = 1
	state = GameState.PLAYING
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func advance_day() -> void:
	current_day += 1
	day_advanced.emit(current_day)

	# 超过最大天数仍未抵达避难所 → 失败
	if current_day > MAX_DAYS and current_location != LocationID.SHELTER:
		state = GameState.GAME_OVER
		game_lost.emit()


func check_game_over(morale: int, alive_count: int) -> bool:
	# 士气归零或队伍全部死亡
	if morale <= 0 or alive_count <= 0:
		state = GameState.GAME_OVER
		game_lost.emit()
		return true
	return false


func end_game() -> void:
	state = GameState.GAME_OVER
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# --- 旗标系统 ---

func set_flag(flag_name: String) -> void:
	flags[flag_name] = true


func has_flag(flag_name: String) -> bool:
	return flags.get(flag_name, false)


func remove_flag(flag_name: String) -> void:
	flags.erase(flag_name)


# --- 预警系统 ---

func add_pending_event(data: Dictionary) -> void:
	pending_events.append(data)


func pop_due_events() -> Array:
	var due: Array = []
	var remaining: Array = []
	for pe in pending_events:
		if pe.day <= current_day:
			due.append(pe)
		else:
			remaining.append(pe)
	pending_events = remaining
	return due


# --- 地点系统 ---

## 返回从指定地点可前往的相邻地点列表。
func get_connected_locations(loc: LocationID) -> Array:
	return LOCATION_CONNECTIONS.get(loc, []).duplicate()


## 返回地点的中文名称（UI 显示用）。
func get_location_name(loc: LocationID) -> String:
	return LOCATION_NAMES.get(loc, "")


## 返回地点的事件池 key，与 events.json 的 "location" 字段值对应。
func get_location_event_key(loc: LocationID) -> String:
	match loc:
		LocationID.PLAIN:    return "Plain"
		LocationID.FOREST:   return "Forest"
		LocationID.BASIN:    return "Basin"
		LocationID.VALLEY:   return "Valley"
		LocationID.GLACIER:  return "Glacier"
		LocationID.SHELTER:  return ""
	return ""


## 检查是否抵达避难所（胜利条件）。
func check_victory() -> bool:
	if current_location == LocationID.SHELTER:
		state = GameState.GAME_OVER
		game_won.emit()
		return true
	return false


# --- 存档快照 ---

# 生成当前状态的存档数据（当天开始时调用）
func make_save_snapshot() -> Dictionary:
	return {
		"current_day": current_day,
		"flags": flags.duplicate(),
		"pending_events": pending_events.duplicate(),
		"location_state": location_state,
		"current_location": current_location,
		"destination": destination,
		"stay_days": stay_days,
	}


# 从存档数据恢复（资源恢复由 ResourceManager 处理）
func restore_from_save(data: Dictionary) -> void:
	current_day = data.get("current_day", 1)
	flags = data.get("flags", {}).duplicate()
	pending_events = data.get("pending_events", []).duplicate()
	location_state = data.get("location_state", LocationState.STAY)
	current_location = data.get("current_location", LocationID.PLAIN)
	destination = data.get("destination", LocationID.PLAIN)
	stay_days = data.get("stay_days", 1)
	state = GameState.PLAYING
