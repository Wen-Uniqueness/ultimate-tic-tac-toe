## ============================================================================

## game_manager.gd — 超级井字棋 全局游戏管理器

## 负责维护所有游戏状态、规则判定、UI 更新。

## ============================================================================

extends Node





## ----------------------------- 常量与枚举 -----------------------------

enum CellState { EMPTY, X, O }

enum BoardState { IN_PLAY, WON_BY_X, WON_BY_O, LOCKED }



## ----------------------------- 微观棋盘内部类 -----------------------------

class MicroBoard:

	var cells: Array[Array]  # 3x3 二维数组，存储 CellState



	func _init():

		# 初始化为全空棋盘

		cells = []

		for i in range(3):

			var row: Array[CellState] = []

			for j in range(3):

				row.append(CellState.EMPTY)

			cells.append(row)



	## 在指定位置落子，成功返回 true

	func place(row: int, col: int, player: CellState) -> bool:

		if row < 0 or row >= 3 or col < 0 or col >= 3:

			return false

		if cells[row][col] != CellState.EMPTY:

			return false

		cells[row][col] = player

		return true



	## 检查当前微观棋盘是否有玩家三连获胜，返回获胜玩家（X/O）或 EMPTY

	func check_win() -> CellState:

		return _check_win_for_state(cells)



	## 静态工具方法：传入 3x3 网格，判断是否有人连成一线

	static func _check_win_for_state(grid: Array[Array]) -> CellState:

		# 横

		for r in range(3):

			if grid[r][0] != CellState.EMPTY and grid[r][0] == grid[r][1] and grid[r][1] == grid[r][2]:

				return grid[r][0]

		# 竖

		for c in range(3):

			if grid[0][c] != CellState.EMPTY and grid[0][c] == grid[1][c] and grid[1][c] == grid[2][c]:

				return grid[0][c]

		# 对角线

		if grid[0][0] != CellState.EMPTY and grid[0][0] == grid[1][1] and grid[1][1] == grid[2][2]:

			return grid[0][0]

		if grid[0][2] != CellState.EMPTY and grid[0][2] == grid[1][1] and grid[1][1] == grid[2][0]:

			return grid[0][2]

		return CellState.EMPTY



	## 判断棋盘是否已满（无空格）

	func is_full() -> bool:

		for r in range(3):

			for c in range(3):

				if cells[r][c] == CellState.EMPTY:

					return false

		return true





## ----------------------------- 信号 -----------------------------

signal move_made(macro_pos: Vector2i, cell_pos: Vector2i)

signal game_ended(result: Dictionary)   # result 包含 "result" (win/draw) 和 "winner" (CellState)

signal last_move_changed(macro_pos, cell_pos)  # 上一手落子位置变化信号，历史为空时两个参数均为 null
signal ai_started_thinking()

signal ai_finished_thinking()





## ----------------------------- 游戏状态变量 -----------------------------

var current_player: CellState = CellState.X

var next_macro: Vector2i = Vector2i(-1, -1)  # (-1,-1) 表示无限制，可任意选择

var macro_boards: Array[MicroBoard]          # 9 个微观棋盘实例

var macro_states: Array[BoardState]          # 9 个宏观格状态

var move_history: Array[Dictionary]          # 历史记录，用于悔棋

var game_over: bool = false



## ----------------------------- AI 相关变量 -----------------------------

var _ai_thinking: bool = false

var _ai_turn: bool = false



## 玩家使用的棋子（X 或 O），AI 则使用另一个

var _player_side: int = CellState.X



## ----------------------------- 节点引用 -----------------------------

var _board_node: Node2D

var _macro_win_line: Line2D

var _status_label: Label

var _free_choice_hint: Label

var _undo_button: Button



## AI 对手节点（在场景中通过 Inspector 或自动查找设置）

@export var ai_player_node: Node = null



## 存储已发现的微观棋盘节点（键：Vector2i，值：节点引用）

var _micro_board_nodes: Dictionary = {}





## ----------------------------- 初始化 -----------------------------

