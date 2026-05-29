class_name TradeStallConfig
extends Resource

## Per-stage Ghost Market Trade configuration (ADR-0004 + ghost-market-trade.md).
##
## A StageConfig with a non-null trade_stall_config spawns ghost merchant stalls
## and applies the demon-tide penalty on each completed trade. Stage 1's
## StageConfig leaves this null (no stalls). Defaults mirror the GDD tuning knobs.
##
## NOTE: the trade OFFER definitions (血契 Blood Pact / 魂典 Soul Codex / 阴债 Yin
## Debt) and their cost/buff logic live in the Ghost Market Trade system (Player +
## TradeStall + TradePanel), not here — this resource only configures the
## per-stage spawn cadence + the demon-tide penalty intensity.

## Number of stalls spawned per run of this stage.
@export var stall_count_per_run: int = 4

## Absolute elapsed-times (seconds) at which stalls spawn (index 0..count-1).
@export var stall_spawn_times: Array[float] = [30.0, 90.0, 150.0, 210.0]

## Seconds an AVAILABLE stall lingers before EXPIRING if not used.
@export var stall_linger_seconds: float = 25.0

## ── Demon-tide penalty (ghost-market-trade Formula 4) ──
## Normal-enemy burst spawned on each completed trade.
@export var demon_tide_base_count: int = 6

## Spawn-interval multiplier applied for demon_tide_window_seconds after a trade.
@export var demon_tide_interval_mult: float = 0.75

## Duration (seconds) the interval multiplier stays active after a trade.
@export var demon_tide_window_seconds: float = 12.0

## Elite added to the tide, indexed by cumulative trade count (0-based).
## e.g. [0, 1, 2, 2] = trade 1 adds 0 elites, trade 2 adds 1, trades 3-4 add 2.
@export var demon_tide_elite_counts: Array[int] = [0, 1, 2, 2]

## The elite archetype the demon tide spawns (e.g. Shanxiao or 黑白无常).
@export var demon_tide_elite_archetype: EnemyArchetype
