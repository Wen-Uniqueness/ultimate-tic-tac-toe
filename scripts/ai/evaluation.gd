## ============================================================================
## evaluation.gd — AI 评估函数
## 评估值表示当前玩家（current_player）的优势，正数有利，负数不利。
## 评估参数设计为可导出变量，方便在 Godot 场景中调参。
## ============================================================================
extends RefCounted
class_name AIEvaluation

# ---- 评估参数（可在场景中调整，见 EvalParams 单例） ----
# 以下为默认值
var micro_threat_two: float = 10.0        # 微观二连威胁（每个）
var micro_piece: float = 1.0              # 微观棋子（每个）
var micro_block_opponent: float = 5.0     # 微观阻挡对手二连（每个可阻挡格）
var macro_threat_two: float = 20.0        # 宏观二连机会（每个）
var macro_block_opponent: float = 15.0    # 宏观阻挡对手二连（每个）
var macro_owned_cell: float = 5.0         # 占领大格（每个）
var micro_weight: float = 0.7             # 微观贡献权重（常规）
var macro_weight: float = 0.3             # 宏观贡献权重（常规）
var macro_weight_endgame: float = 0.9     # 临近终局时宏观权重


func _init():
	pass


## 加载参数（从 EvalParams 对象读取）
func load_params(params_node) -> void:
	if params_node == null:
		return
	if "micro_threat_two" in params_node:
		micro_threat_two = params_node.micro_threat_two
	if "micro_piece" in params_node:
		micro_piece = params_node.micro_piece
	if "micro_block_opponent" in params_node:
		micro_block_opponent = params_node.micro_block_opponent
	if "macro_threat_two" in params_node:
		macro_threat_two = params_node.macro_threat_two
	if "macro_block_opponent" in params_node:
		macro_block_opponent = params_node.macro_block_opponent
	if "macro_owned_cell" in params_node:
		macro_owned_cell = params_node.macro_owned_cell
	if "micro_weight" in params_node:
		micro_weight = params_node.micro_weight
	if "macro_weight" in params_node:
		macro_weight = params_node.macro_weight
	if "macro_weight_endgame" in params_node:
		macro_weight_endgame = params_node.macro_weight_endgame


## 评估局面对 current_player 的优势
func evaluate(state) -> float:
	var p = state.current_player
	var opponent = state.CellState.X if p == state.CellState.O else state.CellState.O

	var micro_score = _evaluate_micro(state, p, opponent)
	var macro_score = _evaluate_macro(state, p, opponent)

	var use_macro_weight = macro_weight
	# 动态调整：若任意一方已达宏观二连，增大宏观权重
	if _has_macro_two_in_row(state, p) or _has_macro_two_in_row(state, opponent):
		use_macro_weight = macro_weight_endgame

	return micro_score * micro_weight + macro_score * use_macro_weight


## 微观贡献评估
func _evaluate_micro(state, p, opponent) -> float:
	var score = 0.0
	for i in range(9):
		if state.macro_states[i] != state.BoardState.IN_PLAY:
			continue
		var grid = state.micro_cells[i]
		score += _score_micro_board(grid, p, opponent)
	return score


## 单个微观棋盘评分
func _score_micro_board(grid: Array, p, opponent) -> float:
	var threats = 0        # 己方二连数
	var pieces = 0         # 己方棋子数
	var blocks = 0         # 可阻挡对手二连的空格数

	# 检查行
	for r in range(3):
		var p_count = 0
		var o_count = 0
		var empty_col = -1
		for c in range(3):
			if grid[r][c] == p:
				p_count += 1
			elif grid[r][c] == opponent:
				o_count += 1
			else:
				empty_col = c
		if p_count == 2 and o_count == 0 and empty_col >= 0:
			threats += 1
		if o_count == 2 and p_count == 0 and empty_col >= 0:
			blocks += 1

	# 检查列
	for c in range(3):
		var p_count = 0
		var o_count = 0
		var empty_row = -1
		for r in range(3):
			if grid[r][c] == p:
				p_count += 1
			elif grid[r][c] == opponent:
				o_count += 1
			else:
				empty_row = r
		if p_count == 2 and o_count == 0 and empty_row >= 0:
			threats += 1
		if o_count == 2 and p_count == 0 and empty_row >= 0:
			blocks += 1

	# 检查主对角线
	var p_count = 0
	var o_count = 0
	var empty_d1 = -1
	for d in range(3):
		if grid[d][d] == p:
			p_count += 1
		elif grid[d][d] == opponent:
			o_count += 1
		else:
			empty_d1 = d
	if p_count == 2 and o_count == 0 and empty_d1 >= 0:
		threats += 1
	if o_count == 2 and p_count == 0 and empty_d1 >= 0:
		blocks += 1

	# 检查副对角线
	p_count = 0
	o_count = 0
	var empty_d2 = -1
	for d in range(3):
		if grid[d][2-d] == p:
			p_count += 1
		elif grid[d][2-d] == opponent:
			o_count += 1
		else:
			empty_d2 = d
	if p_count == 2 and o_count == 0 and empty_d2 >= 0:
		threats += 1
	if o_count == 2 and p_count == 0 and empty_d2 >= 0:
		blocks += 1

	# 棋子数
	for r in range(3):
		for c in range(3):
			if grid[r][c] == p:
				pieces += 1

	return threats * micro_threat_two + pieces * micro_piece + blocks * micro_block_opponent


