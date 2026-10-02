# История выполненных задач

- 2026-10-02 — R22.5 DONE: current-production System/Observer/physics audit, highlight lifecycle/shared-target/fallback cleanup, domain package lookup, preserved shared crouch head geometry, native hazard follow ownership with disabled/Night/restore cleanup, iterated Hunger state. Independent review R1–R7 FIXED; GUT 151/151 (921 assertions), strict hazard/integrated main feedback smokes and static structure/boundary/diff PASS without runtime leaks. Contract: `docs/gecs_architecture.md`; next R23 full-day validation.

- 2026-10-02 — R22 implementation (OWNER_QA): ordinary Health/Hunger/Money HUD, physical four-face package markings, committed damage snapshots with distinct player/toxic/explosion feedback, bounded world hit labels, lock denial and scanner rejection prompts. Separate review: no material findings. GUT 109/109 (548 assertions) without leaks after fixing regression fixture cleanup; strict player-feedback/gaze smokes, main headless shutdown and structure/diff PASS. Rendered full-scenario/gamepad/audio QA remains. Contract: `docs/player_feedback.md`.

- 2026-10-02 — R21 implementation (OWNER_QA): atomic next-Morning autosave/retry/startup, stable identity/ownership/slots/anchor/ink/quest restore, physical exactly-once paid delivery, Morning refusal return retaining penalties, permanent NEVER effects and transient reset, persistent hazard clocks/geometry/follow/attribution. Separate review R1–R10 FIXED; final GUT 72/72 (530 assertions), strict twelve-Night main scenario, headless shutdown and structure/diff PASS. Owner rendered/gamepad/full-day/layout/balance QA remains. Contract: `docs/persistence.md`.

- 2026-10-02 — R20 implementation (OWNER_QA): physical NavigationAgent Trader/exterior, atomic evening purchases, paid Terminal orders, identity-bound refusal quest retaining ordinary penalties, debug deadlines/delivery conditions. Separate review found no material issues; GUT 73/73 (662 assertions), strict main evening walkthrough and structure/diff PASS. Physical fulfillment/restart belongs to R21; owner walking/UI/balance QA remains.

- 2026-10-02 — R19 implementation (OWNER_QA): sole OwnedBy inventory ownership, bounded stack/transfer, quantity-driven world pickups, success-only Food/Med/Wrap effects, Tab modal UI and debug tasks/conditions. Separate review R4 fixed; GUT 35/35 (377 assertions), strict main pickup/UI/cleanup smoke and structure/diff checks PASS. Contract: `docs/inventory.md`; owner rendered/gamepad/balance QA remains.

- 2026-10-02 — R18 implementation (OWNER_QA): active-time Hunger, typed Food backend, reversible carry/speed/attack modifiers, Starving food visual and NPC speech with unchanged identity/orders/response routing, debug conditions/timers/tasks. GUT 69/69 (725 assertions), strict Hunger/combat smokes and structure/diff checks PASS; owner rendered/balance QA remains. See `agent_tasks/roadmap_18_hunger_and_perception.md`.

- 2026-10-02 — R17 implementation (OWNER_QA): separate simple NPC melee/ranged 3+3 variants with animation hooks and projectiles, Player blade, same-body NavigationAgent pursuit/escalation, typed durable combat context and seven-day retaliation lookup, combat debug conditions/timers. GUT 104/104 (881 assertions), strict real R08 impact/main combat and light challenge smokes PASS; owner animation/gameplay/layout QA remains. See `agent_tasks/roadmap_17_combat_and_impact_damage.md`.

