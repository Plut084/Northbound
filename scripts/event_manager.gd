extends Node
## EventManager — 事件系统。
## 负责：加载/筛选/加权选取事件、执行选择、应用效果。
## 通过 ResourceManager 修改资源，通过 CharacterManager 操作角色。

signal event_ready(event_data: Dictionary)
signal effects_applied(effects: Dictionary)

const BASE_WEIGHT: float = 1.0
const COMMON_WEIGHT: float = 0.4
const SCARCITY_MULTIPLIER: float = 3.0
const FOOD_SCARCITY: int = 10
const FIRE_SCARCITY: int = 10

var resource_manager = null
var character_manager = null

var _permanent_excluded: Array = []
var _all_events: Array = []
var _current_event: Dictionary = {}
var _used_event_ids: Array = []
var _last_result_text: String = ""
var _rng: RandomNumberGenerator


func _ready() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	_load_events()


func _load_events() -> void:
	var file: FileAccess = FileAccess.open("res://resources/events/events.json", FileAccess.READ)
	if file == null:
		push_error("EventManager: 无法加载 events.json")
		return
	var json_text: String = file.get_as_text()
	var parsed = JSON.parse_string(json_text)
	if parsed == null or not parsed is Array:
		push_error("EventManager: events.json 格式错误")
		return
	_all_events = parsed
	print_debug("EventManager: 已加载 %d 个事件" % _all_events.size())


func get_random_event() -> Dictionary:
	var scheduled: Dictionary = _check_scheduled()
	if not scheduled.is_empty():
		_current_event = scheduled
		event_ready.emit(_current_event)
		return _current_event

	var available: Array = _get_available_events()
	if available.is_empty():
		_used_event_ids.clear()
		available = _get_available_events()
	if available.is_empty():
		push_error("EventManager: 没有可用事件")
		return {}

	_current_event = _pick_weighted(available)
	_used_event_ids.append(_current_event.id)
	if _current_event.get("once", false):
		_permanent_excluded.append(_current_event.id)

	event_ready.emit(_current_event)
	return _current_event


func _get_available_events() -> Array:
	var available: Array = []
	var loc_key: String = GameManager.get_location_event_key(GameManager.current_location)

	for event in _all_events:
		if event.get("type") == "system":
			continue
		if event.id in _permanent_excluded:
			continue

		# 地点筛选：事件 location 必须匹配当前地点或为 Common
		var event_location: String = event.get("location", "")
		if event_location != "" and event_location != loc_key and event_location != "Common":
			continue

		var require_flag: String = event.get("require_flag", "")
		if require_flag != "" and not GameManager.has_flag(require_flag):
			continue
		if event.has("max_day") and GameManager.current_day > event.max_day:
			continue
		if event.id in _used_event_ids:
			continue
		available.append(event)
	return available


func _pick_weighted(available: Array) -> Dictionary:
	var total_weight: float = 0.0
	var weights: Array = []
	for event in available:
		var w: float = _compute_weight(event)
		weights.append(w)
		total_weight += w

	var roll: float = _rng.randf() * total_weight
	var cumulative: float = 0.0
	for i in available.size():
		cumulative += weights[i]
		if roll <= cumulative:
			return available[i]
	return available[-1]


func _compute_weight(event: Dictionary) -> float:
	var weight: float = BASE_WEIGHT
		# Common 事件权重降低，突出地区差异
	if event.get("location") == "Common":
		weight *= COMMON_WEIGHT
	if resource_manager == null:
		return weight
	var tags: Array = event.get("tags", [])
	if "low_food" in tags and resource_manager.food < FOOD_SCARCITY:
		weight *= SCARCITY_MULTIPLIER
	if "low_fire" in tags and resource_manager.fire < FIRE_SCARCITY:
		weight *= SCARCITY_MULTIPLIER
	return weight


func _check_scheduled() -> Dictionary:
	var due: Array = GameManager.pop_due_events()
	if due.is_empty():
		return {}
	var scheduled: Dictionary = due[0]
	for i in range(1, due.size()):
		GameManager.add_pending_event(due[i])
	return _resolve_scheduled(scheduled)


