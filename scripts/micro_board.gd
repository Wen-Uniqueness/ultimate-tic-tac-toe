## ============================================================================
## micro_board.gd — 微观棋盘控件
## 职责：显示 3x3 格子，处理点击交互，响应 GameManager 状态更新
## ============================================================================
extends Control

## 信号 - 格子合法状态下被点击时触发
signal cell_clicked(macro_pos: Vector2i, cell_pos: Vector2i)

## 该微观棋盘在宏观棋盘上的位置
@export var macro_pos: Vector2i = Vector2i(0, 0)

## 子节点引用
@onready var cell_grid: GridContainer = $CellGrid

## 格子节点列表 [row][col]
var _cells: Array[Array] = []

## Panel 半透明遮罩（锁定/获胜时显示）
var _overlay: Panel

## 胜利/锁定状态标签（展示大 X / O / 黑块）
var _state_label: Label

## 当前高亮是否激活
var _highlight_active: bool = false
var _allowed_cells: Array[Vector2i] = []

## cell.gd 资源引用
const CELL_SCRIPT = preload("res://scripts/cell.gd")


func _ready():
	var gm = _get_game_manager()
	if gm:
		cell_clicked.connect(gm._on_cell_clicked)

	cell_grid.columns = 3
	cell_grid.mouse_filter = Control.MOUSE_FILTER_PASS

	_cells.clear()
	var buttons = cell_grid.get_children()
	for i in range(buttons.size()):
		var row = i / 3
		var col = i % 3
		if row >= _cells.size():
			_cells.append([])
		_cells[row].append(buttons[i])
		if buttons[i] is BaseButton:
			if not buttons[i].get_script():
				buttons[i].set_script(CELL_SCRIPT)
			buttons[i].cell_pos = Vector2i(col, row)
			buttons[i].pressed.connect(_on_cell_pressed.bind(row, col))
			buttons[i].add_theme_stylebox_override("normal", null)
			buttons[i].add_theme_stylebox_override("hover", null)
			buttons[i].add_theme_stylebox_override("pressed", null)
			buttons[i].add_theme_stylebox_override("disabled", null)
			buttons[i].add_theme_font_size_override("font_size", 28)

	_overlay = Panel.new()
	_overlay.name = "Overlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.hide()
	add_child(_overlay)

	_state_label = Label.new()
	_state_label.name = "StateLabel"
	_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_state_label.add_theme_font_size_override("font_size", 72)
	_state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_state_label)

	set_highlight(false, [])
	_resize_overlay()


func _process(_delta):
	pass


func _notification(what: int):
	if what == NOTIFICATION_RESIZED:
		_resize_overlay()


func _resize_overlay():
	if _overlay:
		_overlay.size = size
		if _state_label:
			_state_label.size = size


func set_highlight(active: bool, allowed_cells: Array[Vector2i]):
	_highlight_active = active
	_allowed_cells = allowed_cells.duplicate()

	if _overlay and _overlay.visible:
		return

	for row in range(3):
		for col in range(3):
			var btn = _get_cell_button(row, col)
			if not btn:
				continue
			if active and _is_cell_allowed(row, col):
				btn.disabled = false
				btn.modulate = Color(1, 1, 1, 1)
				btn.self_modulate = Color(1, 1, 1, 1)
				btn.mouse_filter = Control.MOUSE_FILTER_STOP
			else:
				btn.disabled = true
				btn.modulate = Color(0.7, 0.7, 0.7, 0.6)
				btn.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if _highlight_active:
		mouse_filter = Control.MOUSE_FILTER_PASS
	else:
		mouse_filter = Control.MOUSE_FILTER_IGNORE


func _is_cell_allowed(row: int, col: int) -> bool:
	for cell_pos in _allowed_cells:
		if cell_pos.x == col and cell_pos.y == row:
			return true
	return false


func set_cell(row: int, col: int, state):
	var btn = _get_cell_button(row, col)
	if not btn:
		return

	var gm = _get_game_manager()

	var text = ""
	match state:
		gm.CellState.X:
			text = "X"
		gm.CellState.O:
			text = "O"
		_:
			text = ""

	if btn is BaseButton:
		btn.text = text
	else:
		if btn.has_method("set_text"):
			btn.set_text(text)

	match state:
		gm.CellState.X:
			btn.add_theme_color_override("font_color", Color(0.0, 0.25, 1.0, 1))
		gm.CellState.O:
			btn.add_theme_color_override("font_color", Color(1.0, 0.0, 0.0, 1))
		_:
			btn.remove_theme_color_override("font_color")


func set_lock_appearance(state):
	if not _overlay:
		return

	var gm = _get_game_manager()
	if not gm:
		return

	for row in range(3):
		for col in range(3):
			var btn = _get_cell_button(row, col)
			if not btn:
				continue
			btn.disabled = true
			match state:
				gm.BoardState.WON_BY_X:
					btn.modulate = Color(0.0, 0.25, 1.0, 0.5)
				gm.BoardState.WON_BY_O:
					btn.modulate = Color(1.0, 0.0, 0.0, 0.5)
				_:
					btn.modulate = Color(0.5, 0.5, 0.5, 0.4)

	_overlay.show()
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	match state:
		gm.BoardState.WON_BY_X:
			_state_label.text = "X"
			_state_label.modulate = Color(0.0, 0.25, 1.0, 0.5)
		gm.BoardState.WON_BY_O:
			_state_label.text = "O"
			_state_label.modulate = Color(1.0, 0.0, 0.0, 0.5)
		gm.BoardState.LOCKED:
			_state_label.text = "-"
			_state_label.modulate = Color(0.3, 0.3, 0.3, 0.5)
		_:
			_state_label.text = ""
			_state_label.modulate = Color(1, 1, 1, 0.3)


func reset_visuals():
	if _overlay:
		_overlay.hide()
		_state_label.text = ""
	mouse_filter = Control.MOUSE_FILTER_PASS

	for row in range(3):
		for col in range(3):
			var btn = _get_cell_button(row, col)
			if btn:
				if btn is BaseButton:
					btn.text = ""
				btn.disabled = true
				btn.modulate = Color(1, 1, 1, 1)

	set_highlight(false, [])


func _on_cell_pressed(row: int, col: int):
	if not _highlight_active:
		return
	if not _is_cell_allowed(row, col):
		return
	emit_signal("cell_clicked", macro_pos, Vector2i(col, row))


func _get_cell_button(row: int, col: int):
	if row < 0 or row >= _cells.size():
		return null
	if col < 0 or col >= _cells[row].size():
		return null
	return _cells[row][col]

func reset_display():
	reset_visuals()


## 动态查找 GameManager（兼容 game.tscn 和 single_mode.tscn）
func _get_game_manager():
	var gm = get_node("/root/Game/GameManager")
	if gm:
		return gm
	gm = get_node("/root/SingleMode/GameManager")
	if gm:
		return gm
	return null
