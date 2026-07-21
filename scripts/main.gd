extends Control
## Main — 游戏主界面。
## 串联所有 Manager 和 UI 面板，协调核心循环。
## 只负责连接和调度，不实现业务逻辑。

# --- Managers ---
@onready var event_manager: Node = $Managers/EventManager
@onready var resource_manager: Node = $Managers/ResourceManager
@onready var character_manager: Node = $Managers/CharacterManager
@onready var expedition_manager: Node = $Managers/ExpeditionManager

# --- UI ---
@onready var day_panel: Label = $TopBar/DayPanel
@onready var resource_panel: HBoxContainer = $TopBar/ResourcePanel
@onready var event_panel: Control = $EventPanel
@onready var event_notification: Button = $BottomBar/EventNotification
@onready var next_day_button: Button = $BottomBar/NextDayButton
@onready var info_popup: Control = $InfoPopup
@onready var victory_popup: Control = $VictoryPopup
@onready var game_over_popup: Control = $GameOverPopup
@onready var pause_menu: Control = $PauseMenu
@onready var story_intro: Control = $StoryIntro

# --- Panels ---
@onready var journal_panel: Control = $Panels/JournalPanel
@onready var team_panel: Control = $Panels/TeamPanel
@onready var map_view: Control = $Panels/Map
@onready var settings_panel: Control = $Panels/SettingsPanel
@onready var menu_button: Button = $TopBar/MenuButton
@onready var snow_transition: Sprite2D = $SnowTransition

# --- Travel ---
@onready var travel_panel: Control = $Panels/TravelPanel

# --- Background ---
@onready var background_main: Sprite2D = $BackgroundMain

# 地点背景图映射（只配置已有图片的地点）
const BACKGROUND_PATHS: Dictionary = {
	GameManager.LocationID.PLAIN: "res://asserts/background_plain.png",
	GameManager.LocationID.FOREST: "res://asserts/background_forest.png",
	GameManager.LocationID.BASIN: "res://asserts/background_basin.png",
	GameManager.LocationID.VALLEY: "res://asserts/background_valley.png",
	GameManager.LocationID.GLACIER: "res://asserts/background_glacier.png",
}

# 日志记录
var _journal_entries: Array = []

# 当前事件是否已处理完
var _event_resolved: bool = false
# 当前待处理的事件数据
var _pending_event: Dictionary = {}
# 行进模式中打开日志——关闭时需要恢复 TravelPanel
var _journal_from_travel: bool = false


func _ready() -> void:
	var is_loading: bool = SaveManager.is_loading_save()

	# 先初始化 Manager（设置默认值、加载数据文件）
	_initialize_managers()
	_connect_signals()

	# 读档恢复——在默认值初始化后用存档数据覆盖
	if is_loading:
		var data: Dictionary = SaveManager.consume_restore_data()
		if not data.is_empty():
			resource_manager.restore_from_save(data.get("resources", {}))
			character_manager.restore_from_save(data.get("characters", {}))
			expedition_manager.restore_from_save(data.get("expeditions", {}))
			_journal_entries = data.get("journal", []).duplicate()
		var em_state: Dictionary = SaveManager.consume_em_state()
		if not em_state.is_empty():
			event_manager.restore_save_state(em_state)

	_update_all_panels()

	if is_loading:
		_on_game_ready()
	else:
		_set_bottom_buttons_disabled(true)
		story_intro.show_intro()


func _initialize_managers() -> void:
	# ResourceManager 初始化资源
	resource_manager.init_resources()

	# CharacterManager 加载角色
	character_manager.load_characters()

	# EventManager 设置引用
	event_manager.resource_manager = resource_manager
	event_manager.character_manager = character_manager

	# ExpeditionManager 设置引用并加载任务
	expedition_manager.resource_manager = resource_manager
	expedition_manager.character_manager = character_manager
	expedition_manager.load_missions()

	# TeamPanel 设置引用
	team_panel.character_manager = character_manager

	# Map 视图设置引用（会转发给内嵌的 MapPanel）
	if map_view.has_method("set_managers"):
		map_view.set_managers(expedition_manager, character_manager)


