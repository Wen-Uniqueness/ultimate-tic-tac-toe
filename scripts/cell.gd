## ============================================================================
## cell.gd — 微观棋盘中的单个格子按钮
## 负责显示 X/O、高亮、悬浮效果和最后落子标记。
## 点击事件由父级 MicroBoard 监听并转发给 GameManager。
## ============================================================================
extends Button

## 该格子在微观棋盘中的坐标
@export var cell_pos: Vector2i = Vector2i(0, 0)

## 是否标记为上一手落子位置
var is_last_move: bool = false:
	set(val):
		is_last_move = val
		_update_last_move_indicator()

## 最后落子标记的彩色方块
var _last_move_indicator: ColorRect

## 鼠标悬浮/点击时的半透明覆盖层
var _hover_overlay: ColorRect


func _ready():
	# 设置格子最小尺寸，保证可点击区域
	custom_minimum_size = Vector2(48, 48)
	size_flags_horizontal = Control.SIZE_EXPAND
	size_flags_vertical = Control.SIZE_EXPAND

	# 移除按钮默认样式，使用纯色背景
	add_theme_stylebox_override("normal", null)
	add_theme_stylebox_override("hover", null)
	add_theme_stylebox_override("pressed", null)
	add_theme_stylebox_override("disabled", null)

	# 设置字体大小
	add_theme_font_size_override("font_size", 24)

	# 创建悬浮高亮层（默认透明）
	_hover_overlay = ColorRect.new()
	_hover_overlay.name = "HoverOverlay"
	_hover_overlay.color = Color(1, 1, 1, 0)
	_hover_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hover_overlay)
	_hover_overlay.size = size
	_hover_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 创建最后落子指示器（默认隐藏）
	_last_move_indicator = ColorRect.new()
	_last_move_indicator.name = "LastMoveIndicator"
	_last_move_indicator.color = Color(1, 0.9, 0.1, 0.7)  # 金黄色半透明
	_last_move_indicator.size = Vector2(8, 8)
	_last_move_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_last_move_indicator)
	_last_move_indicator.hide()

	# 连接鼠标和按钮信号
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)


func _notification(what: int):
	if what == NOTIFICATION_RESIZED and _last_move_indicator:
		# 将最后落子标记固定在格子右下角
		_last_move_indicator.position = size - _last_move_indicator.size - Vector2(4, 4)


## 更新最后落子标记的可见性
func _update_last_move_indicator():
	if not is_inside_tree():
		return
	if _last_move_indicator:
		_last_move_indicator.visible = is_last_move


## 鼠标进入 — 显示半透明白色高亮
func _on_mouse_entered():
	if disabled:
		return
	_hover_overlay.color = Color(1, 1, 1, 0.25)


## 鼠标离开 — 高亮恢复透明
func _on_mouse_exited():
	_hover_overlay.color = Color(1, 1, 1, 0)


## 按钮按下 — 高亮变为灰色
func _on_button_down():
	if disabled:
		return
	_hover_overlay.color = Color(0.5, 0.5, 0.5, 0.4)


## 按钮抬起 — 根据是否仍悬浮恢复高亮
func _on_button_up():
	if disabled:
		return
	if is_hovered():
		_hover_overlay.color = Color(1, 1, 1, 0.25)
	else:
		_hover_overlay.color = Color(1, 1, 1, 0)


## 重置格子状态（用于新游戏）
func reset():
	text = ""
	disabled = false
	is_last_move = false
	modulate = Color(1, 1, 1, 1)
	_hover_overlay.color = Color(1, 1, 1, 0)
	show()