func _ready():

	if ai_player_node == null:

		ai_player_node = get_node_or_null("../AIPlayer")



	# 动态获取当前场景根路径

	var root_name = "/root/" + get_tree().current_scene.name



	_board_node = get_node(root_name + "/Board") as Node2D

	if not _board_node:

		_board_node = get_node("/root/SingleMode/Board") as Node2D



	_macro_win_line = _board_node.get_node("MacroWinLine") as Line2D

	var ui_layer: CanvasLayer = get_node(root_name + "/UI") as CanvasLayer

	if not ui_layer:

		ui_layer = get_node("/root/SingleMode/UI") as CanvasLayer



	_status_label = ui_layer.get_node("StatusLabel") as Label

	_free_choice_hint = ui_layer.get_node("FreeChoiceHint") as Label

	_undo_button = ui_layer.get_node("UndoButton") as Button

	_undo_button.disabled = true



	# 获取难度和选边控件

	var diff_option = ui_layer.get_node_or_null("DifficultyOption")

	var side_option = ui_layer.get_node_or_null("SideOption")

	var settings_hint = ui_layer.get_node_or_null("SettingsHint")

	if diff_option:

		diff_option.item_selected.connect(_on_difficulty_changed.bind(settings_hint))

	if side_option:

		side_option.item_selected.connect(_on_side_changed.bind(settings_hint))



	_init_micro_board_refs()
	_emit_last_move()



	var reset_btn = ui_layer.get_node_or_null("ResetButton")

	if reset_btn:

		reset_btn.pressed.connect(_on_reset_pressed)



	var back_btn = ui_layer.get_node_or_null("BackToMenuButton")

	if back_btn:

		back_btn.pressed.connect(_on_back_to_menu_pressed)
	_undo_button.pressed.connect(_on_undo_pressed)
	# 连接上一手高亮更新信号
	last_move_changed.connect(_update_last_move_highlight)



	reset_game()





## 递归查找所有微观棋盘节点，并连接 cell_clicked 信号

func _init_micro_board_refs():

	_micro_board_nodes.clear()

	_find_micro_boards(_board_node)



func _find_micro_boards(node: Node):

	for child in node.get_children():

		if child.has_method("set_highlight") and child.get("macro_pos") != null:

			var mb_pos: Vector2i = child.macro_pos

			_micro_board_nodes[mb_pos] = child

			# 连接信号，确保不会重复连接（首次连接前先断开再连接，防止重复）

			if child.has_signal("cell_clicked"):

				if child.cell_clicked.is_connected(_on_cell_clicked):

					child.cell_clicked.disconnect(_on_cell_clicked)

				child.cell_clicked.connect(_on_cell_clicked)

		_find_micro_boards(child)





func _on_reset_pressed():

	reset_game()





## 重置游戏到初始状态

func reset_game():

	_apply_settings()

	# X 始终先手，无论玩家选哪边

	current_player = CellState.X

	next_macro = Vector2i(-1, -1)

	game_over = false

	move_history.clear()

	_ai_thinking = false



	# 创建 9 个微观棋盘

	macro_boards.clear()

	macro_states.clear()

	for i in range(9):

		macro_boards.append(MicroBoard.new())

		macro_states.append(BoardState.IN_PLAY)



	# 隐藏宏观获胜连线

	if _macro_win_line:

		_macro_win_line.hide()



	# 清除所有微观棋盘的视觉状态

	for mb in _micro_board_nodes.values():

		mb.reset_display()   # 需在 micro_board.gd 中实现该方法

	# 连接上一手高亮更新信号
	_emit_last_move()



	_full_ui_update()



	# 若当前轮到 AI，立即开始 AI 回合

	if not _ai_thinking and not game_over and not _is_player_side(current_player):

		_start_ai_turn()





## ----------------------------- 合法性检查 -----------------------------

func is_legal(macro_pos: Vector2i, cell_pos: Vector2i) -> bool:

	if game_over:

		return false



	var idx = macro_pos.y * 3 + macro_pos.x

	if idx < 0 or idx >= 9:

		return false

	if macro_states[idx] != BoardState.IN_PLAY:

		return false



	var board: MicroBoard = macro_boards[idx]

	if board.cells[cell_pos.y][cell_pos.x] != CellState.EMPTY:

		return false



	# 如果 next_macro 为 (-1,-1)，允许任意可用宏观棋盘

	if next_macro == Vector2i(-1, -1):

		return true

	else:

		return macro_pos == next_macro