- 2026-09-21 — Изучен и проиндексирован проект, создана папка docs/ и контекст подсистемы gameplay.
- 2026-09-21 — Добавлен прыжок с земли в S_Jump с проверками ввода и импульса.
- 2026-09-21 — Реализованы физический хват, перенос, вращение и бросок коробок с весовыми профилями; пройдены 36 тестов.
- 2026-09-21 — Введены удаление завершённых файлов задач из agent_tasks/ и краткая история в task_history.md.
- 2026-09-22 — Исправлены RayCast-наведение, контур доступной цели, регистрация lifecycle observer и устойчивость физического переноса предметов; пройдены 37 GUT-тестов.
- 2026-09-22 — R01: physical packages with persistent IDs, immutable shipment definitions, composable tags and independent runtime state; smoke checks and 7 existing regressions passed.
- 2026-09-22 — R02: typed contextual actions, tool input reservation/Alt override, F/use, crosshair and gameplay-driven prompts; 31 existing grab regressions and standalone interaction smoke passed.
- 2026-09-22 — R03: authoritative four-phase day cycle, F-operated shift/sleep stations, schedule gating and Night persistence hook; full world-action cycle and existing grab regressions passed.
- 2026-09-22 — Playtest fixes: contextual E/F priority, phase announcements, frictionless character contacts, 1.25 m carry distance and direct held rotation; real physics and rendered HUD checked.
- 2026-09-22 — R04: typed queued damage/heal pipeline, bounded health, single defeat with grab cleanup and separate package integrity adapter; damage smoke and 37 existing regressions passed.
- 2026-09-22 — R05: deterministic eight-parcel morning supply, data-defined carry/hazard profiles, collision-safe receiving with blocked-space retry and preserved old parcels; next-cycle smoke passed.
- 2026-09-22 — R06: physical scanner with idempotent cycle-scoped registration, result feedback and current-cycle terminal; printer definition prepared, rendered flow and 37 existing regressions validated.
- 2026-09-23 — R06.1: Inspector-first components, independent Carry/two hands, nested capture, E/F/G/swap/rotation and physical Push; reusable warehouse numbers corrected; 64 GUT tests and five smoke checks PASS.
- 2026-09-23 — R07: hand-mapped physical marker, bounded package-local ink with visible-face projection and lifecycle cleanup, numbered physical shelves 01–06; 68 GUT tests, five headless smokes and rendered storage preview PASS; R21 ink persistence contract documented.
- 2026-09-23 — Cart correction: independent grounded reversible transport, assisted stacked cargo and pickup/lifecycle cleanup; S_Push unchanged; 67 relevant GUT tests and three headless smokes PASS, visual playtest user-owned.
- 2026-09-24 — R08: generic Health/Impact and GECS cleanup, pair dedup and throw/source-veto contracts, package damage/depletion effects, fragile/protection profiles, Liquid leak, deliberate opening and condition feedback; durability rebalanced. User confirms all GUT tests pass and parcel damage/destruction/leakage work in-game. Final balance deferred to iteration; durable contract: `docs/damage_impact.md`.
- 2026-09-25 — Codex configuration simplified: short always-loaded rules, on-demand context, three specialized skills, opt-in reviewer/validator, compact checkpoint workflow.
- 2026-09-27 — Astra context refactor: shortened always/routinely read docs, reset stale checkpoint, split R22.5 into milestone-on-demand files, retained bounded tool/project context and sequential opt-in subagents.
- 2026-09-27 — Project code-style guardrails added: private non-exported behavior state and all @onready caches require "_" prefixes; authored .tres resources use searchable type prefixes; structure validator enforces both and existing definitions were renamed to def_*.
- 2026-09-27 — Code-style guardrails hardened: private-by-default behavior members, private-only @onready caches, and searchable canonical prefixes for project-authored Resource files enforced by project structure validation.

- 2026-09-27 — R09 completed: autonomous ToxicArea/Explosion and package adapters; tests and runtime acceptance confirmed by user. Durable contract: `docs/hazards.md`.

- 2026-09-27 - R10: session-owned wallet, atomic purchases, data-driven 100/120/150/200% settlements, persistent deduplication, daily results and Terminal feedback; 7 GUT tests / 42 assertions and headless wallet smoke PASS. Contract: `docs/economy.md`.