## 宏观贡献评估
func _evaluate_macro(state, p, opponent) -> float:
	var grid: Array[Array] = []
	for y in range(3):
		var row: Array = []
		for x in range(3):
			var idx = y * 3 + x
			var s = state.macro_states[idx]
			if s == state.BoardState.WON_BY_X:
				row.append(state.CellState.X)
			elif s == state.BoardState.WON_BY_O:
				row.append(state.CellState.O)
			else:
				row.append(state.CellState.EMPTY)
		grid.append(row)

	var threats = 0   # 己方宏观二连机会
	var blocks = 0    # 阻挡对手宏观二连
	var owned = 0     # 己方占领大格数

	# 行 + 列 + 对角线
	var lines = [
		[Vector2i(0,0), Vector2i(1,0), Vector2i(2,0)],
		[Vector2i(0,1), Vector2i(1,1), Vector2i(2,1)],
		[Vector2i(0,2), Vector2i(1,2), Vector2i(2,2)],
		[Vector2i(0,0), Vector2i(0,1), Vector2i(0,2)],
		[Vector2i(1,0), Vector2i(1,1), Vector2i(1,2)],
		[Vector2i(2,0), Vector2i(2,1), Vector2i(2,2)],
		[Vector2i(0,0), Vector2i(1,1), Vector2i(2,2)],
		[Vector2i(2,0), Vector2i(1,1), Vector2i(0,2)]
	]

	for line in lines:
		var p_count = 0
		var o_count = 0
		for pos in line:
			var val = grid[pos.y][pos.x]
			if val == p:
				p_count += 1
			elif val == opponent:
				o_count += 1
		if p_count == 2 and o_count == 0:
			threats += 1
		if o_count == 2 and p_count == 0:
			blocks += 1

	for y in range(3):
		for x in range(3):
			var idx = y * 3 + x
			if state.macro_states[idx] == state.BoardState.WON_BY_X and p == state.CellState.X:
				owned += 1
			elif state.macro_states[idx] == state.BoardState.WON_BY_O and p == state.CellState.O:
				owned += 1

	return threats * macro_threat_two + blocks * macro_block_opponent + owned * macro_owned_cell


## 检查某玩家在宏观棋盘是否已形成二连
func _has_macro_two_in_row(state, player) -> bool:
	var grid: Array[Array] = []
	for y in range(3):
		var row: Array = []
		for x in range(3):
			var idx = y * 3 + x
			var s = state.macro_states[idx]
			if s == state.BoardState.WON_BY_X:
				row.append(state.CellState.X)
			elif s == state.BoardState.WON_BY_O:
				row.append(state.CellState.O)
			else:
				row.append(state.CellState.EMPTY)
		grid.append(row)

	var lines = [
		[Vector2i(0,0), Vector2i(1,0), Vector2i(2,0)],
		[Vector2i(0,1), Vector2i(1,1), Vector2i(2,1)],
		[Vector2i(0,2), Vector2i(1,2), Vector2i(2,2)],
		[Vector2i(0,0), Vector2i(0,1), Vector2i(0,2)],
		[Vector2i(1,0), Vector2i(1,1), Vector2i(1,2)],
		[Vector2i(2,0), Vector2i(2,1), Vector2i(2,2)],
		[Vector2i(0,0), Vector2i(1,1), Vector2i(2,2)],
		[Vector2i(2,0), Vector2i(1,1), Vector2i(0,2)]
	]

	for line in lines:
		var count = 0
		var occupied = 0
		for pos in line:
			if grid[pos.y][pos.x] == player:
				count += 1
			elif grid[pos.y][pos.x] != state.CellState.EMPTY:
				occupied += 1
		if count >= 2 and occupied == count:
			return true
	return false