## 获取当前玩家所有可落子的宏观棋盘坐标列表

func get_allowed_macros() -> Array[Vector2i]:

	var allowed: Array[Vector2i] = []

	if game_over:

		return allowed



	if next_macro == Vector2i(-1, -1):

		# 无限制：返回所有仍可下的宏观棋盘

		for y in range(3):

			for x in range(3):

				var idx = y * 3 + x

				if macro_states[idx] == BoardState.IN_PLAY:

					allowed.append(Vector2i(x, y))

	else:

		# 有限制：检查目标是否仍可下

		var idx = next_macro.y * 3 + next_macro.x

		if idx >= 0 and idx < 9 and macro_states[idx] == BoardState.IN_PLAY:

			allowed.append(next_macro)

		else:

			# 目标不可用，改为任意选择

			for y in range(3):

				for x in range(3):

					var idx2 = y * 3 + x

					if macro_states[idx2] == BoardState.IN_PLAY:

						allowed.append(Vector2i(x, y))

	return allowed





## ----------------------------- 核心落子逻辑 -----------------------------

func make_move(macro_pos: Vector2i, cell_pos: Vector2i) -> Dictionary:

	if not is_legal(macro_pos, cell_pos):

		return {"result": "illegal"}



	var idx = macro_pos.y * 3 + macro_pos.x

	var board: MicroBoard = macro_boards[idx]



	# 记录历史（悔棋用）

	var history_entry = {

		"macro": macro_pos,

		"cell": cell_pos,

		"player": current_player,

		"macro_state_before": macro_states[idx],

		"next_macro_before": next_macro

	}



	# 执行落子

	board.place(cell_pos.y, cell_pos.x, current_player)



	# 更新微观棋盘显示

	var mb_node = _micro_board_nodes.get(macro_pos)

	if mb_node:

		mb_node.set_cell(cell_pos.y, cell_pos.x, current_player)



	# 微观判定

	var winner = board.check_win()

	var board_locked = false

	if winner != CellState.EMPTY:

		if winner == CellState.X:

			macro_states[idx] = BoardState.WON_BY_X

		else:

			macro_states[idx] = BoardState.WON_BY_O

		board_locked = true

		if mb_node:

			mb_node.set_lock_appearance(macro_states[idx])

	elif board.is_full():

		macro_states[idx] = BoardState.LOCKED

		board_locked = true

		if mb_node:

			mb_node.set_lock_appearance(macro_states[idx])



	# 确定对手的下一手限制区域

	var target_macro = Vector2i(cell_pos.x, cell_pos.y)

	var target_idx = target_macro.y * 3 + target_macro.x

	if target_idx >= 0 and target_idx < 9 and macro_states[target_idx] == BoardState.IN_PLAY:

		next_macro = target_macro

	else:

		next_macro = Vector2i(-1, -1)



	history_entry["next_macro_after"] = next_macro

	move_history.append(history_entry)

	# 连接上一手高亮更新信号
	_emit_last_move()



	# 检查宏观胜利

	var macro_winner = check_macro_win()

	var result_type = "none"

	var final_winner = CellState.EMPTY



	if macro_winner != CellState.EMPTY:

		result_type = "win"

		final_winner = macro_winner

		game_over = true

		var win_cells = _get_macro_win_positions()

		_show_macro_win_line(win_cells, macro_winner)

		emit_signal("game_ended", {"result": "win", "winner": macro_winner})



	# 切换玩家（若游戏未结束）

	if not game_over:

		current_player = CellState.O if current_player == CellState.X else CellState.X



	emit_signal("move_made", macro_pos, cell_pos)



	# 刷新 UI

	_full_ui_update()



	# 检查平局：所有宏观格均不可用 或 当前玩家无合法落子点

	if not game_over:

		var draw = true

		for i in range(9):

			if macro_states[i] == BoardState.IN_PLAY:

				draw = false

				break



		if not draw:

			var all_allowed = get_allowed_macros()

			draw = all_allowed.is_empty()



		if draw:

			game_over = true

			result_type = "draw"

			emit_signal("game_ended", {"result": "draw"})

			_full_ui_update()



	return {"result": result_type, "winner": final_winner}





