extends Control
## MapPanel — 地图/派遣面板。
## 三个标签页：派遣中任务、可派遣任务、任务完成记录。
## 对应 GDD 线框图第 418–504 行。

signal close_pressed

enum TabState { ACTIVE, AVAILABLE, COMPLETED }

@onready var active_tab_button: Button = %ActiveTabButton
@onready var available_tab_button: Button = %AvailableTabButton
@onready var completed_tab_button: Button = %CompletedTabButton
@onready var content_container: VBoxContainer = %ContentContainer

var _current_tab: TabState = TabState.AVAILABLE
var expedition_manager = null
var character_manager = null

# 派遣选择状态
var _selecting_mission: String = ""
var _selected_members: Array[String] = []
var _selection_ui: Control = null
var _go_button: Button = null
var _required_count: int = 0


func show_map() -> void:
	_switch_tab(_current_tab)
	show()


func _ready() -> void:
	hide()
	_switch_tab(TabState.AVAILABLE)


func _switch_tab(tab: TabState) -> void:
	_current_tab = tab
	_update_tab_buttons()
	_clear_content()

	match tab:
		TabState.ACTIVE:
			_build_active_missions()
		TabState.AVAILABLE:
			_build_available_missions()
		TabState.COMPLETED:
			_build_completed_missions()


func _update_tab_buttons() -> void:
	active_tab_button.button_pressed = (_current_tab == TabState.ACTIVE)
	available_tab_button.button_pressed = (_current_tab == TabState.AVAILABLE)
	completed_tab_button.button_pressed = (_current_tab == TabState.COMPLETED)


func _clear_content() -> void:
	for child in content_container.get_children():
		child.queue_free()


# --- 派遣中任务 ---

func _build_active_missions() -> void:
	if expedition_manager == null:
		return

	var missions = expedition_manager.get_active_missions()
	if missions.is_empty():
		var label := Label.new()
		label.text = "暂无进行中的派遣任务。"
		content_container.add_child(label)
		return

	for mission in missions:
		var card := _build_mission_card(mission, true)
		content_container.add_child(card)


# --- 可派遣任务 ---

func _build_available_missions() -> void:
	if expedition_manager == null:
		return

	_clear_selection_state()

	var missions = expedition_manager.get_available_missions()
	if missions.is_empty():
		var label := Label.new()
		label.text = "暂无可派遣的任务。"
		content_container.add_child(label)
		return

	for mission in missions:
		var card := _build_mission_card(mission, false)
		content_container.add_child(card)


# --- 任务完成记录 ---

func _build_completed_missions() -> void:
	if expedition_manager == null:
		return

	var missions = expedition_manager.get_completed_missions()
	if missions.is_empty():
		var label := Label.new()
		label.text = "暂无完成记录。"
		content_container.add_child(label)
		return

	# 倒序显示（最新在前）
	for i in range(missions.size() - 1, -1, -1):
		var mission = missions[i]
		var card := _build_completed_card(mission)
		content_container.add_child(card)


# --- 卡片构建 ---

func _build_mission_card(mission: Dictionary, is_active: bool) -> VBoxContainer:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 6)

	var location_label := Label.new()
	location_label.text = "地点：%s" % mission.get("location", "")
	location_label.add_theme_font_size_override("font_size", 26)
	card.add_child(location_label)

	var people_label := Label.new()
	people_label.text = "人数：%d" % mission.get("required_people", 0)
	card.add_child(people_label)

	var desc_label := Label.new()
	desc_label.text = "任务描述：%s" % mission.get("description", "")
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(desc_label)

	if is_active:
		var remaining = mission.get("end_day", 0) - GameManager.current_day
		var status_label := Label.new()
		status_label.text = "剩余 %d 天" % maxi(0, remaining)
		status_label.add_theme_color_override("font_color", Color.DODGER_BLUE)
		card.add_child(status_label)

		var members_label := Label.new()
		members_label.text = "派遣队员：%s" % ", ".join(mission.get("member_ids", []))
		card.add_child(members_label)
	else:
		var dispatch_button := Button.new()
		dispatch_button.text = "派遣"
		dispatch_button.pressed.connect(_on_dispatch_pressed.bind(mission.id))
		card.add_child(dispatch_button)

	var sep := HSeparator.new()
	card.add_child(sep)

	return card


