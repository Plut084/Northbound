extends Control
## TeamPanel — 队伍面板。
## 显示所有成员信息（姓名、年龄、生命值、背景、特质）。
## 可通过鼠标滚轮翻阅。只负责显示，不修改数据。

signal close_pressed

@onready var members_container: VBoxContainer = %MembersContainer
@onready var scroll_container: ScrollContainer = %ScrollContainer

var character_manager = null


func show_team(characters: Array) -> void:
	# 更新人数标签
	var alive_count := 0
	for c in characters:
		if c.hp > 0:
			alive_count += 1

	var count_label = get_node_or_null("Panel/VBoxContainer/PeopleCount")
	if count_label:
		count_label.text = "人数：%d" % alive_count

	# 清空旧的子节点并重建
	for child in members_container.get_children():
		child.queue_free()

	for c in characters:
		var card := _build_character_card(c)
		members_container.add_child(card)

	show()


func _build_character_card(c: Dictionary) -> VBoxContainer:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 4)

	# 姓名（年龄）
	var name_label := Label.new()
	name_label.text = "%s（%d岁）" % [c.get("name", ""), c.get("age", 0)]
	name_label.add_theme_font_size_override("font_size", 28)
	card.add_child(name_label)

	# 生命值
	var hp_label := Label.new()
	var hp: int = c.get("hp", 0)
	var max_hp: int = c.get("max_hp", 0)
	hp_label.text = "生命值：%d/%d" % [hp, max_hp]
	if hp <= 0:
		hp_label.text += "（已死亡）"
		hp_label.add_theme_color_override("font_color", Color.RED)
	elif hp == 1:
		hp_label.add_theme_color_override("font_color", Color.ORANGE)
	card.add_child(hp_label)

	# 派遣状态
	if character_manager != null and character_manager.is_dispatched(c.id):
		var dispatch_label := Label.new()
		dispatch_label.text = "[派遣中]"
		dispatch_label.add_theme_color_override("font_color", Color.DODGER_BLUE)
		card.add_child(dispatch_label)

	# 背景
	var bg_label := Label.new()
	bg_label.text = "\"%s\"" % c.get("background", "")
	bg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bg_label.add_theme_font_size_override("font_size", 24)
	card.add_child(bg_label)

	# 特质
	var char_trait: Dictionary = c.get("trait", {})
	if not char_trait.is_empty():
		var trait_label := Label.new()
		trait_label.text = "特质：%s" % char_trait.get("description", "")
		trait_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		trait_label.add_theme_font_size_override("font_size", 24)
		trait_label.add_theme_color_override("font_color", Color(0.276, 0.399, 0.879, 1.0))
		card.add_child(trait_label)

	# 分隔线
	var sep := HSeparator.new()
	card.add_child(sep)

	return card


func _on_close_pressed() -> void:
	hide()
	close_pressed.emit()
