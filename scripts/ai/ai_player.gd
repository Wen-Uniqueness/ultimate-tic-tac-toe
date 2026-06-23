## ============================================================================
## ai_player.gd — AI 控制器
## 接收当前游戏状态，返回落子坐标。
## 设计为可与 GameManager 解耦，通过标准接口交互。
## ============================================================================
extends Node
class_name AIPlayer

## 难度枚举
enum Difficulty { EASY, MEDIUM, HARD }

## 当前难度
@export var difficulty: Difficulty = Difficulty.MEDIUM

## 评估参数引用（可选，如果不设置则使用默认值）
@export var eval_params_node: Node = null

var _evaluator: AIEvaluation
var _engine: SearchEngine
var _is_thinking: bool = false


func _ready():
	_evaluator = AIEvaluation.new()
	if eval_params_node != null:
		_evaluator.load_params(eval_params_node)
	_engine = SearchEngine.new(_evaluator)


## 重新加载参数（可在运行时调用）
func reload_params() -> void:
	if _evaluator != null and eval_params_node != null:
		_evaluator.load_params(eval_params_node)


## 核心接口：获取 AI 走法
## 返回 {macro: Vector2i, cell: Vector2i}，若无合法走法返回空字典
func get_move(state) -> Dictionary:
	if _is_thinking:
		push_warning("AI 正在思考中，重复调用被忽略")
		return {}

	_is_thinking = true
	var result = _compute_move(state)
	_is_thinking = false
	return result


func _compute_move(state) -> Dictionary:
	var depth: int
	var time_limit: int
	var random_chance: float

	match difficulty:
		Difficulty.EASY:
			depth = 2
			time_limit = 800
			random_chance = 0.2
		Difficulty.MEDIUM:
			depth = 4
			time_limit = 1000
			random_chance = 0.05
		Difficulty.HARD:
			depth = 6
			time_limit = 1500
			random_chance = 0.0

	return _engine.get_best_move(state, depth, time_limit, random_chance)
