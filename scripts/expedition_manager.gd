extends Node
## ExpeditionManager — 派遣系统。
## 负责：加载派遣任务、启动任务、每日检查完成、计算收益。
## 任务耗时均为游戏日两天。

signal mission_started(mission: Dictionary)
signal mission_completed(mission: Dictionary, effects: Dictionary)
signal missions_updated

const MISSION_DURATION: int = 2

var _all_missions: Array = []
# 进行中的派遣
var _active_missions: Array = []
# 已完成记录
var _completed_missions: Array = []

var resource_manager = null
var character_manager = null


func load_missions() -> void:
	var file = FileAccess.open("res://resources/expeditions/expeditions.json", FileAccess.READ)
	if file == null:
		push_error("ExpeditionManager: 无法加载 expeditions.json")
		return

	var json_text = file.get_as_text()
	var parsed = JSON.parse_string(json_text)
	if parsed == null or not parsed is Array:
		push_error("ExpeditionManager: expeditions.json 格式错误")
		return

	_all_missions = parsed
	print_debug("ExpeditionManager: 已加载 %d 个派遣任务" % _all_missions.size())


# 获取可派遣的任务（排除已在进行中的同 ID 任务）
func get_available_missions() -> Array:
	var active_ids: Array = []
	for m in _active_missions:
		active_ids.append(m.id)

	var available: Array = []
	for m in _all_missions:
		if m.id not in active_ids:
			available.append(m)
	return available


# 获取进行中的任务
func get_active_missions() -> Array:
	return _active_missions


# 获取已完成的任务记录
func get_completed_missions() -> Array:
	return _completed_missions


# 启动派遣任务
# member_ids: 派遣的队员 ID 列表
func start_mission(mission_id: String, member_ids: Array) -> bool:
	if character_manager == null:
		return false

	# 查找任务模板
	var template: Dictionary = {}
	for m in _all_missions:
		if m.id == mission_id:
			template = m.duplicate(true)
			break

	if template.is_empty():
		return false

	# 标记队员为派遣中，队伍人数减少
	character_manager.set_dispatched(member_ids)
	if resource_manager != null:
		resource_manager.modify_people(-member_ids.size())

	# 计算增益（基础 1.0 + 士气调整 + 特质调整）
	var trait_mult: float = character_manager.get_expedition_trait_multiplier(member_ids)
	var food_bonus: float = character_manager.get_food_scavenge_bonus(member_ids)
	var morale_mult: float = 1.0
	if resource_manager != null:
		morale_mult = resource_manager.get_expedition_multiplier()

	var base_mult: float = 1.0 + (morale_mult - 1.0) + (trait_mult - 1.0)

	var mission_data := {
		"id": template.id,
		"location": template.location,
		"description": template.description,
		"effects": template.effects,
		"member_ids": member_ids.duplicate(),
		"start_day": GameManager.current_day,
		"end_day": GameManager.current_day + MISSION_DURATION,
		"multiplier": base_mult,
		"food_multiplier": base_mult + (food_bonus - 1.0),
	}

	_active_missions.append(mission_data)
	mission_started.emit(mission_data)
	missions_updated.emit()
	return true


# 每日调用——检查是否有任务到期
func check_completions() -> Array:
	var completed: Array = []
	var still_active: Array = []

	for mission in _active_missions:
		if GameManager.current_day >= mission.end_day:
			_complete_mission(mission)
			completed.append(mission)
		else:
			still_active.append(mission)

	_active_missions = still_active

	if not completed.is_empty():
		missions_updated.emit()

	return completed


# 结算单个任务
func _complete_mission(mission: Dictionary) -> void:
	# 队员回归
	character_manager.clear_dispatched(mission.member_ids)

	# 计算最终收益（食物用 food_multiplier，其他用 multiplier）
	var effects: Dictionary = mission.get("effects", {}).duplicate()
	var mult: float = mission.get("multiplier", 1.0)
	var food_mult: float = mission.get("food_multiplier", mult)
	var adjusted_effects: Dictionary = {}
	for key in effects:
		var raw: int = effects[key]
		var use_mult: float = food_mult if key == "food" else mult
		var adjusted: int = int(round(raw * use_mult))
		adjusted_effects[key] = adjusted

	# 更新资源——只更新 food 和 fire，people 由返回成员恢复
	if resource_manager != null:
		var people_returned = mission.member_ids.size()
		resource_manager.modify_people(people_returned)

		for key in adjusted_effects:
			match key:
				"food":
					resource_manager.modify_food(adjusted_effects[key])
				"fire":
					resource_manager.modify_fire(adjusted_effects[key])

	var record := {
		"id": mission.id,
		"location": mission.location,
		"description": mission.description,
		"effects": adjusted_effects,
		"members": mission.member_ids.duplicate(),
		"completed_day": GameManager.current_day,
	}
	_completed_missions.append(record)
	mission_completed.emit(record, adjusted_effects)


# --- 存档 ---

func make_save_snapshot() -> Dictionary:
	return {
		"active_missions": _active_missions.duplicate(true),
		"completed_missions": _completed_missions.duplicate(true),
	}


func restore_from_save(data: Dictionary) -> void:
	_active_missions = data.get("active_missions", []).duplicate(true)
	_completed_missions = data.get("completed_missions", []).duplicate(true)
