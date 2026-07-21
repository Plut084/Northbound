extends Label
## DayPanel — 天数显示。
## 只负责显示当前天数，不涉及游戏逻辑。

# 由 GameManager 在天数变化时调用
func update_day(day: int) -> void:
	text = "第 %d 天" % day
