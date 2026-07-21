extends Control
## SettingsPanel — 设置面板。
## 音量调节、全屏切换、返回按钮。
## 对应 GDD 线框图第 101–109 行。
## 音量通过 AudioManager 控制，不直接操作 AudioServer。

signal close_pressed

@onready var volume_slider: HSlider = %VolumeSlider
@onready var fullscreen_button: Button = %FullscreenButton
@onready var volume_label: Label = %VolumeLabel

var _is_fullscreen: bool = false
var _audio_manager: Node = null


func _ready() -> void:
	hide()
	_find_audio_manager()

	if _audio_manager and _audio_manager.has_method("get_volume"):
		volume_slider.value = _audio_manager.get_volume() * 100

	_is_fullscreen = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_update_fullscreen_label()


## 从场景树查找 AudioManager
func _find_audio_manager() -> void:
	var main_node := get_node_or_null("/root/Audiomanager")
	if main_node:
		_audio_manager = main_node.get_node_or_null("BGM")


func _on_volume_changed(value: float) -> void:
	if _audio_manager and _audio_manager.has_method("set_volume"):
		_audio_manager.set_volume(value / 100.0)
	volume_label.text = "音量：%d%%" % int(value)


func _on_fullscreen_pressed() -> void:
	_is_fullscreen = not _is_fullscreen
	if _is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_update_fullscreen_label()


func _update_fullscreen_label() -> void:
	fullscreen_button.text = "全屏：[%s]" % ("ON" if _is_fullscreen else "OFF")


func _on_close_pressed() -> void:
	hide()
	close_pressed.emit()
