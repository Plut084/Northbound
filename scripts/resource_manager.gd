extends Node
## ResourceManager — 统一资源管理。
## 所有资源修改必须经过此 Manager。
## 负责：存储资源值、应用每日消耗、执行 GDD 阈值规则。

signal resource_changed(resource_name: String, new_value: int)

# 资源上限常量
const MAX_FOOD: int = 999
const MAX_FIRE: int = 999
const MAX_MORALE: int = 999
const MIN_PEOPLE: int = 1
const MAX_PEOPLE: int = 20

# GDD 阈值常量
const FOOD_LOW_THRESHOLD: int = 5
const FOOD_HIGH_THRESHOLD: int = 15
const FIRE_HIGH_THRESHOLD: int = 15
const MORALE_LOW_THRESHOLD: int = 5
const MORALE_HIGH_THRESHOLD: int = 15

# 每日消耗常量
const DAILY_FIRE_COST: int = 2

# 资源默认值（GDD 指定）
@export var default_food: int = 20
@export var default_fire: int = 20
@export var default_morale: int = 20
@export var default_people: int = 6

var food: int
var fire: int
var morale: int
var people: int

# 记录每日食物消耗量（用于火种节省计算）
var _daily_food_consumption: int = 0


func init_resources() -> void:
	_set_food(default_food)
	_set_fire(default_fire)
	_set_morale(default_morale)
	_set_people(default_people)


# --- 资源修改（统一入口） ---

func modify_food(amount: int) -> void:
	_set_food(clampi(food + amount, 0, MAX_FOOD))


func modify_fire(amount: int) -> void:
	_set_fire(clampi(fire + amount, 0, MAX_FIRE))


func modify_morale(amount: int) -> void:
	_set_morale(clampi(morale + amount, 0, MAX_MORALE))


func modify_people(amount: int) -> void:
	_set_people(clampi(people + amount, MIN_PEOPLE, MAX_PEOPLE))


# --- 每日消耗 ---

## 推进一天时调用。返回需要处理的角色伤害信息。
## 食物消耗 = 当前队伍人数的一半（向下取整，不含派遣中成员）
## 火种消耗 = 2
func apply_daily_consumption(active_party_size: int) -> Dictionary:
	# 火种高于 15 时，每日食物消耗减少 1（不包括随机事件带来的食物变化）
	var food_cost: int = ceili(active_party_size / 2.0)
	food_cost = maxi(1, food_cost)
	if fire > FIRE_HIGH_THRESHOLD:
		food_cost = maxi(1, food_cost - 1)

	_daily_food_consumption = food_cost
	modify_food(-food_cost)
	modify_fire(-DAILY_FIRE_COST)

	return {
		"food_cost": food_cost,
		"fire_cost": DAILY_FIRE_COST,
	}


## 在每日消耗之后调用，应用 GDD 阈值规则。
## 返回角色伤害信息（调用方应将其传递给 CharacterManager）。
func apply_daily_threshold_effects(character_count: int) -> Dictionary:
	var result := {
		"damage_to_random": false,
		"morale_change": 0,
	}

	# 食物低于 5 时，每天队伍中随机一人生命值 -1
	if food < FOOD_LOW_THRESHOLD and character_count > 0:
		result["damage_to_random"] = true

	# 食物高于 15 时，每天士气 +1
	if food > FOOD_HIGH_THRESHOLD:
		result["morale_change"] += 1
		modify_morale(1)

	# 火种归零时，每天士气 -1
	if fire <= 0:
		result["morale_change"] -= 1
		modify_morale(-1)

	return result


# --- 派遣收益调整 ---

## 根据士气计算派遣收益倍率。
## 士气 > 15：+20%。士气 < 5：-20%。
func get_expedition_multiplier() -> float:
	if morale > MORALE_HIGH_THRESHOLD:
		return 1.2
	elif morale < MORALE_LOW_THRESHOLD:
		return 0.8
	return 1.0


# --- 查询 ---

func get_all_resources() -> Dictionary:
	return {
		"food": food,
		"fire": fire,
		"morale": morale,
		"people": people,
	}


# --- 存档 ---

func make_save_snapshot() -> Dictionary:
	return {
		"food": food,
		"fire": fire,
		"morale": morale,
		"people": people,
	}


func restore_from_save(data: Dictionary) -> void:
	_set_food(data.get("food", default_food))
	_set_fire(data.get("fire", default_fire))
	_set_morale(data.get("morale", default_morale))
	_set_people(data.get("people", default_people))


# --- 内部 setter（统一发出信号） ---

func _set_food(value: int) -> void:
	if food != value:
		food = value
		resource_changed.emit("food", food)


func _set_fire(value: int) -> void:
	if fire != value:
		fire = value
		resource_changed.emit("fire", fire)


func _set_morale(value: int) -> void:
	if morale != value:
		morale = value
		resource_changed.emit("morale", morale)


func _set_people(value: int) -> void:
	if people != value:
		people = value
		resource_changed.emit("people", people)
