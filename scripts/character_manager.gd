extends Node
## CharacterManager — 角色系统。
## 负责：加载角色数据、管理 HP、派遣状态、提供查询接口。
## 只负责数据，不负责 UI。

signal character_died(character: Dictionary)
signal character_added(character: Dictionary)
signal character_damaged(character_id: String, new_hp: int)
signal roster_changed

var _characters: Array = []
# 派遣中的角色 ID 集合
var _dispatched_ids: Array = []


func load_characters() -> void:
	var file = FileAccess.open("res://resources/characters/characters.json", FileAccess.READ)
	if file == null:
		push_error("CharacterManager: 无法加载 characters.json")
		return

	var json_text = file.get_as_text()
	var parsed = JSON.parse_string(json_text)
	if parsed == null or not parsed is Array:
		push_error("CharacterManager: characters.json 格式错误")
		return

	_characters = parsed
	print_debug("CharacterManager: 已加载 %d 个角色" % _characters.size())


# --- 查询 ---

func get_all_characters() -> Array:
	return _characters


func get_alive_characters() -> Array:
	var alive: Array = []
	for c in _characters:
		if c.hp > 0:
			alive.append(c)
	return alive


func get_alive_count() -> int:
	return get_alive_characters().size()


func get_character_by_id(id: String) -> Dictionary:
	for c in _characters:
		if c.id == id:
			return c
	return {}


# 获取可派遣的成员（存活 + 未派遣 + 允许派遣）
func get_available_members() -> Array:
	var available: Array = []
	for c in _characters:
		if c.hp > 0 and c.id not in _dispatched_ids:
			available.append(c)
	return available


# 获取可派遣的成员（在 get_available_members 基础上排除 can_dispatch=false 的角色）
func get_dispatchable_members() -> Array:
	var result: Array = []
	for c in get_available_members():
		if c.get("can_dispatch", true):
			result.append(c)
	return result


# 获取当前队伍中的成员（存活 + 未派遣）
func get_party_members() -> Array:
	return get_available_members()


func get_party_size() -> int:
	return get_available_members().size()


# --- 派遣状态 ---

func is_dispatched(id: String) -> bool:
	return id in _dispatched_ids


func set_dispatched(ids: Array) -> void:
	for id in ids:
		if id not in _dispatched_ids:
			_dispatched_ids.append(id)
	roster_changed.emit()


func clear_dispatched(ids: Array) -> void:
	for id in ids:
		_dispatched_ids.erase(id)
	roster_changed.emit()


# --- HP 操作 ---

func apply_damage(character_id: String, amount: int) -> void:
	var c = get_character_by_id(character_id)
	if c.is_empty() or c.hp <= 0:
		return

	c.hp = maxi(0, c.hp - amount)
	character_damaged.emit(character_id, c.hp)

	if c.hp <= 0:
		character_died.emit(c)


func heal_character(character_id: String, amount: int) -> void:
	var c = get_character_by_id(character_id)
	if c.is_empty() or c.hp <= 0:
		return

	c.hp = mini(c.max_hp, c.hp + amount)
	character_damaged.emit(character_id, c.hp)


# 对随机一名在营队员造成伤害（排除已派遣成员，他们不在营地不应受饥饿等影响）
func damage_random_alive(amount: int) -> String:
	# 使用 get_available_members 而非 get_alive_characters，
	# 避免派遣中的角色被营地饥饿伤害错误打到
	var available = get_available_members()
	if available.is_empty():
		return ""

	var target = available[randi() % available.size()]
	apply_damage(target.id, amount)
	return target.id


# --- 特质查询 ---

# 返回在派遣任务中所有 bonus 特质的累计倍率（通用资源）
func get_expedition_trait_multiplier(member_ids: Array) -> float:
	var total := 1.0
	for id in member_ids:
		var c = get_character_by_id(id)
		if c.is_empty():
			continue
		var char_trait: Dictionary = c.get("trait", {})
		if char_trait.get("type") == "expedition_bonus":
			total += char_trait.get("value", 0.0)
	return total


# 返回在派遣任务中食物专属 bonus 的累计倍率
func get_food_scavenge_bonus(member_ids: Array) -> float:
	var total := 1.0
	for id in member_ids:
		var c = get_character_by_id(id)
		if c.is_empty():
			continue
		var char_trait: Dictionary = c.get("trait", {})
		if char_trait.get("type") == "food_scavenge_bonus":
			total += char_trait.get("value", 0.0)
	return total


# 返回当前队伍中 fire_cost_reduce 特质的火种节省量
func get_fire_cost_reduction() -> int:
	var reduction := 0
	for c in _characters:
		if c.hp <= 0 or c.id in _dispatched_ids:
			continue
		var char_trait: Dictionary = c.get("trait", {})
		if char_trait.get("type") == "fire_cost_reduce":
			reduction += char_trait.get("value", 0)
	return reduction


# 返回当前队伍中 cold_resist 特质的伤害减免
func get_cold_damage_reduction() -> int:
	var reduction := 0
	for c in _characters:
		if c.hp <= 0 or c.id in _dispatched_ids:
			continue
		var char_trait: Dictionary = c.get("trait", {})
		if char_trait.get("type") == "cold_resist":
			reduction += char_trait.get("value", 0)
	return reduction


# 返回当前队伍中 morale_story 特质的每日士气加成
func get_morale_story_bonus() -> int:
	var bonus := 0
	for c in _characters:
		if c.hp <= 0 or c.id in _dispatched_ids:
			continue
		var char_trait: Dictionary = c.get("trait", {})
		if char_trait.get("type") == "morale_story":
			bonus += char_trait.get("value", 0)
	return bonus


# 返回当前队伍中 food_production 特质的每日食物加成
func get_food_production_bonus() -> int:
	var bonus := 0
	for c in _characters:
		if c.hp <= 0 or c.id in _dispatched_ids:
			continue
		var char_trait: Dictionary = c.get("trait", {})
		if char_trait.get("type") == "food_production":
			bonus += char_trait.get("value", 0)
	return bonus


# 返回当前队伍中 heal_bonus 特质的治疗加成
func get_heal_bonus() -> int:
	var bonus := 0
	for c in _characters:
		if c.hp <= 0 or c.id in _dispatched_ids:
			continue
		var char_trait: Dictionary = c.get("trait", {})
		if char_trait.get("type") == "heal_bonus":
			bonus += char_trait.get("value", 0)
	return bonus


# 将新角色加入队伍
func add_character(character_data: Dictionary) -> void:
	if not character_data.has("id"):
		character_data["id"] = "recruit_%d" % Time.get_unix_time_from_system()
	if not character_data.has("max_hp"):
		character_data["max_hp"] = character_data.get("hp", 2)
	_characters.append(character_data)
	character_added.emit(character_data)


# --- 存档 ---

func make_save_snapshot() -> Dictionary:
	return {
		"characters": _characters.duplicate(true),
		"dispatched_ids": _dispatched_ids.duplicate(),
	}


func restore_from_save(data: Dictionary) -> void:
	_characters = data.get("characters", []).duplicate(true)
	_dispatched_ids = data.get("dispatched_ids", []).duplicate()
