extends HBoxContainer
## ResourcePanel — 右上角资源显示面板。
## 只负责显示当前资源数值，不修改数据。
## 对应 GDD：食物、火种、士气、人数。

@export var label_separator := "  |  "

@onready var food_label: Label = %FoodLabel
@onready var fire_label: Label = %FireLabel
@onready var morale_label: Label = %MoraleLabel
@onready var people_label: Label = %PeopleLabel


# 由 Main 在资源变化时调用
func update_resources(food: int, fire: int, morale: int, people: int) -> void:
	food_label.text = "食物 %d" % food
	fire_label.text = "火种 %d" % fire
	morale_label.text = "士气 %d" % morale
	people_label.text = "人数 %d" % people
