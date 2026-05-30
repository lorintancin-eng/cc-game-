class_name DemonTideSpec
extends RefCounted

## The punishment wave a completed Ghost Market trade summons —
## the computed result of TradeFormulas.demon_tide() (ghost-market-trade.md
## Formula 4). Pure data, no behavior.
##
## Consumed by StageDirector (live wiring, a later playtest-gated step) to drive
## EnemySpawner bursts: spawn `normal_count` Stage-2 normals + `elite_count`
## Impermanence elites, override the spawn interval by `interval_mult` for
## `window_seconds`.

var normal_count: int = 0
var elite_count: int = 0
var interval_mult: float = 1.0
var window_seconds: float = 0.0