## ----------------------------- 宏观胜负判断 -----------------------------



## 发射上一手落子位置变化信号

## 从数据层同步所有微观棋盘格子的显示
## 在悔棋后调用，确保每个格子显示正确的 X/O/空白
func _sync_all_boards_visuals():
	for y in range(3):
		for x in range(3):
			var pos = Vector2i(x, y)
			var mb_node = _micro_board_nodes.get(pos)
			if not mb_node:
				continue
			var idx = y * 3 + x
			if idx < 0 or idx >= macro_boards.size():
				continue
			var board_data: MicroBoard = macro_boards[idx]
			mb_node.sync_from_data(board_data.cells)

func _emit_last_move():
	if move_history.is_empty():
		last_move_changed.emit(null, null)
	else:
		var last = move_history[-1]
		last_move_changed.emit(last["macro"], last["cell"])


## 发射上一手落子位置变化信号 last_move_changed 
func _update_last_move_highlight(macro_pos, cell_pos):
	# 清除所有格子的高亮
	for y in range(3):
		for x in range(3):
			var pos = Vector2i(x, y)
			var mb_node = _micro_board_nodes.get(pos)
			if not mb_node:
				continue
			for cy in range(3):
				for cx in range(3):
					var cell = mb_node.get_cell(cy, cx)
					if cell:
						cell.set_last_highlight(false)

	# 连接上一手高亮更新信号
	if macro_pos != null and cell_pos != null:
		var mb_node = _micro_board_nodes.get(macro_pos)
		if mb_node:
			var cell = mb_node.get_cell(cell_pos.y, cell_pos.x)
			if cell:
				cell.set_last_highlight(true)


## 悔棋：撤销最后一步操作

## 悔棋：撤销最后一步操作
func _on_undo_pressed():
	if move_history.is_empty() or game_over:
		return

	# 获取最后一步记录
	var last = move_history[-1]

	# 解析坐标
	var macro_pos: Vector2i = last["macro"]
	var cell_pos: Vector2i = last["cell"]
	var idx = macro_pos.y * 3 + macro_pos.x

	# 将微观棋盘数据中的棋子清空
	var board: MicroBoard = macro_boards[idx]
	board.cells[cell_pos.y][cell_pos.x] = CellState.EMPTY

	# 恢复宏观棋盘状态
	macro_states[idx] = last["macro_state_before"]
	next_macro = last["next_macro_before"]

	# 更新该微观棋盘的视觉锁定状态（如果已解除锁定）
	var mb_node = _micro_board_nodes.get(macro_pos)
	if mb_node:
		# 先移除 overlay（锁定/获胜遮罩），恢复为普通状态
		mb_node.reset_visuals()
		# 立刻从数据层同步恢复所有格子的显示
		mb_node.sync_from_data(board.cells)

	# 恢复玩家
	current_player = last["player"]

	# 从历史中移除
	move_history.pop_back()

	# 隐藏宏观胜利线（如果有）
	if _macro_win_line:
		_macro_win_line.hide()

	# 重置游戏结束标志
	game_over = false

	# 同步所有棋盘格子的显示（确保 UI 与数据层完全一致）
	_sync_all_boards_visuals()

	# 发射信号更新上一手高亮
	_emit_last_move()

	# 刷新全部 UI（状态标签、棋盘高亮、悔棋按钮等）
	_full_ui_update()
func check_macro_win() -> CellState:

	# 将宏观棋盘状态转为 3x3 的 CellState 矩阵，再复用静态方法判断

	var grid: Array[Array] = []

	for y in range(3):

		var row: Array[CellState] = []

		for x in range(3):

			var idx = y * 3 + x

			var s = macro_states[idx]

			if s == BoardState.WON_BY_X:

				row.append(CellState.X)

			elif s == BoardState.WON_BY_O:

				row.append(CellState.O)

			else:

				row.append(CellState.EMPTY)

		grid.append(row)



	return MicroBoard._check_win_for_state(grid)