func _connect_signals() -> void:
	# 故事过场
	story_intro.intro_finished.connect(_on_intro_finished)

	# 事件流
	event_manager.event_ready.connect(_on_event_ready)
	event_panel.choice_selected.connect(_on_choice_selected)
	event_panel.continue_pressed.connect(_on_event_continue)
	event_panel.system_event_confirmed.connect(_on_system_event_confirmed)
	event_manager.effects_applied.connect(_on_effects_applied)
	info_popup.confirmed.connect(_on_info_confirmed)

	# 胜利/失败
	GameManager.game_won.connect(_on_game_won)
	GameManager.game_lost.connect(_on_game_lost)
	game_over_popup.restart_pressed.connect(_on_restart)
	game_over_popup.quit_to_menu_pressed.connect(_on_game_over_quit)

	# ResourceManager 资源变化 → UI 更新
	resource_manager.resource_changed.connect(_on_resource_changed)

	# CharacterManager 角色变化
	character_manager.character_died.connect(_on_character_died)

	# ExpeditionManager
	expedition_manager.missions_updated.connect(_update_all_panels)

	# 暂停菜单
	pause_menu.resume_game.connect(_on_pause_resume)
	pause_menu.save_game.connect(_on_pause_save)
	pause_menu.load_game.connect(_on_pause_load)
	pause_menu.quit_to_menu.connect(_on_pause_quit)

	# Map 视图
	map_view.close_pressed.connect(_on_map_closed)

	# 面板关闭信号
	journal_panel.close_pressed.connect(_on_journal_closed)
	team_panel.close_pressed.connect(_update_all_panels)
	settings_panel.close_pressed.connect(_update_all_panels)

	# 底部按钮
	event_notification.pressed.connect(_on_event_notification_pressed)
	next_day_button.pressed.connect(_on_next_day_pressed)

	# 地点 / 行进
	travel_panel.travel_next_day_pressed.connect(_on_travel_next_day_pressed)
	travel_panel.journal_pressed.connect(_on_journal_pressed)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not story_intro.visible:
		_toggle_pause()


# --- 故事过场 ---

func _on_intro_finished() -> void:
	_set_bottom_buttons_disabled(false)
	# 读档时可能没有 em_state，需要初始化
	var em_state: Dictionary = SaveManager.consume_em_state()
	if not em_state.is_empty():
		event_manager.restore_save_state(em_state)
	_on_game_ready()


func _on_game_ready() -> void:
	_update_all_panels()
	# 更新队伍面板人数
	if team_panel.has_node("Panel/VBoxContainer/PeopleCount"):
		team_panel.get_node("Panel/VBoxContainer/PeopleCount").text = "人数：%d" % character_manager.get_party_size()
	_on_day_advanced()


# --- 事件流 ---

func _pick_new_event() -> void:
	event_manager.get_random_event()
	_event_resolved = false


func _on_event_ready(event_data: Dictionary) -> void:
	# 事件可用——显示 (!事件) 通知
	_pending_event = event_data
	event_notification.visible = true
	event_notification.disabled = false
	next_day_button.disabled = true


func _on_event_notification_pressed() -> void:
	event_notification.visible = false
	event_panel.display_event(_pending_event)
	event_panel.show()


func _on_choice_selected(choice_index: int) -> void:
	event_manager.apply_choice(choice_index)


## 系统事件（无选择）的"确认"按钮回调。
## apply_event_effects 内部应用效果并发出 effects_applied，
## 后续由 _on_effects_applied → _on_info_confirmed → display_result 处理。
func _on_system_event_confirmed() -> void:
	event_manager.apply_event_effects()


func _on_effects_applied(_effects: Dictionary) -> void:
	# 应用特质减免后再显示效果
	info_popup.show_effects(_effects)


func _on_info_confirmed() -> void:
	event_panel.display_result(event_manager.get_last_result_text())
	_update_all_panels()

	# 检查游戏结束条件
	var morale: int = resource_manager.morale
	var alive: int = character_manager.get_alive_count()
	if GameManager.check_game_over(morale, alive):
		return


