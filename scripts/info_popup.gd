extends Control
## InfoPopup — 资源变化提示弹窗。
## 显示资源增减。只显示，不修改数据。

signal confirmed

const RESOURCE_NAMES: Dictionary = {
	"food": "食物",
	"fire": "火种",
	"morale": "士气",
	"people": "人数",
}

@onready var changes_label: Label = %ChangesLabel


func show_effects(effects: Dictionary) -> void:
	var lines: Array = []

	# 资源变化
	for key in effects:
		if key == "_health_details":
			continue
		var value: int = effects[key]
		if value == 0:
			continue
		var name: String = RESOURCE_NAMES.get(key, key)
		var sign := "+" if value > 0 else ""
		lines.append("%s %s%d" % [name, sign, value])

	if lines.is_empty():
		changes_label.text = "一切照旧，没有变化。"
	else:
		changes_label.text = "\n".join(lines)

	show()


func _on_confirm_button_pressed() -> void:
	hide()
	confirmed.emit()