func _build_completed_card(mission: Dictionary) -> VBoxContainer:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 4)

	var location_label := Label.new()
	location_label.text = "地点：%s" % mission.get("location", "")
	card.add_child(location_label)

	var effects: Dictionary = mission.get("effects", {})
	var effects_text := "获得："
	for key in effects:
		var name := _resource_name(key)
		effects_text += "%s+%d " % [name, effects[key]]
	var effects_label := Label.new()
	effects_label.text = effects_text
	card.add_child(effects_label)

	var day_label := Label.new()
	day_label.text = "完成于第 %d 天" % mission.get("completed_day", 0)
	day_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	card.add_child(day_label)

	var sep := HSeparator.new()
	card.add_child(sep)

	return card


# --- 派遣流程 ---

func _on_dispatch_pressed(mission_id: String) -> void:
	_selecting_mission = mission_id
	_selected_members.clear()
	_build_selection_ui(mission_id)


func _build_selection_ui(mission_id: String) -> void:
	_clear_content()

	if character_manager == null:
		return

	# 查找任务要求
	_required_count = 0
	for m in expedition_manager.get_available_missions():
		if m.id == mission_id:
			_required_count = m.get("required_people", 0)
			break

	# 标题
	var title := Label.new()
	title.text = "选择派遣队员（需要 %d 人）" % _required_count
	title.add_theme_font_size_override("font_size", 28)
	content_container.add_child(title)

	# 可选成员列表
	var available = character_manager.get_dispatchable_members()
	if available.is_empty():
		var label := Label.new()
		label.text = "没有可派遣的队员。"
		content_container.add_child(label)
		return

	for member in available:
		var check := CheckBox.new()
		check.text = "%s（HP: %d/%d）" % [member.name, member.hp, member.max_hp]
		check.set_meta("member_id", member.id)
		check.toggled.connect(_on_member_toggled.bind(member.id, check))
		content_container.add_child(check)

	# 按钮行
	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 16)

	var back_button := Button.new()
	back_button.text = "返回"
	back_button.pressed.connect(_on_selection_back)
	button_row.add_child(back_button)

	_go_button = Button.new()
	_go_button.text = "出发"
	_go_button.disabled = true
	_go_button.pressed.connect(_on_go_pressed)
	button_row.add_child(_go_button)

	content_container.add_child(button_row)


func _on_member_toggled(toggled_on: bool, member_id: String, check: CheckBox) -> void:
	if toggled_on:
		if member_id not in _selected_members:
			_selected_members.append(member_id)
	else:
		_selected_members.erase(member_id)

	# 达到所需人数时，禁用所有未选中的复选框
	var at_limit := _selected_members.size() >= _required_count
	for child in content_container.get_children():
		if child is CheckBox and not child.button_pressed:
			child.disabled = at_limit

	# 更新出发按钮状态
	if _go_button:
		_go_button.disabled = (_selected_members.size() != _required_count)


func _on_go_pressed() -> void:
	if expedition_manager == null:
		return

	expedition_manager.start_mission(_selecting_mission, _selected_members)
	_clear_selection_state()
	_switch_tab(TabState.ACTIVE)


func _on_selection_back() -> void:
	_clear_selection_state()
	_switch_tab(TabState.AVAILABLE)


func _clear_selection_state() -> void:
	_selecting_mission = ""
	_selected_members.clear()
	_selection_ui = null
	_go_button = null
	_required_count = 0


# --- 标签页切换 ---

func _on_active_tab_pressed() -> void:
	_switch_tab(TabState.ACTIVE)


func _on_available_tab_pressed() -> void:
	_switch_tab(TabState.AVAILABLE)


func _on_completed_tab_pressed() -> void:
	_switch_tab(TabState.COMPLETED)


func _on_close_pressed() -> void:
	hide()
	close_pressed.emit()


func _resource_name(key: String) -> String:
	match key:
		"food": return "食物"
		"fire": return "火种"
		_: return key