func _on_event_continue() -> void:
	event_panel.hide()
	_event_resolved = true
	next_day_button.disabled = false
	event_notification.visible = false

	# 检查胜利条件
	if GameManager.state == GameManager.GameState.GAME_OVER:
		return

	# 记录日志
	var last_result: String = event_manager.get_last_result_text()
	_journal_entries.append({
		"day": GameManager.current_day,
		"text": last_result,
	})
	_update_all_panels()


# --- 下一天 ---

func _on_next_day_pressed() -> void:
	if not _event_resolved:
		return

	# 禁用按钮防止重复点击
	next_day_button.disabled = true
	_play_snow_transition()


## 风雪过渡动画：素材从左侧滑入、滑向右侧消失。
func _play_snow_transition() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var tex_size: Vector2 = snow_transition.get_rect().size * snow_transition.scale

	# 起始位置：完全在屏幕左侧之外
	snow_transition.position.x = -tex_size.x
	snow_transition.visible = true

	var tween: Tween = create_tween()
	tween.tween_property(snow_transition, "position:x", viewport_size.x + tex_size.x, 0.6)
	tween.finished.connect(_on_snow_transition_finished)


func _on_snow_transition_finished() -> void:
	snow_transition.visible = false
	_execute_next_day()


## 实际执行天数推进逻辑，在风雪动画之后调用。
func _execute_next_day() -> void:
	# 1. 检查派遣任务完成情况
	var completed: Array = expedition_manager.check_completions()
	for mission in completed:
		_journal_entries.append({
			"day": GameManager.current_day,
			"text": "派遣任务完成：%s" % mission.get("location", ""),
		})

	# 2. 应用每日消耗
	var party_size: int = character_manager.get_party_size()
	resource_manager.apply_daily_consumption(party_size)

	# 3. 应用特质效果
	var morale_bonus: int = character_manager.get_morale_story_bonus()
	if morale_bonus > 0:
		resource_manager.modify_morale(morale_bonus)
	var food_bonus: int = character_manager.get_food_production_bonus()
	if food_bonus > 0:
		resource_manager.modify_food(food_bonus)

	# 4. 应用阈值效果
	var threshold_result: Dictionary = resource_manager.apply_daily_threshold_effects(character_manager.get_alive_count())
	if threshold_result.get("damage_to_random", false):
		var target_id: String = character_manager.damage_random_alive(1)
		if target_id != "":
			_journal_entries.append({
				"day": GameManager.current_day,
				"text": "%s 因饥饿而受伤。" % target_id,
			})

	# 5. 驻留天数 +1
	GameManager.stay_days += 1

	# 6. 推进天数
	GameManager.advance_day()

	# 7. 检查游戏结束
	var morale: int = resource_manager.morale
	var alive: int = character_manager.get_alive_count()
	if morale <= 0:
		# 士气归零触发失败事件
		var game_over_event: Dictionary = _find_system_event("game_over_morale")
		if not game_over_event.is_empty():
			event_manager._current_event = game_over_event
			event_manager.event_ready.emit(game_over_event)
		else:
			GameManager.check_game_over(morale, alive)
		return

	if GameManager.check_game_over(morale, alive):
		return

	# 8. 进入新的一天
	_update_all_panels()
	_on_day_advanced()


func _find_system_event(id: String) -> Dictionary:
	for event in event_manager._all_events:
		if event.id == id:
			return event
	return {}


# --- 每日状态流转 ---

## 每天推进后的入口：根据 location_state 决定 UI 和流程。
func _on_day_advanced() -> void:
	_update_background()
	if GameManager.location_state == GameManager.LocationState.TRAVEL:
		_enter_travel_mode()
	else:
		_handle_stay_day_start()


## Stay 状态下的新一天开始。
## 移动功能已移至地图界面——玩家通过地图按钮自行选择去向。
func _handle_stay_day_start() -> void:
	_show_stay_ui()
	_pick_new_event()


# --- 行进模式 ---

## 进入行进模式：隐藏 Stay UI，显示 Travel 面板。
func _enter_travel_mode() -> void:
	_hide_stay_ui()
	travel_panel.show_travel()
	_update_all_panels()


