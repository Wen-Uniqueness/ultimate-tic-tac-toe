## ============================================================================
## MainMenu.gd — 主菜单场景脚本
## 提供单人模式（AI）、本地双人模式选择入口，以及游戏规则弹窗。
## ============================================================================
extends Control

## ----------------------------- 场景路径 -----------------------------
const SCENE_SINGLE := "res://scenes/single_mode.tscn"
const SCENE_MULTI  := "res://scenes/game.tscn"

## ----------------------------- 节点引用 -----------------------------
@onready var btn_single: Button = $VBoxContainer/ButtonContainer/BtnSingle
@onready var btn_multi: Button = $VBoxContainer/ButtonContainer/BtnMulti
@onready var btn_settings: Button = $VBoxContainer/ButtonContainer/BtnSettings
@onready var btn_rules: Button = $VBoxContainer/ButtonContainer/BtnRules
@onready var btn_quit: Button = $VBoxContainer/BtnQuit

# 游戏规则弹窗
@onready var rules_dialog: AcceptDialog = $RulesDialog
@onready var rules_text: RichTextLabel = $RulesDialog/RulesRichText


func _ready():
	# 连接按钮信号
	btn_single.pressed.connect(_on_single_pressed)
	btn_multi.pressed.connect(_on_multi_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)
	btn_rules.pressed.connect(_on_rules_pressed)

	# 设置按钮暂不启用（预留扩展）
	btn_settings.disabled = true
	btn_settings.mouse_default_cursor_shape = Control.CURSOR_ARROW

	# 初始化规则文本
	_setup_rules_text()

	# 启动淡入效果
	_fade_in()


## 设置游戏规则对话框的 RichText 内容
func _setup_rules_text():
	rules_text.text = """[center][b]超级井字棋 — 游戏规则[/b][/center]

[color=#FFD700][b]核心玩法[/b][/color]
游戏采用 [i]双层棋盘[/i]：一个 3×3 的宏观棋盘，每个宏观格子内又是一个独立的 3×3 微观井字棋。
玩家通过占领微观棋盘来争夺宏观格子，最终在宏观棋盘上形成三连获胜。

[color=#FFD700][b]回合流程[/b][/color]
1. [i]先手[/i]：X 先落子，O 后手交替进行。
2. [i]落子限制[/i]：上一步落子的微观位置决定对手下一步的宏观目标区域。
   • 若目标微观棋盘已被占领或锁定，则可自由选择任意可用区域落子。
3. [i]微观判定[/i]：微观棋盘出现三连则被当前玩家占领；下满且无三连则平局锁定，双方均无法占领。
4. [i]宏观判定[/i]：占领或锁定的微观棋盘立刻检查宏观棋盘。若某方占领的宏观格子形成横、竖或斜三连，游戏立即结束，该方获胜。
5. [i]平局[/i]：所有微观棋盘均被占领或锁定且无人获胜，则为平局。平局锁定的大格不计入任何连线。

[color=#FFD700][b]关键要点[/b][/color]
• 宏观格子被锁定时相当于双方障碍物，不可用于连线。
• 坐标映射：微观落子的小格位置 (r, c) 决定对手下一手的宏观区域。"""

	# 设置 RichTextLabel 样式
	rules_text.add_theme_font_size_override("normal_font_size", 18)
	rules_text.add_theme_color_override("default_color", Color(0.9, 0.9, 0.95))


## 页面淡入（从透明到不透明）
func _fade_in():
	modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.4)


## 页面淡出（从不透明到透明），完成后切换场景
func _fade_out_and_switch(scene_path: String):
	# 禁用所有按钮防止重复点击
	for child in get_tree().get_nodes_in_group("menu_buttons"):
		if child is BaseButton:
			child.disabled = true

	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.3)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)


## 单人模式按钮
func _on_single_pressed():
	_fade_out_and_switch(SCENE_SINGLE)


## 本地双人模式按钮
func _on_multi_pressed():
	_fade_out_and_switch(SCENE_MULTI)


## 显示游戏规则弹窗
func _on_rules_pressed():
	rules_dialog.popup_centered(Vector2i(600, 480))


## 退出游戏
func _on_quit_pressed():
	get_tree().quit()


## 处理退出键（PC 端 Esc 退出）
func _input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
