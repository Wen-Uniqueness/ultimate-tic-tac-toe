## ============================================================================
## game_state.gd — AI 不可变状态快照
## 供搜索使用，不污染主游戏数据。
## ============================================================================
extends RefCounted
class_name GameState

## 枚举（与 GameManager 保持一致）
enum CellState { EMPTY, X, O }
enum BoardState { IN_PLAY, WON_BY_X, WON_BY_O, LOCKED }

var macro_states: Array[int]          # 长度 9, BoardState 整数值
var micro_cells: Array[Array]         # 9 个微棋盘, 每个为 3x3 CellState 整数值
var current_player: int               # CellState.X 或 CellState.O
var next_macro: Vector2i              # (-1,-1) 表示无限制
var cached_legal_moves: Array         # 缓存合法走法, 每次 apply_move 后重置


func _init():
	macro_states = []
	micro_cells = []
	for i in range(9):
		macro_states.append(BoardState.IN_PLAY)
		var board: Array[Array] = []
		for r in range(3):
			var row: Array = []
			for c in range(3):
				row.append(CellState.EMPTY)
			board.append(row)
		micro_cells.append(board)
	current_player = CellState.X
	next_macro = Vector2i(-1, -1)


## 从 GameManager 创建快照（主游戏 -> AI 状态）
static func from_game_manager(gm) -> GameState:
	var state = GameState.new()
	state.current_player = gm.current_player
	state.next_macro = gm.next_macro
	for i in range(9):
		state.macro_states[i] = gm.macro_states[i]
		var src_board = gm.macro_boards[i]
		for r in range(3):
			for c in range(3):
				state.micro_cells[i][r][c] = src_board.cells[r][c]
	return state


## 获取所有合法走法
func get_legal_moves() -> Array[Dictionary]:
	if cached_legal_moves != null and not cached_legal_moves.is_empty():
		return cached_legal_moves.duplicate()

	var moves: Array[Dictionary] = []
	var target_macros: Array[int] = []

	if next_macro == Vector2i(-1, -1):
		for idx in range(9):
			if macro_states[idx] == BoardState.IN_PLAY:
				target_macros.append(idx)
	else:
		var idx = next_macro.y * 3 + next_macro.x
		if idx >= 0 and idx < 9 and macro_states[idx] == BoardState.IN_PLAY:
			target_macros.append(idx)
		else:
			for i in range(9):
				if macro_states[i] == BoardState.IN_PLAY:
					target_macros.append(i)

	for idx in target_macros:
		var board = micro_cells[idx]
		var macro_x = idx % 3
		var macro_y = idx / 3
		for r in range(3):
			for c in range(3):
				if board[r][c] == CellState.EMPTY:
					moves.append({
						"macro": Vector2i(macro_x, macro_y),
						"cell": Vector2i(c, r)
					})

	cached_legal_moves = moves.duplicate()
	return moves


## 应用走法，返回新状态（不可变）
func apply_move(move: Dictionary) -> GameState:
	var new_state = GameState.new()
	# 深拷贝数据
	for i in range(9):
		new_state.macro_states[i] = macro_states[i]
		for r in range(3):
			for c in range(3):
				new_state.micro_cells[i][r][c] = micro_cells[i][r][c]

	new_state.current_player = current_player
	new_state.next_macro = next_macro

	var macro_pos: Vector2i = move["macro"]
	var cell_pos: Vector2i = move["cell"]
	var idx = macro_pos.y * 3 + macro_pos.x

	# 落子
	new_state.micro_cells[idx][cell_pos.y][cell_pos.x] = current_player

	# 检查微观棋盘胜负
	var winner = _check_micro_win(new_state.micro_cells[idx])
	if winner != CellState.EMPTY:
		if winner == CellState.X:
			new_state.macro_states[idx] = BoardState.WON_BY_X
		else:
			new_state.macro_states[idx] = BoardState.WON_BY_O
	elif _is_board_full(new_state.micro_cells[idx]):
		new_state.macro_states[idx] = BoardState.LOCKED

	# 检查宏观胜负
	new_state.current_player = CellState.O if current_player == CellState.X else CellState.X

	# 确定 next_macro
	var target_macro = cell_pos
	var target_idx = target_macro.y * 3 + target_macro.x
	if target_idx >= 0 and target_idx < 9 and new_state.macro_states[target_idx] == BoardState.IN_PLAY:
		new_state.next_macro = target_macro
	else:
		new_state.next_macro = Vector2i(-1, -1)

	return new_state


## 宏观胜负检查
func check_winner() -> int:
	var grid: Array[Array] = []
	for y in range(3):
		var row: Array = []
		for x in range(3):
			var sidx = y * 3 + x
			var s = macro_states[sidx]
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


## 是否终局
func is_terminal() -> bool:
	if check_winner() != CellState.EMPTY:
		return true
	# 检查是否还有 IN_PLAY 的宏观格
	for s in macro_states:
		if s == BoardState.IN_PLAY:
			return false
	return true


## 当前玩家是否有直接获胜的走法（提前终止优化用）
func has_instant_win_move() -> Dictionary:
	var moves = get_legal_moves()
	for m in moves:
		var ns = apply_move(m)
		if ns.check_winner() == current_player:
			return m
	return {}


## 微棋盘三连检查
static func _check_micro_win(grid: Array) -> int:
	for r in range(3):
		if grid[r][0] != CellState.EMPTY and grid[r][0] == grid[r][1] and grid[r][1] == grid[r][2]:
			return grid[r][0]
	for c in range(3):
		if grid[0][c] != CellState.EMPTY and grid[0][c] == grid[1][c] and grid[1][c] == grid[2][c]:
			return grid[0][c]
	if grid[0][0] != CellState.EMPTY and grid[0][0] == grid[1][1] and grid[1][1] == grid[2][2]:
		return grid[0][0]
	if grid[0][2] != CellState.EMPTY and grid[0][2] == grid[1][1] and grid[1][1] == grid[2][0]:
		return grid[0][2]
	return CellState.EMPTY


## 棋盘是否满
static func _is_board_full(grid: Array) -> bool:
	for r in range(3):
		for c in range(3):
			if grid[r][c] == CellState.EMPTY:
				return false
	return true
