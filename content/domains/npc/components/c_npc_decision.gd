extends Component
## Временное состояние владельца намерения; не хранит физические transform и ссылки на цели.
class_name C_NpcDecision

enum Owner {
	EMERGENCY,
	COMBAT,
	SERVICE,
	SCHEDULE,
	IDLE,
	NONE,
}

enum ActionStatus {
	NONE,
	ACCEPTED,
	RUNNING,
	COMPLETED,
	FAILED,
	CANCELLED,
}

## Transient execution identity; schedule record remains the sole obligation authority.
var action_generation: int = 0
## Status committed by explicit operations, never an independent BT success flag.
var action_status: ActionStatus = ActionStatus.NONE
## Captured authored obligation key; retained through move/finish leaf transitions.
var action_goal_id: StringName = &""
## Captured obligation calendar identity.
var action_day: int = 0
## Captured obligation calendar phase.
var action_phase: int = -1
## Current or terminal execution reason for diagnostics.
var action_reason: StringName = &""
## Local idle destination; cannot overwrite the district's required schedule goal.
var local_activity_id: StringName = &""
## Last explicit participation transition; mode itself is derived from roster placement/death.
var participation_reason: StringName = &""
## Explicit transition incarnation; unrelated AI wakes cannot supersede a native mode commit.
var participation_generation: int = 0
## Prevents nested native World transitions while enable/disable signal callbacks are running.
var participation_committing: bool = false

## Ветка решения, имеющая право задавать движение и действия.
var intent_owner: Owner = Owner.NONE
## Токен листа, задавшего движение; прерывание старого действия не отменяет движение его замены.
var active_task_id: int = 0
## Защищает остановку участия от вложенного abort во время исполнения текущего такта BT.
var tree_updating: bool = false
## Название текущего поведения для отладки.
var active_behavior: String = ""
## Время ожидания недостижимой цели.
var blocked_elapsed: float = 0.0

## Transient interval captured by cadence, shared through sensing/traits/BT and cleared by route progression.
var scheduled_delta: float = 0.0
## Calendar day captured by the cadence owner; queued stages reject superseded steps.
var scheduled_day: int = 0
## Calendar phase captured by the cadence owner; not persistent NPC history.
var scheduled_phase: int = -1

## Transient reset generation; buffered AI stages reject work from an older brain lifecycle.
var lifecycle_generation: int = 0
## One coalesced meaningful wake, consumed only by the existing cadence owner.
var wake_requested: bool = false
## Most recent diagnostic cause; duplicate wakes do not enqueue repeated work.
var wake_reason: StringName = &""
## Urgent wake invalidates the previous queued step once before fair resampling.
var wake_urgent: bool = false
## First GameClock tick at which this actor became due, or -1 outside the due set.
var due_since_tick: int = -1
## Current selection/deferral reason for the shared AI diagnostics provider.
var selection_reason: StringName = &""
## Authored schedule origin for diagnostics; the roster still owns the obligation.
var obligation_source: String = ""


#region Transient state reset
## Clears derived state in place; retains the constructed Component and durable NPC authority.
func reset_transient_state() -> void:
	lifecycle_generation += 1
	action_generation += 1
	action_status = ActionStatus.NONE
	action_goal_id = &""
	action_day = 0
	action_phase = -1
	action_reason = &""
	local_activity_id = &""
	participation_reason = &""
	participation_generation += 1
	participation_committing = false

	intent_owner = Owner.NONE
	active_task_id = 0
	tree_updating = false
	active_behavior = ""
	blocked_elapsed = 0.0
	scheduled_delta = 0.0
	scheduled_day = 0
	scheduled_phase = -1
	wake_requested = false
	wake_reason = &""
	wake_urgent = false
	due_since_tick = -1
	selection_reason = &""
	obligation_source = ""
#endregion
