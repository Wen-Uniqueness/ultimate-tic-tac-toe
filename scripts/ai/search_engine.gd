## ============================================================================
## search_engine.gd — AI 核心搜索算法
## 带 Alpha-Beta 剪枝的 Minimax + 迭代加深 + 启发式排序
## ============================================================================
extends RefCounted
class_name SearchEngine

const INF: float = 999999.0

var evaluator: AIEvaluation
var _start_time: int = 0
var _time_limit_ms: int = 0
var _timeout: bool = false


func _init(eval: AIEvaluation):
	evaluator = eval


## 获取最佳走法（外部接口）
func get_best_move(state, depth: int, time_limit_ms: int, random_chance: float = 0.0) -> Dictionary:
	_start_time = Time.get_ticks_msec()
	_time_limit_ms = time_limit_ms
	_timeout = false

	# 检查有无一步致胜
	var win_move = state.has_instant_win_move()
	if not win_move.is_empty():
		return win_move

	var max_depth = depth
	var best_move: Dictionary = {}
	var best_score: float = -INF

	# 迭代加深（从 2 开始，步长 2）
	for d in range(2, max_depth + 1, 2):
		if _timeout:
			break

		var moves = state.get_legal_moves()
		if moves.is_empty():
			return {}

		# 启发式排序
		_sort_moves_by_heuristic(moves, state)

		var result = _search_with_depth(state, d, moves)
		if _timeout and not best_move.is_empty():
			break

		if not result.is_empty():
			best_move = result
			best_score = _evaluate_move(state, result)

	# 随机扰动
	if random_chance > 0.0 and randf() < random_chance:
		var all_moves = state.get_legal_moves()
		if not all_moves.is_empty():
			best_move = all_moves[randi() % all_moves.size()]

	return best_move


## 搜索到指定深度，返回最佳走法
func _search_with_depth(state, depth: int, moves_sorted: Array) -> Dictionary:
	var alpha = -INF
	var beta = INF
	var best_move: Dictionary = {}
	var best_val = -INF

	var is_maximizing = true  # 当前玩家最大化

	for m in moves_sorted:
		if _timeout:
			break
		var new_state = state.apply_move(m)
		if new_state.is_terminal():
			var w = new_state.check_winner()
			if w == state.current_player:
				return m  # 直接获胜走法
			elif w != state.CellState.EMPTY:
				continue  # 对手获胜走法，跳过

		var val = _mini_max(new_state, depth - 1, alpha, beta, not is_maximizing)
		if val > best_val:
			best_val = val
			best_move = m
		alpha = max(alpha, val)

	return best_move


## Alpha-Beta 核心
func _mini_max(state, depth: int, alpha: float, beta: float, is_maximizing: bool) -> float:
	if _timeout:
		return 0.0

	# 检查超时
	if Time.get_ticks_msec() - _start_time >= _time_limit_ms:
		_timeout = true
		return 0.0

	if depth == 0 or state.is_terminal():
		var e = evaluator.evaluate(state)
		# 对终局做极大极小惩罚/奖励
		if state.is_terminal():
			var w = state.check_winner()
			if w != state.CellState.EMPTY:
				# 胜者是谁？若当前节点轮到对手
				var perspective = state.current_player
				if w == perspective:
					return INF - (10 - depth)  # 越早胜越好
				else:
					return -INF + (10 - depth)
			else:
				return 0.0  # 平局
		return e

	var moves = state.get_legal_moves()
	if moves.is_empty():
		return 0.0

	_sort_moves_by_heuristic(moves, state)

	if is_maximizing:
		var value = -INF
		for m in moves:
			if _timeout:
				break
			var new_state = state.apply_move(m)
			value = max(value, _mini_max(new_state, depth - 1, alpha, beta, false))
			alpha = max(alpha, value)
			if beta <= alpha:
				break
		return value
	else:
		var value = INF
		for m in moves:
			if _timeout:
				break
			var new_state = state.apply_move(m)
			value = min(value, _mini_max(new_state, depth - 1, alpha, beta, true))
			beta = min(beta, value)
			if beta <= alpha:
				break
		return value


## 启发式排序：按走法评分从高到低
func _sort_moves_by_heuristic(moves: Array, state) -> void:
	var scored: Array[Dictionary] = []
	for m in moves:
		var ns = state.apply_move(m)
		var s = evaluator.evaluate(ns)
		scored.append({"move": m, "score": s})

	scored.sort_custom(func(a, b): return a.score > b.score)

	moves.clear()
	for item in scored:
		moves.append(item.move)


## 简单评估某个走法
func _evaluate_move(state, move: Dictionary) -> float:
	var ns = state.apply_move(move)
	return evaluator.evaluate(ns)
