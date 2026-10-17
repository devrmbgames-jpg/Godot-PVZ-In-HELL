# Постоянные жители — личности, возвращение и авторское наполнение

Status: **IN_PROGRESS**
Technical: **IN_PROGRESS**
Execution order: **70**
Reference baseline: `d6ea70fe8a00071ee9a5b57aa4a7e647e108ea27`
Source: [полное исходное ТЗ](references/task-refactor-2026-10-17/district_authored_residents_and_resurrection.md.txt).
Процесс/приоритет источников: [README](README.md). Эта карточка — единственный текущий owner.

## Goal / acceptance

Девять авторских жителей (включая Вампира), постоянные дома/имена/личности и один returning
Lost без дома. Никаких случайных преемников; return_day = death_day + 2; одна партия каждой
действительной смерти. Сохраняются воспринятая память/отношения, реальные вещи/деньги/заказы,
личные квесты/награды и сроки Source. Новая кампания: старую схему отклонять, файл сохранять.
Все личные привычки/интересы/желания/диалоги/квесты и полная приёмка Source обязательны.

## Current

Последний reviewed provider `ccf91885d92fd415926ae765e4c868293403b135`:
R1a/R1b typed DEF_NpcPerson, три явные prototype-карточки, fixed ID/home/recipient/profile/scene,
seed/order independence, strict retained/fresh/cold restore. R2a календарь/retained body/loot
и R2b знание/персональная реакция реализованы, reviewed. NpcDeathRecord хранит факты отдельно
от known/suspected actor; detached наблюдение/день снимаются на C_Death до queued commit.
UI хранит borrowed номер эпизода; показ строки, не async чтение, подтверждает response_given.
Native idle subtree применяет разовую реакцию; бой/опасность/роли выше, NPC-конфликт сохраняет
разрешения/риски/ambient budget. Память не перезапускает погоню после одного эпизода.
Schema30/strict preflight/native golden согласованы; PVZH1 unchanged, ConfigFile DEFERRED.

R2c1 reviewed: buffered death/drop сохраняет supported carried quantity/physical ID, включая
native disable, disk/cold и повторную жизнь. RV-006 FIXED в ccf91885d92fd415926ae765e4c868293403b135.
R2c2 реализован, native orders/cold/schema gates PASS; **REVIEW_PENDING** до committed immutable review.
CustomerVisit.absence_sequence приостанавливает нерешённое появление. NpcReturnCommitted
возобновляет тот же visit после действительного возврата; срок доставки вычисляется чистым
HomeDeliveryDeadlineRules из исходного обещания и истории смертей, включая blocked return.
Старые claims/declaration/settlement/память не стираются. Физическая выдача/осмотр и две once
денежные операции проверены. UI/дверь показывают отсутствие без скрытой даты; schema31.
Новых job/bonus/quota/roster/таймеров нет. Personal R3 quest deadlines/rewards ещё открыты.

Main/rooms ещё profiles path — временная граница R1c, не постоянная dual resident модель.
Lost main пока placed merchant: до guest-перевода нужны семь barter-ролей. Девятый физический
дом — provider physical_homes_and_privacy. Ранние имена/образы/реплики — обратимые prototypes,
не финальный канон. R2c2 проходит завершающие gates; полный R3 не реализован.

## Work packages

| Пакет | Проверяемый результат |
| --- | --- |
| R1 | Fixed authored identity/home/recipient; R1c main/rooms без live resident generation. |
| R2a | Calendar +2, retained body, повторные смерти/loot, Night retry, strict disk/cold. |
| R2b | Различать распознанного/подозреваемого/неизвестного, личная реакция после возврата. |
| R2c1 | Реальные supported belongings при death/drop/return/disk/cold, без потери/дубля. |
| R2c2 | Сохранённые выплаты/заказы/личные сроки во время отсутствия; Source §§6–7. |
| R3 | Все nine/lost/home/content/малые quests/once rewards/диалоги и owner acceptance Source. |

Каждый пакет включает свои lifecycle/persistence/consumer gates; ни один не сокращает Source.
[Society foundation](npc_living_society/01_foundation_and_contracts.md) переиспользует R1/R2.
[Physical homes](npc_living_society/physical_homes_and_privacy.md) владеет rooms/doors/HOME runtime;
здесь — постоянная person→home привязка. Barter owns catalogs/prices/trade roles.

## Next

Commit проверенный R2c2 от reviewed BASE
`ccf91885d92fd415926ae765e4c868293403b135`, immutable review/triage/fix до принятия пакета.
Пока review pending — только независимый анализ barter/home/R3 authoring, без зависимых правок.
После R2 завершить R1c вместе с конкретными barter/home providers; проверить authored placed
merchant, удалить старую замену live residents. Полный авторский R3 остаётся обязательным.

## Validation / review

R2c2 actual, .artifacts/godot_agent/:
- `gut-20261017-000205866`: **29/585 PASS/CLEAN** — actual damage/blocked return, two deaths,
  carried box ID, disk, confirmed real inspection/handoff, original+bonus once, old fraud
  world deadline/real penalty, shared Control rendering/door caption, Night immutable retry,
  stale return event, invalid marker preflight, existing denial/reputation.
- `000222308`: existing delivery/offers **36/312 PASS/CLEAN**; fixture now stages held box
  in native reach (initial `000015639` 35/36 FAIL, no product reach change).