func _resolve_scheduled(scheduled: Dictionary) -> Dictionary:
	var condition: Dictionary = scheduled.get("condition", {})
	var passed: bool = true
	if resource_manager != null:
		for key in condition:
			var required: int = condition[key]
			match key:
				"food":   if resource_manager.food   < required: passed = false
				"fire":   if resource_manager.fire   < required: passed = false
				"morale": if resource_manager.morale < required: passed = false

	var event_id: String = scheduled.pass_event if passed else scheduled.fail_event
	for event in _all_events:
		if event.id == event_id:
			return event
	push_error("EventManager: 找不到预约系统事件 '%s'" % event_id)
	return {}


## 对当前事件应用其自带的效果（用于无选择的系统事件）。
func apply_event_effects() -> void:
	if _current_event.is_empty():
		return
	var effects: Dictionary = _current_event.get("effects", {})
	_last_result_text = _current_event.get("result", "")
	_apply_effects(effects)
	effects_applied.emit(effects)


func apply_choice(choice_index: int) -> void:
	if _current_event.is_empty():
		return
	var choices: Array = _current_event.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		return

	var choice: Dictionary = choices[choice_index]
	var effects: Dictionary = choice.get("effects", {})

	if effects.has("fire") and effects.fire < 0 and character_manager != null:
		var reduction: int = character_manager.get_fire_cost_reduction()
		effects.fire = mini(0, effects.fire + reduction)
	if effects.has("health") and effects.health < 0 and character_manager != null:
		var reduction: int = character_manager.get_cold_damage_reduction()
		effects.health = mini(0, effects.health + reduction)

	_last_result_text = choice.get("result", "")

	var flags_set: Dictionary = choice.get("flags_set", {})
	for flag in flags_set:
		GameManager.set_flag(flag)

	var consume_flag: String = _current_event.get("consume_flag", "")
	if consume_flag != "":
		GameManager.remove_flag(consume_flag)

	var schedule: Dictionary = choice.get("schedule", {})
	if not schedule.is_empty():
		var target_day: int = GameManager.current_day + schedule.get("day_offset", 0)
		GameManager.add_pending_event({
			"day": target_day,
			"condition": schedule.get("condition", {}),
			"pass_event": schedule.get("pass_event", ""),
			"fail_event": schedule.get("fail_event", "")
		})

	# 招募新成员——事件选项中携带 recruit 字段时，将角色加入队伍
	var recruit_data: Dictionary = choice.get("recruit", {})
	if not recruit_data.is_empty() and character_manager != null:
		character_manager.add_character(recruit_data)
		# 招募角色自动增加队伍人数
		if resource_manager != null:
			resource_manager.modify_people(1)

	_apply_effects(effects)
	effects_applied.emit(effects)


func get_last_result_text() -> String:
	return _last_result_text


func get_save_state() -> Dictionary:
	return {
		"permanent_excluded": _permanent_excluded.duplicate(),
		"used_event_ids": _used_event_ids.duplicate(),
	}


func restore_save_state(state: Dictionary) -> void:
	_permanent_excluded = state.get("permanent_excluded", []).duplicate()
	_used_event_ids = state.get("used_event_ids", []).duplicate()
	_current_event = {}


func _apply_effects(effects: Dictionary) -> void:
	if resource_manager == null:
		return

	if effects.has("food"):
		resource_manager.modify_food(effects.food)
	if effects.has("fire"):
		resource_manager.modify_fire(effects.fire)
	if effects.has("morale"):
		resource_manager.modify_morale(effects.morale)
	if effects.has("health"):
		var hp_change: int = effects.health
		var health_details: Array = []
		if hp_change < 0 and character_manager != null:
			var available: Array = character_manager.get_available_members()
			var damage_count: int = mini(abs(hp_change), available.size())
			for _i in range(damage_count):
				var idx: int = randi() % available.size()
				var chara = available[idx]
				character_manager.apply_damage(chara.id, 1)
				health_details.append({
					"name": chara.name,
					"change": -1,
					"current_hp": chara.hp,
					"max_hp": chara.max_hp,
				})
				available.remove_at(idx)
		elif hp_change > 0 and character_manager != null:
			var available: Array = character_manager.get_available_members()
			if not available.is_empty():
				var heal_amount: int = hp_change + character_manager.get_heal_bonus()
				var target = available[0]
				for c in available:
					if c.hp < target.hp:
						target = c
				var old_hp: int = target.hp
				character_manager.heal_character(target.id, heal_amount)
				health_details.append({
					"name": target.name,
					"change": target.hp - old_hp,
					"current_hp": target.hp,
					"max_hp": target.max_hp,
				})
		if not health_details.is_empty():
			effects["_health_details"] = health_details
