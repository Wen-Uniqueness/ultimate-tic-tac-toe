## ============================================================================
## eval_params.gd — 评估参数参考值对象
## 挂载为场景中的独立节点，导出所有参数，方便在 Godot 编辑器内调参。
## ============================================================================
extends Node
class_name EvalParams

## 评估参数 - 导出到编辑器，可实时调节
@export var micro_threat_two: float = 10.0        # 微观二连威胁（每个）
@export var micro_piece: float = 1.0              # 微观棋子（每个）
@export var micro_block_opponent: float = 5.0     # 阻挡对手微观二连（每个可阻挡格）
@export var macro_threat_two: float = 20.0         # 宏观二连机会（每个）
@export var macro_block_opponent: float = 15.0     # 阻挡对手宏观二连（每个）
@export var macro_owned_cell: float = 5.0          # 占领大格（每个）
@export var micro_weight: float = 0.7              # 微观权重
@export var macro_weight: float = 0.3              # 宏观权重
@export var macro_weight_endgame: float = 0.9      # 终局宏观权重
