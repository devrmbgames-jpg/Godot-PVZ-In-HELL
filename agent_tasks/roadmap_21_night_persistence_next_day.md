# R21 — Сон, autosave и следующее утро

Status: **OWNER_QA**

## Task state

### Goal
Замкнуть цикл и сохранить долгосрочные результаты в одном autosave slot.

### Constraints / acceptance
- This is a Feature-level tracked task.
- Зависимости: R03, R05, R09, R11, R11.1, R14, R18, R19, R20
- Reuse existing authoritative contracts from completed dependencies; do not duplicate them.
- The existing `## Работы`, `## Критерии готовности`, `## Проверки`, and `## Границы` sections remain the detailed implementation specification.
- Follow Godot 4.7, GECS ownership, physics authority, and validation rules from `AGENTS.md`.

### Milestones
- [x] Reconfirm dependency completion and current production owners/contracts.
- [x] Foundation: Night/store/codec/world restore/physical orders (`baaa8478`).
- [x] Physical Morning refusal return and two-Night consumed-order persistence scenario.
- [x] Complete relationship validation/permanent completion/reset regressions and the remaining work checklist.
- [x] Independently review material changes and resolve all R-findings.
- [x] Run final task validation according to the documented GUT/headless budget.
- [x] Record remaining owner gameplay/visual QA.

### Decisions
This file remains authoritative.
- Save one atomic autosave containing the next Morning state. Night cannot advance on write failure; retry preserves the same target day. Restart after a successful write resumes that Morning.
- Persist only explicit data contracts and stable IDs; runtime nodes/control/session references are excluded. Reconstruct live ownership/slot/quest relationships after all entities exist.
- Keep package-local ink and physical transforms; stop transient velocities and hand/push/dialogue/challenge captures at Night. Never clean a parcel merely because its customer is absent today.
- Physical paid orders carry order/<operation ID>; fulfilled records survive pickup/consumption. Blocked receiving retries without charging again.

### Current
Agent implementation complete. Foundation `baaa8478`, physical Morning return `daf17670`, final hardening in the current milestone. Preflight checks stable IDs, resolved authored paths, ownership roles/capacity, physical slot/cart types and required prefab/profile data before mutation. Reindex the derived World ID registry once on restore. Preserve NEVER completion and valve effect without executing again; reset incomplete progress. Restore persistent hazard clocks, native geometry, live attribution/follow by stable keys and source veto, preserving resolved explosion guards. Apply saved disabled state after geometry setup. All review R1–R10 FIXED. Next roadmap task: R22 HUD/world feedback. Owner rendered full-day scenario, gamepad, physical layout and multi-day balance QA remain.

### Validation
- Final GUT 72/72 PASS, 530 assertions (`tests/artifacts/r21_final_gut.log`): save/codec/world/permanent runtime/return/customer/commerce/anchoring surfaces, including malformed path/role/capacity/required-profile no-mutation regressions.
- Strict `night_persistence-20261002-091151100.log` PASS: twelve Nights through Morning 13 and level recreation; preserved registered late target/number/condition/ink, consumed order never respawns, physical refusal return keeps penalties, permanent NEVER effect survives, real Carry slowdown/rotation capture reset. Fixture skips customer Day playthrough and supplies actual refusal through OutcomeService; no full customer/scenario or rendered claim.
- Main headless startup/shutdown 120 frames: no project runtime error/resource leak; external Windows certificate-store error only. Structure/diff checks PASS. Separate read-only review R7–R10 FIXED/rechecked, no tests run by reviewer.
- Return milestone GUT 53/53 PASS, 402 assertions (`tests/artifacts/r21_return_gut.log`): return eligibility, identity/number, future target/false declaration/unheld rejection plus save/world/customer/commerce regressions.
- Strict `night_persistence-20261002-083948714.log` PASS: two Sleeps/recreated levels, consumed paid order never respawns, actual ray/automatic authored grab profile/F return point, retained refusal penalty and lifecycle/number release, returned parcel remains gone, late quest target remains physical. Fixture supplies the prior refusal fact through CustomerOutcomeService; no full customer dialogue/day playthrough claim.
- Foundation GUT 15/15 PASS, 114 assertions (`tests/artifacts/r21_foundation_gut.log`): codec/records/canonical definitions, atomic overwrite/checksum corruption, negative debt, write failure/retry without day increment, repeated owned-item restore, unknown/missing fields/targets, null Package definition, real swapped physical slots and disabled Entity lifecycle.
- Strict `night_persistence-20261002-082146990.log` PASS after review fixes: main Sleep -> autosave -> level recreation -> Morning, one physical paid order, inventory ownership, late quest target and reusable number, HP/opening/damage/ink and stale Sleep rejection. Isolated test slot removed afterwards; no rendered/visual claim.
- Structure validator and diff checks PASS. Headless editor imports resolved classes; external certificate/editor settings/plugin errors prevent a clean editor claim.
- Separate read-only review R2–R6 integrated; reviewer rechecked R4–R6 as FIXED and ran no tests. Final hardening regression/review completed above.

### Owner QA / blockers
Ручные проверки и результаты игроков: [сценарий QA](../qa_tasks/commerce_and_persistence.md).

Игровая приёмка ожидается; перенос не означает успешного прохождения. Реализация и автоматические доказательства остаются в этой задаче.

