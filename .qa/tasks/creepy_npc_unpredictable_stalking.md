# Жуткий — C4 rendered acceptance

Owner task: [creepy_npc_unpredictable_stalking](../../.agents/tasks/creepy_npc_unpredictable_stalking.md).

Status: **IN_PROGRESS**. Owner approved up to8 C4 rendered/playtest cases on2026-10-17; parcel budget is separate.
Budget: **3/8 cases consumed**. Case1 PASS for native skip branch only;
case2 INCONCLUSIVE overall (bounded episode confirmed, variation/surprise not established),
case3 INCONCLUSIVE (no active approach remained for the intended turn).

Runtime/schema26 reviewed through `d1b19fc4abbf2ccc27b8d7e89a7dc639fb05b348`,
BASE `dccea7c57b4cf6fbb3b7e63285023d1432a27322`; targeted RV-001 repair review PASS.
Full C3 initial review BASE `e45ca4d8251ffc43fdce1ab111a8afc32ac85722`,
TARGET `c6c850f6d28d3ea75e6575548808bc9053b2be87`; only RV-001 was accepted and fixed.
Main native service regressions38/38,320 assertions/stderr0 and delivery/save two-process smoke PASS.
Reviewer validation NOT_RUN. Native checks do not establish surprise or gameplay feel.

Runnable build: [PVZInHell.exe](../../.export/windows/20261016-160618Z-04110f3b-creepy-c3-parcel-h4/PVZInHell.exe),
main menu120/level120 headless PASS, isolated export QA profile. Subsequent changes concern
local runner/task bookkeeping; reviewed gameplay inputs are unchanged. Export itself emitted
shutdown-only dummy-texture RID retention, KNOWN_ENGINE_LIMITATION/DEFERRED under owner policy.
Use separate C4 QA slots; never ordinary autosave/manual slots. No new authoring defaults are approved.

| # | Prepared scenario and acceptance | Evidence/result |
| --- | --- | --- |
| 1 | Work at terminal: one native free opportunity may be skipped or take a hidden bounded route; nearby arrival feels unexpected and the NPC remains discoverable through actual view/LOS. No teleport or modal/camera capture. | PASS (skip branch only): actual terminal reader, native free opportunity seq0→1, skip/deadline10.05s fixed while150 physics frames advance2.5s; normal wandering, no episode/success memory/teleport. Actual terminal PNG inspected. `.artifacts/creepy-c4-085f/01-observation.json`, `01-terminal-skip.png`. Surprise/close arrival untested here. |
| 2 | Carry boxes and move: varying native opportunities/delays/sides, limited replans/time, no circling or endless following. Same captured opportunity never rerolls on each tick. | INCONCLUSIVE overall: native Carry retained through movement; episode1 kept ready3207070/deadline11207070/replans2, native approach reached a hidden point and ended within12.57 active seconds, notice=-1/memories0/sequence1. No reroll/endless following observed. Multiple opportunities/side variation and subjective surprise not established. `02-observation.json`, inspected `02-carry.png` in the same artifact directory. |
| 3 | Deliberately turn during approach; an early distant sighting aborts without close-success memory. Occlusion/FOV edges use actual camera visibility, not omniscience. | INCONCLUSIVE: no actual turn performed. Automatic customer priority interfered with initial staging; a transient eval compile error required game restart. Final native setup finished the actual appearance and phase; at2.083s sequence1 was consumed but episode0, distance3.177m, observedfalse, notice=-1/memories0. No distant-sighting or cancellation-cause claim. `03-observation.json`; no visual evidence for this criterion. |
| 4 | Actual detection below2.5m records one success and an ordinary reaction. No retry before30 active seconds; pause/save/reload/reset preserve the captured cooldown. Expiry alone does not create a new source. | NOT_RUN |
| 5 | Multiple recipients: rear SERVICE respects the existing queue/reservation. A waiting later recipient never bypasses the first; watched/cooling-down skipped service windows remain consumed for that visit. | NOT_RUN |
| 6 | Reach the rear contact, then turn: own registered number appears once only after real detection, no invented number for an unregistered order. Own held parcel transfers inside1m without F or return to the stationary counter. | NOT_RUN |
| 7 | Leave the work zone or obstruct the alternative path, including a short route watchdog: ordinary counter fallback retains visit/reservation/elapsed/source choice. No repeated attempt or double arrival/payment. | NOT_RUN |
| 8 | Interrupt with accepted dialogue, inspection, payment/departure or urgent danger/reset: ordinary role continues or ends by its owner, only rear movement is released, replacement intent remains intact. Inspection returns to the reached contact. | NOT_RUN |

Assess perceived surprise, the possibility of noticing early, ordinary reaction and absence of
service friction. Report inconclusive/failed cases explicitly. Unapproved rendered checks remain
NOT_RUN; C4/owner acceptance stays open until its required criteria are actually accepted.

Current execution code d7fbb8f6a06d2cd30acbe5235bb7098364200e92; C3 stalking runtime unchanged,
parcel dialogue migration085f1411 independently reviewed. Updated build049a5983 is available;
live MCP is the rendered target. Isolated C4 slots `user://qa_creepy_c4_*`, ordinary saves preserved.
Case1 preparation used native schedule completion and placement operations to stage the free NPC;
probability/delay/routes/authored defaults unchanged. No user surprise assessment claimed from skip.
Case2 used deterministic QA world_seed1 to select an approach, without changing native probability0.6,
delays or routes. Actual automatic customer appearance was finished by NpcServiceRole, then the
phase completed by NpcScheduleActionService before staging. Initial relocation is fixture setup,
never movement evidence. Case3 remains counted within the same eight-case budget.
