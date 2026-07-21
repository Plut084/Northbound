\# GODOT\_RULES.md



Project: Northbound

Engine: Godot 4.x

Language: GDScript



\---



\# Purpose



本文件用于约束所有 AI 在 Northbound 项目中的 Godot 开发方式。



目标：



保持代码一致性。



保持结构简单。



保持 Demo 能快速迭代。



任何情况下：



不要为了"更高级"而增加复杂度。



\---



\# First Principle



永远优先：



可运行



而不是：



可扩展。



Northbound 是一个独立游戏项目。



不是通用游戏框架。



不要设计框架。



不要设计引擎。



不要提前封装未来可能不会使用的功能。



\---



\# Project Architecture



项目采用：



Scene + Manager



架构。



不要使用：



ECS



MVVM



复杂依赖注入



插件式框架



大型状态机框架



保持 Godot 原生开发方式。



\---



\# Folder Structure



res://



assets/



audio/



fonts/



images/



scenes/



scripts/



ui/



resources/



save/



不要创建无意义目录。



例如：



Core/



Framework/



Engine/



Runtime/



Infrastructure/



\---



\# Scene Rules



每个 Scene 只负责一件事情。



例如：



Main



EventPanel



ChoiceButton



StatusBar



MainMenu



不要出现：



一个 Scene 包含整个游戏。



Scene 应尽量小。



便于复用。



\---



\# Script Rules



一个脚本：



一个职责。



如果脚本超过：



300 行。



优先考虑拆分。



如果函数超过：



40 行。



优先考虑拆分。



\---



\# Node Naming



节点统一使用 PascalCase。



例如：



Main



StatusBar



EventPanel



ChoiceButton



错误：



panel1



testNode



button\_new



\---



\# Variables



成员变量：



snake\_case



例如：



food



morale



current\_day



不要：



foodNum



Food



CurrentDay



\---



\# Constants



使用：



const



全部大写。



例如：



MAX\_FOOD



EVENT\_PATH



\---



\# Export



所有可调参数：



必须使用：



@export



例如：



@export var max\_food := 10



禁止：



代码内部写死。



\---



\# Signals



优先使用：



Signal



不要直接跨节点调用。



推荐：



signal event\_finished



signal day\_changed



signal resource\_changed



不要：



Main.get\_node(...)



\---



\# Node Access



优先：



@onready



不要：



每次都 get\_node()



推荐：



@onready var event\_panel = $EventPanel



\---



\# Singleton



AutoLoad 数量：



尽量少。



推荐：



GameManager



SaveManager



不要：



EventManager



UIManager



AudioManager



WeatherManager



InventoryManager



全部 Singleton。



\---



\# Managers



Manager 负责：



数据。



不要负责：



UI。



例如：



GameManager



保存：



资源



日期



角色



不要：



更新 Label。



\---



\# UI Rules



UI 不允许：



修改游戏数据。



UI 只负责：



显示。



所有数据修改：



交给 Manager。



\---



\# Event System



事件必须：



数据驱动。



不要：



把事件写死在代码里。



推荐：



JSON



Resource



Dictionary



读取事件。



\---



\# Save System



统一：



Dictionary



序列化。



不要：



多个脚本分别保存。



统一入口：



SaveManager



\---



\# Random



统一：



RandomNumberGenerator



不要：



randomize()



不要：



randf()



到处调用。



\---



\# Magic Number



禁止：



if hp > 37



使用：



const



或者：



@export



\---



\# Comments



不要解释：



代码做了什么。



解释：



为什么这样设计。



例如：



错误：



\# 加一



food += 1



正确：



\# 玩家完成一天后恢复少量食物，

\# 用于降低前期失败率。



\---



\# Error Handling



任何读取资源：



必须判断：



是否为空。



不要默认存在。



\---



\# Performance



Demo 阶段：



不要提前优化。



不要缓存一切。



不要对象池。



不要复杂算法。



优先：



代码可读。



\---



\# Resource Loading



优先：



preload()



固定资源。



使用：



load()



动态资源。



\---



\# State



尽量减少：



bool



例如：



不要：



is\_open



is\_show



is\_start



is\_end



过多。



优先：



enum。



例如：



enum GameState



\---



\# Enum



推荐：



enum DayState



enum EventState



enum MenuState



不要：



字符串判断。



\---



\# Dependency



禁止：



循环依赖。



禁止：



Scene A



引用



Scene B



同时



Scene B



引用



Scene A。



\---



\# Debug



Debug 信息：



统一：



print\_debug()



不要：



print()



到处都是。



\---



\# Testing



每增加一个功能：



必须验证：



能够进入下一天。



资源不会异常。



存档正常。



事件正常结束。



\---



\# AI Rules



AI 不允许：



为了代码优雅：



重构整个项目。



如果开发者没有明确提出：



不要：



修改已有架构。



不要：



替换已有系统。



保持：



最小改动。



\---



\# Final Principle



任何代码提交前：



问自己三个问题：



① 是否更简单？



② 是否符合 Godot 官方推荐？



③ 是否符合 MVP？



如果答案不是三个"是"，



停止修改。