- schema31 golden generate `gut-20261016-235923726` **15/804**, ordinary read `235949246`
  **15/805 PASS/CLEAN**. Current golden native delta only version30→31; populated absence
  records exercised separately by real orders disk/cold. Previous file preserved by inherited test.
- terminal suite `gut-20261017-000640139`: 32/263 assertions PASS but wrapper **FAIL/UNKNOWN**,
  queued detached rows reported transient orphans. Native cleanup frame в after_each исправляет
  fixture: `000747357` **32/263 PASS/CLEAN**. Public offer fixture collection day fixed to3.
- MCP native path diagnostics six scripts CLEAN; smoke scene created/attached/saved via MCP.
- formatter/lint, strict architecture, structure/dependencies, persistence inventory PASS;
  staged final gate before commit. No suppression or expanded engine waiver.
Two-process orders smoke **PASS**, combined tests/artifacts/ logs:
`npc_return_orders-write-20261017-100621687.log`,
`npc_return_orders-restore-20261017-100630847.log`.
Isolated slot; cold data/prefab preflight, same physical ID/job/bonus, two lives, deadline6,
no payout/imagined visits. Manual I/O; scheduled Night proved separately by native GUT.
Initial cold smoke failed because fixture omitted native customer schedule in new process;
fixed fixture tuning, no codec/production workaround. Other early failed trials remain in logs.

R2c1 **PASS/CLEAN**: gut-20261016-233656753 20/413, inventory233816349 17/135;
red233619934 buffered drop lost stack, ordinary233536557 19/19 disproved general order failure.
Cold belongings logs tests/artifacts/npc_return_belongings-{write/restore}-
20261017-{093835601/093843728}.log. RV-006 FIXED `ccf91885d92fd415926ae765e4c868293403b135`.
Review BASE `bdd05240b7d03037eacd76c6ed2cce8d6549b82f` → TARGET
`ccf91885d92fd415926ae765e4c868293403b135`: PASS/no findings, repair0/2.

R2b actual native: death/LOS/BT/street27/488 (`233003727`), service+old dialogue41/812
(`232356332`), sight8/27 (`232211292`), grudge16/153 (`232248961`), schema30 golden read15/805
(`232145738`), golden generation15/804 (`232110354`); все gut-20261016, PASS/CLEAN.
Life/guest two-process logs: npc_life_cycle write/restore `20261017-092428846`/`092436956`,
npc_guest_life `20261017-092445067`/`092453164`. Own-death position/pending response survived
process exit; known-player disk restore/presentation are GUT, не cold/rendered claims.
MCP native path diagnostics CLEAN; anonymous script_patch reload43 отдельно не считался PASS.
Explicit verified .bin Godot path required by smoke runner (JSONC settings resolver initially failed).

| Canonical triage | Review / repair evidence |
| --- | --- |
| RV-004 timing, RV-005 Russian context docs **FIXED** | R2b BASE `5deafb36b509cb675f5144e4201c828e8fd5d9f0` → TARGET `6ec18d7f1b962aa8cabe2b7f47ff521e92d9a503`: two P2 accepted. Fix/re-review TARGET `bdd05240b7d03037eacd76c6ed2cce8d6549b82f`, BASE `6ec18d7f1b962aa8cabe2b7f47ff521e92d9a503`: PASS, cycle1/2. Red25/27 `232906671`, green27/488 `233003727`, both LOS directions/calendar; executable-line docs equivalence PASS. |
| RV-002 exact fields, RV-003 pending body **FIXED** | R2a BASE `2c0be0eae47131f0a3b41bcc23f1a5eced4ed015` → TARGET `30e6716aa696311581cd1be4145dbd1466d080cd`: two P2. Fix/re-review TARGET `5deafb36b509cb675f5144e4201c828e8fd5d9f0`, BASE `30e6716aa696311581cd1be4145dbd1466d080cd`: PASS, cycle1/2. Red `230318246`, green16/310 `230350002`, six corruptions reject before mutation. |
| RV-001 scene/card **FIXED** | code `83873c575b0db5cb6684b7ff90cdc6d1085fa0fd` had structure FAIL; read edge `0b86da5ba79f028f62c77d34991472e74956ab95` fixes gate. Re-review BASE `11d735a284aa0b4211608735266ea597c77de338` → TARGET `0b86da5ba79f028f62c77d34991472e74956ab95`: PASS, cycle1/2. |

R1 cold-smoke review BASE `0b86da5ba79f028f62c77d34991472e74956ab95` →
TARGET `2c0be0eae47131f0a3b41bcc23f1a5eced4ed015`: PASS.
R1a BASE `92da28ef275ff4e6331bb171251eb8e5ca9e2c41` →
TARGET `d143a897bcb0c508de1caa50f3eb4a9835d4723e`: PASS, cards8/89.
Raw early trial failures remain in artifacts; not engine-waived. Old offline authoring
`offlinescript-20261016-{214450592,215150462}.*` FAIL (ECS/scan/mixed shutdown), output
independently CLEAN GUT; no expanded waiver/investigation. Current assets use live MCP.

## Owner QA / blockers

R1c/authored placed merchant, R2c2 review, full R3 obligations and owner acceptance remain open;
вся задача не DONE. Required missing authoring data не заменяется случайной генерацией.
Rendered milestone budget **0/8**; по последнему указанию владельца не спрашивать повторно
в пределах неиспользованного лимита. Исчерпанные physics/H4/C4 budgets не переиспользуются.
Windows build этого внутреннего checkpoint NOT_RUN; build/visual acceptance — после связного R2.