## 返回宏观盘上三连获胜的三个格子坐标（宏观坐标），若无人获胜返回空数组

func _get_macro_win_positions() -> Array[Vector2i]:

	var grid: Array[Array] = []

	for y in range(3):

		var row: Array[CellState] = []

		for x in range(3):

			var idx = y * 3 + x

			var s = macro_states[idx]

			if s == BoardState.WON_BY_X:

				row.append(CellState.X)

			elif s == BoardState.WON_BY_O:

				row.append(CellState.O)

			else:

				row.append(CellState.EMPTY)

		grid.append(row)



	# 横

	for r in range(3):

		if grid[r][0] != CellState.EMPTY and grid[r][0] == grid[r][1] and grid[r][1] == grid[r][2]:

			return [Vector2i(0, r), Vector2i(1, r), Vector2i(2, r)]

	# 竖

	for c in range(3):

		if grid[0][c] != CellState.EMPTY and grid[0][c] == grid[1][c] and grid[1][c] == grid[2][c]:

			return [Vector2i(c, 0), Vector2i(c, 1), Vector2i(c, 2)]

	# 对角线

	if grid[0][0] != CellState.EMPTY and grid[0][0] == grid[1][1] and grid[1][1] == grid[2][2]:

		return [Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 2)]

	if grid[0][2] != CellState.EMPTY and grid[0][2] == grid[1][1] and grid[1][1] == grid[2][0]:

		return [Vector2i(0, 2), Vector2i(1, 1), Vector2i(2, 0)]

	return []





## 在宏观棋盘上绘制获胜连线

func _show_macro_win_line(win_cells, winner):

	if not _macro_win_line or win_cells.size() != 3:

		return



	# 根据获胜玩家设置颜色

	match winner:

		CellState.X:

			_macro_win_line.default_color = Color(0.0, 0.25, 1.0, 0.9)

		CellState.O:

			_macro_win_line.default_color = Color(1.0, 0.0, 0.0, 0.9)



	# 获取 MacroGrid 以计算每个宏观格的位置

	var macro_grid = _board_node.get_node("MacroGrid") as GridContainer

	if not macro_grid:

		return



	# 计算线条端点（宏观格中心坐标，相对 Board 节点）

	var points = PackedVector2Array()

	for cell in win_cells:

		var mb_node = _micro_board_nodes.get(cell)

		if not mb_node:

			return

		var center = mb_node.position + mb_node.size * 0.5

		points.append(center)



	_macro_win_line.points = points

	_macro_win_line.show()







## ----------------------------- UI 更新 -----------------------------

func _full_ui_update():

	# 状态标签

	if game_over:

		var macro_winner = check_macro_win()

		if macro_winner != CellState.EMPTY:

			if _is_player_side(macro_winner):

				_status_label.text = "玩家获胜！"

			else:

				_status_label.text = "AI 获胜！"

		else:

			_status_label.text = "平局！"

	else:

		if _is_player_side(current_player):

			_status_label.text = "轮到玩家落子"

		else:

			_status_label.text = "AI 正在思考..."



	# 自由选择提示

	var is_free = (next_macro == Vector2i(-1, -1))

	_free_choice_hint.visible = is_free

	# 获取最后一步记录
	_undo_button.disabled = move_history.is_empty()

	if is_free:

		if _is_player_side(current_player):

			_free_choice_hint.text = "AI 被送去的区域不可用，您可以任意选择落子区域"

		else:

			_free_choice_hint.text = "区域不可用，AI 将任意选择落子区域"



	# 更新棋盘高亮

	_update_board_highlights()







func _update_board_highlights():

	if _ai_thinking:

		_disable_all_cells()

		return



	var allowed_macros = get_allowed_macros()

	var allowed_set = {}

	for v in allowed_macros:

		allowed_set[Vector2i(v.x, v.y)] = true



	for y in range(3):

		for x in range(3):

			var pos = Vector2i(x, y)

			var node = _micro_board_nodes.get(pos)

			if not node:

				continue

			var idx = y * 3 + x

			if macro_states[idx] == BoardState.IN_PLAY:

				var active = allowed_set.has(pos)

				var allowed_cells: Array[Vector2i] = []

				if active:

					var board: MicroBoard = macro_boards[idx]

					for cy in range(3):

						for cx in range(3):

							if board.cells[cy][cx] == CellState.EMPTY:

								allowed_cells.append(Vector2i(cx, cy))

				node.set_highlight(active, allowed_cells)

			else:

				node.set_highlight(false, [] as Array[Vector2i])





