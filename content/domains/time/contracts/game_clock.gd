extends Resource
## Durable elapsed gameplay clock aggregated by C_DayCycle; S_GameTime is its sole tick writer.
class_name GameClock

## Exact required serialized field set for the closed clock record.
const SAVE_FIELDS: Array[String] = ["elapsed_ticks", "tick_remainder", "world_seed"]

#region Persistent clock state
## Nonnegative monotonic simulation timestamp in GameTimeRules microsecond ticks.
@export var elapsed_ticks: int = 0
## Fractional tick carried between steps, in the half-open range [0, 1).
@export var tick_remainder: float = 0.0
## Authored session seed; every durable decision includes this value in its canonical key.
@export var world_seed: int = 0
#endregion

#region Transient step state
## Explicit gameplay pause; calendar requests and native physics retain separate ownership.
var paused: bool = false
## Integer elapsed ticks committed by the latest clock step; never persisted as history.
var step_ticks: int = 0
#endregion