## 行进途中点击"下一天"——抵达目的地。
func _on_travel_next_day_pressed() -> void:
	# 1. 应用每日消耗
	var party_size: int = character_manager.get_party_size()
	resource_manager.apply_daily_consumption(party_size)

	# 2. 应用特质效果
	var morale_bonus: int = character_manager.get_morale_story_bonus()
	if morale_bonus > 0:
		resource_manager.modify_morale(morale_bonus)

	# 3. 应用阈值效果
	var threshold_result: Dictionary = resource_manager.apply_daily_threshold_effects(
		character_manager.get_alive_count()
	)
	if threshold_result.get("damage_to_random", false):
		var target_id: String = character_manager.damage_random_alive(1)
		if target_id != "":
			_journal_entries.append({
				"day": GameManager.current_day,
				"text": "%s 在行进中因饥饿而受伤。" % target_id,
			})

	# 3.5 检查派遣任务完成情况
	var completed: Array = expedition_manager.check_completions()
	for mission in completed:
		_journal_entries.append({
			"day": GameManager.current_day,
			"text": "派遣任务完成：%s" % mission.get("location", ""),
		})

	# 4. 抵达目的地
	GameManager.current_location = GameManager.destination
	GameManager.stay_days = 1
	GameManager.location_state = GameManager.LocationState.STAY

	# 5. 写日志
	var loc_name: String = GameManager.get_location_name(GameManager.current_location)
	_journal_entries.append({
		"day": GameManager.current_day,
		"text": "队伍抵达了%s。" % loc_name,
	})

	# 6. 检查胜利（抵达避难所）
	if GameManager.check_victory():
		return

	# 7. 检查游戏结束
	var morale: int = resource_manager.morale
	var alive: int = character_manager.get_alive_count()
	if morale <= 0:
		# 士气归零，触发 game_over_morale 事件
		var game_over_event: Dictionary = _find_system_event("game_over_morale")
		if not game_over_event.is_empty():
			event_manager._current_event = game_over_event
			event_manager.event_ready.emit(game_over_event)
		else:
			GameManager.check_game_over(morale, alive)
		return
	if GameManager.check_game_over(morale, alive):
		return

	# 8. 推进天数
	GameManager.advance_day()

	# 9. 恢复 Stay UI 并进入新一天
	travel_panel.hide()
	_update_all_panels()
	_on_day_advanced()


# --- UI 模式切换 ---

## 隐藏 Stay 专属的 UI（事件面板、底部按钮等）。
func _hide_stay_ui() -> void:
	event_panel.hide()
	event_notification.visible = false
	next_day_button.visible = false
	for child in $BottomBar.get_children():
		if child is Button:
			child.visible = false


## 恢复 Stay 模式的 UI。
## 注意：不恢复 EventNotification —— 它只在事件就绪时由 _on_event_ready 显示。
func _show_stay_ui() -> void:
	for child in $BottomBar.get_children():
		if child is Button and child != event_notification:
			child.visible = true
	next_day_button.visible = true
	# 恢复按钮可用状态
	_set_bottom_buttons_disabled(false)


# --- 资源变化 ---

func _on_resource_changed(_resource_name: String, _new_value: int) -> void:
	_update_all_panels()


# --- 角色死亡 ---

func _on_character_died(character: Dictionary) -> void:
	# 人数减少
	resource_manager.modify_people(-1)
	_journal_entries.append({
		"day": GameManager.current_day,
		"text": "%s 倒下了，再也没有起来。" % character.get("name", ""),
	})
	_update_all_panels()

	var alive: int = character_manager.get_alive_count()
	if alive <= 0:
		GameManager.check_game_over(resource_manager.morale, alive)


# --- 胜利/失败 ---

func _on_game_won() -> void:
	# 行进模式下触发胜利时，TravelPanel 可能尚未隐藏，先关闭再弹窗
	travel_panel.hide()
	victory_popup.show_victory()


func _on_game_lost() -> void:
	# 行进模式下触发失败时同理
	travel_panel.hide()
	var alive: int = character_manager.get_alive_count()
	game_over_popup.show_game_over(GameManager.current_day, alive)


