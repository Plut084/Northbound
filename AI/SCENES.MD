\# SCENE\_ARCHITECTURE.md



Project: Northbound

Engine: Godot 4.x



\---



\# Purpose



本文件定义整个项目的 Scene 架构。



目标：



\- Scene 单一职责

\- Scene 可复用

\- Scene 解耦

\- Scene 易维护



任何 AI 不允许随意修改项目结构。



\---



\# Architecture



采用：



Scene + Manager



架构。



不要：



MVC



MVVM



ECS



插件框架



保持 Godot 原生设计。



\---



\# Root Scene



Main.tscn



Main



├── UI

├── World

├── Managers

└── CanvasLayer



Main 只负责：



启动游戏。



连接 Manager。



切换界面。



不要实现业务逻辑。



\---



\# Managers



Managers



├── GameManager

├── EventManager

├── ResourceManager

├── SaveManager

└── AudioManager



Manager：



负责数据。



不负责 UI。



不负责动画。



\---



\## GameManager



负责：



游戏流程。



例如：



开始游戏



进入下一天



游戏结束



暂停



恢复



不要：



直接修改 Label。



\---



\## EventManager



负责：



随机事件。



事件读取。



事件执行。



事件状态。



不要：



绘制 UI。



\---



\## ResourceManager



负责：



资源。



Food



Fire



Morale



Health



所有资源修改：



只能经过 ResourceManager。



\---



\## SaveManager



负责：



存档。



读取。



恢复。



统一入口。



不要多个地方分别保存。



\---



\## AudioManager



负责：



播放音乐。



播放音效。



不要包含游戏逻辑。



\---



\# UI



UI



├── HUD

├── EventPanel

├── ResourcePanel

├── DayPanel

├── MainMenu

└── PauseMenu



UI：



只负责显示。



禁止：



修改数据。



例如：



错误：



Button



↓



Food += 1



正确：



Button



↓



Signal



↓



GameManager



↓



ResourceManager



↓



UI 更新



\---



\# World



Northbound 属于：



文字事件游戏。



World 很简单。



以后如果增加：



地图。



旅行。



天气。



放这里。



不要放 UI。



\---



\# EventPanel



职责：



显示事件。



显示图片。



显示正文。



生成按钮。



点击按钮：



发 Signal。



不要：



直接修改资源。



\---



\# ChoiceButton



一个按钮：



一个 Scene。



便于复用。



不要：



动态创建复杂 UI。



\---



\# ResourcePanel



只负责：



显示：



Food



Fire



Morale



Health



不要：



负责计算。



\---



\# DayPanel



显示：



Day



天气



地点



仅显示。



\---



\# MainMenu



负责：



开始游戏。



继续游戏。



退出。



不要：



初始化游戏。



初始化交给 GameManager。



\---



\# PauseMenu



负责：



暂停。



继续。



返回主菜单。



不要：



保存游戏。



\---



\# Future Scenes



以后如果增加：



CharacterPanel



MapPanel



EndingPanel



Journal



保持：



独立 Scene。



不要塞进 Main。



\---



\# Scene Communication



推荐：



Signal



↓



Manager



↓



Signal



↓



UI



不要：



UI



↓



UI



↓



UI



相互调用。



\---



\# Resource Loading



Scene：



preload()



不要：



运行时频繁 load()



\---



\# Maximum Complexity



一个 Scene：



最好：



少于 15 个节点。



如果超过：



考虑拆分。



\---



\# Scene Responsibility



每个 Scene：



回答一句话：



"我负责什么？"



如果回答超过一句。



说明职责过多。



应该拆分。



\---



\# Final Principle



Scene：



负责表现。



Manager：



负责逻辑。



Data：



负责存储。



不要混用。