## ----------------------------- 辅助方法 -----------------------------

func _disable_all_cells():

	for node in _micro_board_nodes.values():

		if node and node.has_method("set_highlight"):

			node.set_highlight(false, [] as Array[Vector2i])





## ----------------------------- 微观棋盘点击回调 -----------------------------

func _on_cell_clicked(macro_pos: Vector2i, cell_pos: Vector2i):

	if game_over:

		return

	if _ai_thinking or not _is_player_side(current_player):

		return



	if _ai_thinking or not _is_player_side(current_player):

		return



	# 再次验证是否属于合法宏观格子（防御性检查）

	var allowed = get_allowed_macros()

	var is_valid = false

	for v in allowed:

		if v == macro_pos:

			is_valid = true

			break

	if not is_valid:

		push_warning("非法落子：macro_pos ", macro_pos, " 不在允许列表中")

		return



	make_move(macro_pos, cell_pos)



	if not game_over and not _is_player_side(current_player):

		_start_ai_turn()





## ----------------------------- 返回菜单 -----------------------------

func _on_back_to_menu_pressed():

	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")





## 判断某方是否为玩家所控的子

func _is_player_side(side: int) -> bool:

	return side == _player_side





## ----------------------------- 设置变更 -----------------------------

func _on_difficulty_changed(index: int, hint_label: Label):

	if hint_label:

		hint_label.visible = true





func _on_side_changed(index: int, hint_label: Label):

	if hint_label:

		hint_label.visible = true





## 应用 UI 设置到游戏（在 reset_game 时调用）

func _apply_settings():

	var ui_layer = get_node("/root/" + get_tree().current_scene.name + "/UI") as CanvasLayer

	if not ui_layer:

		return



	var diff_option = ui_layer.get_node_or_null("DifficultyOption")

	if diff_option and ai_player_node:

		ai_player_node.difficulty = diff_option.selected



	var side_option = ui_layer.get_node_or_null("SideOption")

	if side_option:

		# selected == 0: 玩家执 X（AI 执 O），selected == 1: 玩家执 O（AI 执 X）

		_player_side = CellState.X if side_option.selected == 0 else CellState.O



	var settings_hint = ui_layer.get_node_or_null("SettingsHint")

	if settings_hint:

		settings_hint.visible = false



## ----------------------------- AI 回合 -----------------------------

func _start_ai_turn():

	if _ai_thinking:

		return

	if game_over:

		return



	_ai_thinking = true

	_ai_turn = true

	ai_started_thinking.emit()



	_disable_all_cells()

	_full_ui_update()



	call_deferred("_execute_ai_move")





func _execute_ai_move():

	if not _ai_thinking or game_over:

		return



	if ai_player_node == null or not ai_player_node.has_method("get_move"):

		push_error("AI 节点未正确配置！")

		_ai_thinking = false

		_ai_turn = false

		return



	var GameStateClass = preload("res://scripts/ai/game_state.gd")

	var state = GameStateClass.from_game_manager(self)



	var move = ai_player_node.get_move(state)



	_ai_thinking = false

	_ai_turn = false



	if move.is_empty():

		push_warning("AI 未返回有效走法")

		_full_ui_update()

		ai_finished_thinking.emit()

		return



	var macro_pos: Vector2i = move.get("macro", Vector2i(-1, -1))

	var cell_pos: Vector2i = move.get("cell", Vector2i(-1, -1))



	if macro_pos == Vector2i(-1, -1) or cell_pos == Vector2i(-1, -1):

		push_warning("AI 返回的走法坐标无效")

		_full_ui_update()

		ai_finished_thinking.emit()

		return



	make_move(macro_pos, cell_pos)

	ai_finished_thinking.emit()