- 2026-09-27 — R11: persistent customer schedule/AssignedTo, physical counter, actual vs terminal outcomes, refusal/return/buyout and delayed complaints with reputation hooks; 27 GUT tests / 176 assertions and headless customer walkthrough PASS. Contract: `docs/customers.md`; visual acceptance not run.
- 2026-09-29 — Agent architecture migrated to right-sized Fix/Task/Feature workflow with on-demand develop/GECS/GUT/design skills, authoritative task state, compact CURRENT_WORK, task status index, review triage, DEFERRED status, and structural validation of normalized task metadata.

- 2026-09-29 — R11.1: prolonged interaction/reset policies, generic access/openable contracts, RemoteTransform3D-backed physical slots, collision-validated Carry placement, Hammer anchor/unfix with reversible physics/support safety; focused GUT and both physics smokes PASS, owner gameplay QA confirmed.

- 2026-09-29 — R12: DialogueManager integrated through typed customer context and project modal UI; direct package-number dialogue, riddle/retry with idempotent Satisfaction penalty, voluntary refusal, delayed complaint and false TAKEN/Aggressive handoff implemented. Focused R12 GUT and lifecycle smoke PASS; owner confirmed the dialogue flow works in main_level.

- 2026-09-29 — Added hidden reversible package history IDs (`day-number-hazard/size/mass`) and a next-Morning audit that auto-declares previously requested but still-unregistered shipments Lost, applies the existing 120% Lost settlement once, and removes the lost physical parcel while preserving registered unresolved shipments.
- 2026-09-29 — Corrected customer arrival semantics: package-pickup NPCs now wait for an active package registration and do not block shift completion while gated; due shipments still unregistered on the next Morning are closed Lost without spawning the NPC. Customer events with another authored purpose can opt out of the registration gate.
- 2026-09-29 — Split ignored registration from honest LOST economics: ordinary declared LOST remains 120% to preserve the refusal/fraud dilemma, while a due Package left unregistered until the next Morning now records LossCause.MISSED_REGISTRATION and a dedicated data-driven 300% settlement.
- 2026-09-29 — Migrated Terminal presentation to `Root/Panel/NewUI`: package-centric rows, detail view with durable history UID, search/sort/archive filters, package history and transaction logs, and only Taken/Refused/Lost outcome actions. Removed the legacy RichText/visit/Closeout UI, `terminal_text`/`registry_text`, and Terminal-driven refusal buyout/return path; refused parcels now remain warehouse-owned until a future physical unload/trash/vehicle interaction. Godot 4.7 UI script checks and project structure validation PASS; owner visual/gameplay QA remains.


## 2026-10-03 — Завершённые задачи удалены из очереди

По прямому требованию владельца удалены implementation task-файлы DONE/OWNER_QA; ожидающие игрока сценарии сохранены в qa_tasks. Ссылки на выполненные R11.1–R22.5 и организационные задачи перенаправлены сюда; исходные подробности сохраняются в Git. Открытые R23, новые замечания, CharacterBody-миграция и низкоприоритетная консоль остаются в agent_tasks.

Последние завершённые этапы dev: Windows QA export 8ebf7c55; rigid player/trader fixes 357a49b6/eb68777c; player QA migration 0fc15546; shared World/primitive level cc638f5d (2/2 GUT, 224 asserts); stair/nav UID repair a2e81594; native NPC avoidance + navigation cell_size 0.25 bd8d333c (14/14 GUT, 56 asserts; corridor, Trader, queue, reset; review R1 FIXED). Production nav bakes main 198/primitive 70 polygons; shared-world suite rerun 2/2, 224 asserts. Windows main/test bd8d333c each passed actual-scene confirmation + 120-frame startup, external certificate-store warning only. Manual player acceptance remains pending.

QA-01 rigid movement changes are historical and superseded by the new CharacterBody requirement. QA-02 Trader and QA-11 avoidance implementation are complete; their regression checklists remain in qa_tasks/owner_qa_fixes.md.

Completed implementation IDs retained for dependency resolution: R11.1, R12, R12.1, R12.2, R13, R14, R15, R16, R17, R18, R19, R20, R21, R22, R22.5. Их игровая приёмка отдельно ожидается в qa_tasks.