func _on_restart() -> void:
	GameManager.start_new_game()


func _on_game_over_quit() -> void:
	GameManager.end_game()


# --- 暂停 ---

func _toggle_pause() -> void:
	if pause_menu.visible:
		pause_menu.hide_menu()
	else:
		pause_menu.show_menu()


func _on_pause_resume() -> void:
	pause_menu.hide_menu()


func _on_pause_save() -> void:
	var data: Dictionary = _make_full_save_snapshot()
	SaveManager.save_game(data)


func _on_pause_load() -> void:
	var data: Dictionary = SaveManager.load_game()
	if data.is_empty():
		return
	GameManager.restore_from_save(data)
	SaveManager.prepare_load(data)
	get_tree().reload_current_scene()


func _on_pause_quit() -> void:
	GameManager.end_game()


# --- 存档 ---

func _make_full_save_snapshot() -> Dictionary:
	var data: Dictionary = GameManager.make_save_snapshot()
	data["resources"] = resource_manager.make_save_snapshot()
	data["characters"] = character_manager.make_save_snapshot()
	data["expeditions"] = expedition_manager.make_save_snapshot()
	data["journal"] = _journal_entries.duplicate()
	data["event_save_state"] = event_manager.get_save_state()
	return data


func _restore_from_save(data: Dictionary) -> void:
	GameManager.restore_from_save(data)
	resource_manager.restore_from_save(data.get("resources", {}))
	character_manager.restore_from_save(data.get("characters", {}))
	expedition_manager.restore_from_save(data.get("expeditions", {}))
	_journal_entries = data.get("journal", []).duplicate()
	SaveManager.store_em_state(data.get("event_save_state", {}))


# --- 底部按钮回调 ---

## 在故事过场期间禁用所有交互按钮，防止玩家误操作。
func _set_bottom_buttons_disabled(disabled: bool) -> void:
	menu_button.disabled = disabled
	for child in $BottomBar.get_children():
		if child is Button:
			child.disabled = disabled


func _on_journal_pressed() -> void:
	# 行进模式下 TravelPanel 会拦截日志面板的点击事件，
	# 打开日志时先隐藏 TravelPanel，关闭时通过 _on_journal_closed 恢复
	if travel_panel.visible:
		travel_panel.hide()
		_journal_from_travel = true
	journal_panel.show_journal(_journal_entries)


## 日志面板关闭回调——行进模式下需恢复 TravelPanel。
func _on_journal_closed() -> void:
	if _journal_from_travel:
		travel_panel.show_travel()
		_journal_from_travel = false
	_update_all_panels()


func _on_team_pressed() -> void:
	team_panel.show_team(character_manager.get_all_characters())


func _on_map_pressed() -> void:
	map_view.show_map()


## 地图关闭回调：如果玩家选择了目的地（location_state 变为 TRAVEL），进入行进模式。
## 如果仅查看地图（未选择目的地），只刷新面板，不改变按钮禁用状态。
func _on_map_closed() -> void:
	if GameManager.location_state == GameManager.LocationState.TRAVEL:
		_enter_travel_mode()
	else:
		_update_all_panels()


func _on_menu_pressed() -> void:
	_toggle_pause()


func _on_settings_pressed() -> void:
	settings_panel.show()


# --- UI 更新 ---

## 根据当前地点切换主界面背景图。
func _update_background() -> void:
	var path: String = BACKGROUND_PATHS.get(GameManager.current_location, "")
	if path.is_empty():
		return
	var tex: Texture2D = load(path)
	if tex:
		background_main.texture = tex


func _update_all_panels() -> void:
	var r: Dictionary = resource_manager.get_all_resources()

	# DayPanel
	if day_panel.has_method("update_day"):
		day_panel.update_day(GameManager.current_day)

	# ResourcePanel
	if resource_panel.has_method("update_resources"):
		resource_panel.update_resources(
			r.get("food", 0),
			r.get("fire", 0),
			r.get("morale", 0),
			r.get("people", 0)
		)