### Review
| ID | Severity | Finding | State | Evidence / decision |
| R1 | BUG | New Systems lacked explicit GamePlay group. | FIXED | Scene group contract restored; structure and strict smoke PASS. |
| R2 | BUG | Legitimate wallet debt blocked Night snapshot. | FIXED | Signed wallet bounds match WalletService; debt/retry/progression GUT PASS. |
| R3 | BUG | Missing scene/authored_path could pass preflight then throw. | FIXED | Explicit String fields required; no-mutation GUT PASS. |
| R4 | BUG | Restore retained obsolete ownership/slot bindings; per-item replacement failed swapped slots. | FIXED | Clear all old links before all saved state/bindings; transfer guard; owner swap and real slot swap regressions PASS; reviewer rechecked. |
| R5 | BUG | Null Package definition could fail after world mutation. | FIXED | Definition and matching nonempty Package ID validated before commit; regression PASS; reviewer rechecked. |
| R6 | BUG | Entity enabled flag bypassed World lifecycle and processing changes. | FIXED | World enable/disable APIs, preserving stored-item processing; callbacks/flags GUT PASS; reviewer rechecked. |
| R7 | BUG | Alternate authored paths could map two records to one Entity or outside the level. | FIXED | Resolve/deduplicate actual instances and require root descendants before mutation; registry/path regressions PASS; reviewer rechecked. |
| R8 | BUG | Omitted required Package/Hazard component could fail after commit began. | FIXED | Required prefab component preflight; omitted-component no-mutation regressions PASS; reviewer rechecked. |
| R9 | BUG | Disabled hazards skipped native geometry setup. | FIXED | Rehydrate while enabled, then World.disable; recreate/enable shape-mask regression PASS; reviewer rechecked. |
| R10 | BUG | Null/incompatible hazard profile could retire a restored entity after mutation. | FIXED | Shared setup/load profile validator and concrete prefab compatibility; malformed-profile no-mutation regressions PASS; reviewer rechecked. |


---

Зависимости: R03, R05, R09, R11, R11.1, R14, R18, R19, R20
Ветка/base: master / `0390f1b7`.
Источники: [ТЗ 03](../docs/roadmap/03_day_phase_cycle.md), [ТЗ 08.1](../docs/roadmap/08_1_arrangement_extended_interactions.md), [ТЗ 14](../docs/roadmap/14_evening_meta_scaffold.md), [ТЗ 15](../docs/roadmap/15_night_save_next_day.md), [ТЗ 17](../docs/roadmap/17_vertical_slice_scenario.md).

## Цель

Замкнуть цикл и сохранить долгосрочные результаты в одном autosave slot.

## Начать здесь

- [content/scenes/main_level.gd](../content/scenes/main_level.gd)
- [content/scenes/main_level.tscn](../content/scenes/main_level.tscn)

Затем прочитать контракты, созданные задачами-зависимостями. Имена новых типов из roadmap — проектируемые контракты, а не утверждение о существующих файлах.

## Работы

- [ ] SleepPoint запускает одну транзакцию Night: результаты, persistent snapshot, PendingDelivery, DayIndex и новый Morning.
- [ ] Сохранить минимум DayIndex, Money/Penalties, Health, Hunger, upgrades/purchases, quest flags, PendingDeliveries; дополнительно сохранить Inventory и связи identity, необходимые уже работающим задачам.
- [ ] Сохранять активные/невыданные Package через любое число дней: stable identity, reusable registration number, состояние Opened/Damaged, ownership/physical persistence и RequestedPackage identity. Ночь сама по себе не освобождает номер.
- [ ] Сохранять actual delivery outcome отдельно от Terminal declaration, unresolved Complaints/disputes, примененные settlement operation IDs и 7-day justified-retaliation windows.
- [ ] Сохранять persistent physical-slot/placement/fixed-object state из R11.1 там, где объект должен переживать ночь; временный interaction progress/control capture не сохранять.
- [ ] Сбрасывать schedule, временные challenges/dialogue/hazards/reservations; сохранять явно persistent последствия.
- [ ] Определить политику физического расположения и маркерных штрихов между днями; исключить потерю quest-target и дубликаты ID. Customer arrival может быть запланирован через 10+ дней либо никогда, поэтому отсутствие события сегодня не является cleanup condition.
- [x] Поддержать morning return отказной Package: lifecycle/номер закрываются только после successful return commit; существующая Complaint/штраф не отменяются автоматически.
- [ ] Восстанавливать ссылки по стабильным ID, не сериализовать Node/Relationship runtime напрямую; безопасно обрабатывать отсутствующий/некорректный save.
- [ ] Доставлять каждый оплаченный order ровно один раз даже после повторного load или прерывания перехода.

## Критерии готовности

- Morning второго дня сохраняет необходимые характеристики и quest flags, приносит заказанный предмет.
- Зарегистрированная, но невыданная Package предыдущего дня остается физически/логически активной с тем же номером; unresolved dispute переживает save/load без повторного штрафа. Если package-pickup Customer был due, но NPC не появился из-за отсутствия registration record, а Package к следующему Morning всё ещё не зарегистрирована, визит автоматически закрывается как LOST / MISSED_REGISTRATION без спавна NPC, получает отдельный существенный штраф (default 300% accounting value) один раз и Package удаляется из физического склада.
- Перезапуск игры восстанавливает согласованное состояние; повтор Sleep/load не дублирует доставку или DayIndex.
- Нет оставшегося slowdown, rotation lock или временной опасности после reset.

## Проверки

GUT: round-trip, missing/corrupt save, reset/persist, повторное применение delivery; integration Night → restart → Morning. Общие команды и правила завершения — в [README](README.md).

## Границы

Один autosave slot; без облака, multiplayer и полного редактора сохранений. Сохранять Godot physics authority, GECS data/behavior boundaries и read-only addons. Выполненные основания переиспользовать, а не создавать заново.

## Первый шаг

Проверить завершение зависимостей по task_history.md и существующим контрактам, затем прочитать указанные исходники и актуализировать WORK.md/CURRENT_WORK.md. При реализации не считать непроверенные пункты выполненными.
