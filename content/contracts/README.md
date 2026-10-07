# Typed gameplay boundaries

Request/Command carries intent. A `true` submission accepts dispatch and does not promise
completion. Event/Result carries a committed fact, or an explicit terminal rejection.
Synchronous domain operations return their committed result directly. They do not need an
artificial event pair. `World.emit_event` is synchronous; structural CommandBuffer work is not.
`deps()` orders Systems but does not flush `PER_GROUP` work.

## Owning boundaries

| Domain | Entry / sole command handler | Completion / commit point | Idempotency and regression |
|---|---|---|---|
| Damage | `DamageRequestService.submit(DamageRequest)` → `O_Damage` | `DamageResult.EVENT` follows health arithmetic, with copied attribution/correlation and stable target ID; rejected/blocked results cannot announce applied damage | Separate hits remain separate commands. Death/depletion/package consumers protect their own terminal effects. `test_refactoring_v2_boundaries`, `test_damage_feedback`, combat regressions |
| Commerce | `CommerceService.purchase`, `order`, `home_delivery` | Returned `Status.COMMITTED` follows wallet, grant/delivery and `PurchaseReceipt`; diagnostics follow the same mutation | Operation ID + payload receipt detect duplicate/conflict. `test_commerce` |
| Interaction | Existing synchronous action API; `PackageOpening.request_open` → `O_PackageOpening` for deferred opening | `PackageOpenResult` remains `PENDING` until the handler commits; prolonged action succeeds only on `COMMITTED`. `PlayerInteractionEvent` and `PackageLifecycleEvent` describe actual transitions | Opening state prevents replay; action completion cannot mistake dispatch for success. `test_package_contents`, `test_player_interaction_events`, `test_prolonged_session` |
| Customer outcomes | `CustomerOutcomeService` synchronous operations; Dialogue contexts validate the current session before invoking them | Bool success means committed mutation of the current `CustomerVisit` aggregate; settlement flags and wallet journal precede trace completion | Intent mask, riddle flags, complaint/declaration/settlement history protect repeated actions. Closed contexts reject late mutations; panel discards late awaited lines and releases pinned runtime references. `test_customer_dialogue`, `test_customer_flow` |
| Quests | `RefusalQuestService.accept` / `ignore`; scheduled resolution remains task 19 | Choice returns committed bool; resolution records state and removes live binding before diagnostics; reward follows wallet result and `reward_paid` | Quest state and deterministic reward operation ID protect repeat effects. `test_refusal_quest` |
| Hazards | `HazardSpawnService.submit` → `O_HazardSpawn`; `HazardResetRequest` → reset observer | `HazardSpawnResult.EVENT` follows materialization and required ownership links; bool submit is dispatch only | Request ID deduplication; scheduled ownership review remains task 23 |
| Lights | `LightFlickerRequest` → `O_LightFlicker` | START/STOP are requests on the preserved `light_flickering` channel; `CircuitLightView` presents the request, not a second gameplay handler | No legacy `LightFlickerEvent` alias; light regressions |

## Existing payload classification

- Intent: `DamageRequest`, `PackageOpenRequest`, `HazardSpawnRequest`, `HazardResetRequest`,
  `LightFlickerRequest`, `DayTransitionRequest`, `MoneyOperation`, `CustomerDialogueIntent`.
- Terminal facts/results: `DamageResult`, `DamageFeedback`, `HealthDepletionEvent`,
  `ImpactResult`, `PackageOpenResult`, `PackageLifecycleEvent`, `PackageDebrisSpawnedEvent`,
  `PlayerInteractionEvent`, `HazardSpawnResult`, `ChallengeResult`, `ChallengeResolution`,
  `DailyMoneyResult`, `PackageDeliveryCheck`, `PackageScanResult`, `AccessResult`, `GameSaveResult`.
- ECS-owned records / immutable authored or computed data: visits/complaints, quest records,
  purchase receipts/pending deliveries, NPC population/delivery/memory records, receiving batches,
  package registration/mark/history records, body/contact snapshots, interaction progress/captures,
  attack/action choices, combat/route/lighting/control contexts and presentation notices.
  Their Resource/RefCounted representation does not establish a second mutable authority.

## Diagnostic provider

`BoundaryTrace` is the sole writer of transient `C_BoundaryTrace.entries`. The optional session
component retains at most 128 reason-coded entries with operation, stage, correlation, origin
and target IDs. `snapshots()` returns detached scalar copies. Domain identities prefer package,
NPC and persistent IDs, then explicit Entity ID; never NodePath or instance ID. Explicit commerce,
visit, quest and hazard IDs keep their domain meaning. Automatic IDs are session-local diagnostics,
not persistent idempotency keys. Entries authorize no effects and are excluded from save codecs.

Provider fixtures live in task 40; the read-only debugger presentation belongs to task 48.
Execution dispatcher removal remains with tasks 11–25, contract relocation with task 28 and
dependency enforcement with task 33. There is no global dispatcher or wildcard subscription.

## Customer planning execution owner (task 11)

O_CustomerPlanning is the sole handler of CustomerPlanningRequest (discrete planning/reconciliation).
A completion receipt is pending until its actual buffer flush; stale runtime session/day may reject
with rejection_reason. DayPhaseChanged is an immutable committed phase snapshot, also used to bootstrap
the authored/restored current phase. PackageScanResult.EVENT follows actual registered state and
releases due followups in the same day. S_CustomerFlow owns recurring arrival timing/history; S_CustomerArrivals projects the count
and submits one selected materialization after terminal phase commits. No second planning path.

Planning cache is transient, rebuilt at bootstrap and invalidated by current-format restore.
Active phases are owned by explicit Systems (task 12); outcome polling remains unfinished 13.
District enqueue belongs to 16.

## Customer runtime cadence and first contact (task 12)

Isolated S_CustomerClock -> S_CustomerGreeting -> phase-specific Systems -> S_CustomerArrivals
runs before day/navigation/decision consumers. Transient scheduled_phase snapshots prevent
multiple owners consuming a newly entered phase in the same step; they are not persisted.

CustomerGreetingRequest has one synchronous O_CustomerGreeting handler. Scheduling or the
native wait-for-parcel leaf requests first contact; the handler owns authored eligibility,
input focus and line-of-sight checks. Announcement remains a reusable explicit command.

NpcDecisionReady is a committed perception snapshot with its accumulated due-step interval.
O_CustomerServiceClock consumes it synchronously before native BT execution; no structural
commands are queued for scalar role/entrance clock writes. Observer MANUAL buffer mode does
not change this boundary. Task 15 migrates the decision publisher while preserving this
fact/cadence; there is no second Service clock or generic customer phase dispatcher.
