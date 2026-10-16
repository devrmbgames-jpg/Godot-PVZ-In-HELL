# Жуткий — C4 rendered acceptance

Owner task: [creepy_npc_unpredictable_stalking](../../.agents/tasks/creepy_npc_unpredictable_stalking.md).

Status: **NOT_RUN**. Owner approved up to8 C4 rendered/playtest cases on2026-10-17; parcel budget is separate.
Budget: **0/8 cases**. No screenshots or gameplay-feel PASS have been recorded for C4.

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
| 1 | Work at terminal: one native free opportunity may be skipped or take a hidden bounded route; nearby arrival feels unexpected and the NPC remains discoverable through actual view/LOS. No teleport or modal/camera capture. | NOT_RUN |
| 2 | Carry boxes and move: varying native opportunities/delays/sides, limited replans/time, no circling or endless following. Same captured opportunity never rerolls on each tick. | NOT_RUN |
| 3 | Deliberately turn during approach; an early distant sighting aborts without close-success memory. Occlusion/FOV edges use actual camera visibility, not omniscience. | NOT_RUN |
| 4 | Actual detection below2.5m records one success and an ordinary reaction. No retry before30 active seconds; pause/save/reload/reset preserve the captured cooldown. Expiry alone does not create a new source. | NOT_RUN |
| 5 | Multiple recipients: rear SERVICE respects the existing queue/reservation. A waiting later recipient never bypasses the first; watched/cooling-down skipped service windows remain consumed for that visit. | NOT_RUN |
| 6 | Reach the rear contact, then turn: own registered number appears once only after real detection, no invented number for an unregistered order. Own held parcel transfers inside1m without F or return to the stationary counter. | NOT_RUN |
| 7 | Leave the work zone or obstruct the alternative path, including a short route watchdog: ordinary counter fallback retains visit/reservation/elapsed/source choice. No repeated attempt or double arrival/payment. | NOT_RUN |
| 8 | Interrupt with accepted dialogue, inspection, payment/departure or urgent danger/reset: ordinary role continues or ends by its owner, only rear movement is released, replacement intent remains intact. Inspection returns to the reached contact. | NOT_RUN |

Assess perceived surprise, the possibility of noticing early, ordinary reaction and absence of
service friction. Report inconclusive/failed cases explicitly. Unapproved rendered checks remain
NOT_RUN; C4/owner acceptance stays open until its required criteria are actually accepted.
