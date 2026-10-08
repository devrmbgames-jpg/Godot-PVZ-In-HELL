# Game time and deterministic decisions

The Time domain owns elapsed gameplay time independently of player-driven calendar labels.
`C_DayCycle` remains the day/phase authority and owns a typed `GameClock` aggregate.
The aggregate is durable data, not a parallel runtime model: `S_GameTime` alone writes its
`elapsed_ticks` and `tick_remainder`. Persistence reconstructs validated records while runtime
owners are suspended; ordinary consumers only read them. Pinned GECS copies top-level Component
properties while sharing nested Resources. The C_DayCycle clock setter therefore copies the clock
value on assignment, preserving exported durable fields and resetting transient step/pause data.
Different live entities never share a prefab clock aggregate.

## Elapsed clock

Schema 9 fixes one tick at one microsecond (`GameTimeRules.TICKS_PER_SECOND = 1_000_000`).
Each valid callback adds `delta * TICKS_PER_SECOND` to the carried fractional tick remainder,
commits the integer floor and retains the fractional part in `[0, 1)`. Timestamps are
nonnegative signed-64-bit integers. Step conversion is restricted to the exactly representable
floating-point integer range; addition must not overflow the timestamp. Authored positive
durations round upward to ticks. Invalid/nonfinite/negative callback deltas do not advance time.

The main-level composition executes the `Clock` group once before Input, Interaction, Physics
and GamePlay. Input/Interaction/GamePlay receive the committed tick interval converted to seconds
for their existing native adapters. Input remains sampled once per callback; gameplay effects such as stamina consume elapsed game time.
Godot/Jolt callbacks and physical contact/stance windows keep their native frame/delta contracts. `Engine.get_physics_frames()` remains appropriate for contact capture,
same-frame structural guards, avoidance freshness and per-frame planning budgets; it is not a
calendar or macro AI timestamp.

SceneTree pause prevents the main simulation callback. The explicit clock `paused` flag also
freezes elapsed ticks/remainder and produces a zero gameplay step. NIGHT preparation freezes
elapsed time. Sleep changes day/phase through `S_DayPhase` and existing committed calendar
facts; it never invents eight hours, an automatic day length or elapsed offline duration.
The separate Storage group runs after GamePlay with raw callback seconds for bounded Night I/O retries.
Those transient operational timers never become elapsed gameplay/calendar authority.
UI/real time has no authority over domain deadlines or random decisions.

Shift duration is a read calculation from start/end timestamps. NPC cadence stores the last
sample timestamp and retained active interval in the existing `NpcRecord` aggregate; its sole
writer is `S_NpcCadence`. Dormant/dead/night participants do not accumulate active intervals.
The sampled due interval in `C_NpcDecision` is transient; it supplies the same quantized seconds
to sensing, traits, native BT, role clocks and route progression. Calendar schedules and
once-per-day outcomes continue to use persisted day/phase labels and idempotent receipts.

## Decision seed v1

`DecisionRandomRules.ALGORITHM` is `pvzh-decision-seed-v1`. The key contains, in this exact order:

1. Algorithm/version tag.
2. Saved signed-64-bit world seed in canonical decimal ASCII.
3. Nonempty stable actor/action identity in UTF-8.
4. Positive calendar day in decimal ASCII.
5. Nonempty decision/action kind in UTF-8.
6. Nonnegative persisted repeated-decision sequence in decimal ASCII.

Each field is framed as its UTF-8 byte length in decimal ASCII, one ASCII colon (`0x3a`),
then exactly those payload bytes. There are no implicit separators, locale conversions,
engine/process hashes or dictionary traversal. SHA-256 hashes the concatenated bytes.
The first eight digest bytes are interpreted big-endian, with the high bit cleared to give
an integer in `[0, 2^63 - 1]`. That seed initializes the existing Godot 4.7.1
`RandomNumberGenerator`. This contract pins the current runtime RNG; it does not promise
cross-version RNG compatibility or deterministic Jolt lockstep.

Every preview constructs a generator for its explicit key and changes no durable sequence.
Committers own sequences: NPC activity uses `activity_sequence`; inspection uses the committed
appearance count; followups increment their persisted count only when scheduled. Daily offers,
package variants, replacements and social incidents have stable day/action identities and
existing committed record/receipt guards. Repeating a rejected query cannot consume a decision.
Random candidate paths/IDs are sorted before sampling. Authored schedules/rotation and the persisted Customer visit queue retain their
explicit authored ordering; dictionary iteration never supplies a random candidate order.

`tests/fixtures/refactoring_v2/decision_rng_golden.json` contains independent Python UTF-8/SHA-256
key/seed oracles, plus native Godot integer and fraction outputs. Fraction outputs are exact
little-endian IEEE-754 binary64 byte strings for the pinned Windows x64 runtime, avoiding JSON
floating-point rounding. The fixture includes Unicode and both signed world-seed extremes.
An engine/RNG/algorithm upgrade must deliberately revise this contract and its golden tests.
Opaque cryptographic package-ID creation remains an identity operation; terminal UI hashes remain
derived display fingerprints. Neither is a durable gameplay random-decision seed.

## Persistence

Schema 9 saves the clock/remainder/world seed with calendar state and NPC cadence/decision
sequences. The closed codec requires the full clock field set and validates ranges before
live state changes. The Night snapshot normalizes next-morning calendar and shift markers
while retaining elapsed ticks; no night duration is added. The native Variant fixture uses
nondefault clock/remainder/seed/cadence/sequence values and proves the next RNG output after
restore. Unsupported older/newer saves are rejected without migration or automatic overwrite.
