## ============================================================================
## MainMenu.gd — 主菜单场景脚本
## 提供单人模式（AI）与本地双人模式的选择入口。
## ============================================================================
extends Control

## ----------------------------- 场景路径 -----------------------------
const SCENE_SINGLE := "res://scenes/single_mode.tscn"
const SCENE_MULTI  := "res://scenes/game.tscn"

## ----------------------------- 节点引用 -----------------------------
@onready var btn_single: Button = $VBoxContainer/ButtonContainer/BtnSingle
@onready var btn_multi: Button = $VBoxContainer/ButtonContainer/BtnMulti
@onready var btn_settings: Button = $VBoxContainer/ButtonContainer/BtnSettings
@onready var btn_quit: Button = $VBoxContainer/BtnQuit


func _ready():
	# 连接按钮信号
	btn_single.pressed.connect(_on_single_pressed)
	btn_multi.pressed.connect(_on_multi_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)

	# 设置按钮暂不启用（预留扩展）
	btn_settings.disabled = true
	btn_settings.mouse_default_cursor_shape = Control.CURSOR_ARROW

	# 启动淡入效果
	_fade_in()


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


## 退出游戏
func _on_quit_pressed():
	get_tree().quit()


## 处理退出键（PC 端 Esc 退出）
func _input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
