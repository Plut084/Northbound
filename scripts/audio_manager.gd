extends AudioStreamPlayer2D
## AudioManager — 音频管理。
## 负责背景音乐播放、音效控制和音量调节。
## 音量通过 Godot AudioServer 总线实现，统一入口。

const LOOP_START := 28.2
const LOOP_END := 175.35

var _bus_name := "Master"


func _ready():
	seek(LOOP_START)
	play()


func _process(_delta):
	if get_playback_position() >= LOOP_END:
		seek(LOOP_START)


## 设置主音量（0.0 ~ 1.0）
func set_volume(linear: float) -> void:
	var bus_index := AudioServer.get_bus_index(_bus_name)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(clampf(linear, 0.0, 1.0)))


## 获取当前主音量（0.0 ~ 1.0）
func get_volume() -> float:
	var bus_index := AudioServer.get_bus_index(_bus_name)
	return db_to_linear(AudioServer.get_bus_volume_db(bus_index))
