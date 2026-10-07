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
