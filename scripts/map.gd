extends Control
## Map — 世界地图视图。
## MapContainer 包含地图背景和 6 个地点按钮，平移时联动。
## 点击可到达地点 → 确认弹窗 → 确认后进入行进模式。

signal close_pressed

const PAN_STEP: float = 300.0
const PAN_DURATION: float = 0.35

@onready var map_container: Control = $MapContainer
@onready var background_map: Sprite2D = $MapContainer/BackgroundMap
@onready var dispatch_button: Button = $DispatchButton
@onready var map_panel: Control = $MapPanel
@onready var confirm_dialog: Control = $ConfirmDialog
@onready var confirm_message: Label = $ConfirmDialog/Panel/VBoxContainer/MessageLabel
@onready var current_location_label: Label = $CurrentLocationLabel

# 嵌入地图的 6 个地点按钮（MapContainer 子节点，随地图平移）
var _location_buttons: Dictionary = {}
var _can_leave: bool = false
var _pending_destination: int = -1

var expedition_manager: Node = null
var character_manager: Node = null
var _current_pan_offset: float = 0.0
var _pan_limit: float = 0.0


func _ready() -> void:
	hide()
	var viewport_width: float = get_viewport().get_visible_rect().size.x
	var tex_width: float = background_map.get_rect().size.x * background_map.scale.x
	_pan_limit = maxf(0.0, (tex_width - viewport_width) / 2.0)

	if map_panel.has_signal("close_pressed"):
		map_panel.close_pressed.connect(_on_map_panel_close)

	_location_buttons = {
		GameManager.LocationID.PLAIN: $MapContainer/Plainbutton,
		GameManager.LocationID.FOREST: $MapContainer/Forestbutton,
		GameManager.LocationID.BASIN: $MapContainer/Basinbutton,
		GameManager.LocationID.VALLEY: $MapContainer/Valleybutton,
		GameManager.LocationID.GLACIER: $MapContainer/Glacierbutton,
		GameManager.LocationID.SHELTER: $MapContainer/Shelterbutton,
	}
	for loc_id in _location_buttons:
		_location_buttons[loc_id].pressed.connect(_on_location_pressed.bind(loc_id))

	# 确认弹窗按钮
	$ConfirmDialog/Panel/VBoxContainer/ButtonRow/ConfirmButton.pressed.connect(_on_confirm_travel)
	$ConfirmDialog/Panel/VBoxContainer/ButtonRow/CancelButton.pressed.connect(_on_cancel_travel)


func set_managers(exp_mgr: Node, char_mgr: Node) -> void:
	expedition_manager = exp_mgr
	character_manager = char_mgr
	map_panel.expedition_manager = exp_mgr
	map_panel.character_manager = char_mgr
	# 派遣状态变化时实时刷新地点按钮（有派遣队外出则禁用移动）
	if expedition_manager.has_signal("missions_updated"):
		expedition_manager.missions_updated.connect(_refresh_location_buttons)


func show_map() -> void:
	dispatch_button.show()
	map_panel.hide()
	confirm_dialog.hide()
	_refresh_location_buttons()
	current_location_label.text = "当前：%s | 第 %d 天" % [
		GameManager.get_location_name(GameManager.current_location),
		GameManager.current_day,
	]
	_current_pan_offset = 0.0
	map_container.position.x = 0.0
	show()


func _refresh_location_buttons() -> void:
	var current: int = GameManager.current_location
	var connected: Array = GameManager.get_connected_locations(current)
	_can_leave = GameManager.stay_days > 2

	# 有派遣队外出时禁止地点移动
	var has_active_expedition: bool = false
	if expedition_manager != null:
		has_active_expedition = not expedition_manager.get_active_missions().is_empty()

	var can_move: bool = _can_leave and not has_active_expedition
	var block_reason: String = ""
	if has_active_expedition:
		block_reason = "有派遣队外出中，无法移动"
	elif not _can_leave:
		block_reason = "需要在此地停留至少2天"

	for loc_id in _location_buttons:
		var btn: Button = _location_buttons[loc_id]
		var loc_name: String = GameManager.get_location_name(loc_id)

		if loc_id == current:
			btn.text = loc_name
			btn.disabled = true
			btn.tooltip_text = ""
		elif loc_id not in connected:
			btn.text = loc_name
			btn.disabled = true
			btn.tooltip_text = ""
		elif not can_move:
			btn.text = loc_name
			btn.disabled = true
			btn.tooltip_text = block_reason
		else:
			btn.text = loc_name
			btn.disabled = false
			btn.tooltip_text = ""


## 点击可到达地点 → 弹出确认对话框。
func _on_location_pressed(loc_id: int) -> void:
	if not _can_leave:
		return
	var connected: Array = GameManager.get_connected_locations(GameManager.current_location)
	if loc_id not in connected:
		return

	_pending_destination = loc_id
	var loc_name: String = GameManager.get_location_name(loc_id)
	confirm_message.text = "是否前往 %s ？" % loc_name
	confirm_dialog.show()


func _on_confirm_travel() -> void:
	if _pending_destination < 0:
		return
	GameManager.destination = _pending_destination
	GameManager.location_state = GameManager.LocationState.TRAVEL
	_pending_destination = -1
	confirm_dialog.hide()
	hide()
	close_pressed.emit()


func _on_cancel_travel() -> void:
	_pending_destination = -1
	confirm_dialog.hide()


func _pan_map(direction: float) -> void:
	var new_offset: float = clampf(
		_current_pan_offset + direction * PAN_STEP,
		-_pan_limit - 850,
		_pan_limit - 930
	)
	if is_equal_approx(new_offset, _current_pan_offset):
		return
	_current_pan_offset = new_offset

	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(map_container, "position:x", _current_pan_offset, PAN_DURATION)


func _on_left_pressed() -> void:
	_pan_map(1.0)


func _on_right_pressed() -> void:
	_pan_map(-1.0)


func _on_dispatch_button_pressed() -> void:
	dispatch_button.hide()
	map_panel.show_map()


func _on_map_panel_close() -> void:
	map_panel.hide()
	dispatch_button.show()
	# 从派遣界面返回后刷新地点按钮，派遣队外出则禁用移动
	_refresh_location_buttons()


func _on_close_pressed() -> void:
	hide()
	close_pressed.emit()
