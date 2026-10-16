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

Последний reviewed provider `bdd05240b7d03037eacd76c6ed2cce8d6549b82f`:
R1a/R1b typed DEF_NpcPerson, три явные prototype-карточки, fixed ID/home/recipient/profile/scene,
seed/order independence, strict retained/fresh/cold restore. R2a календарь/retained body/loot
и R2b знание/персональная реакция реализованы, reviewed. NpcDeathRecord хранит факты отдельно
от known/suspected actor; detached наблюдение/день снимаются на C_Death до queued commit.
UI хранит borrowed номер эпизода; показ строки, не async чтение, подтверждает response_given.
Native idle subtree применяет разовую реакцию; бой/опасность/роли выше, NPC-конфликт сохраняет
разрешения/риски/ambient budget. Память не перезапускает погоню после одного эпизода.
Schema30/strict preflight/native golden согласованы; PVZH1 unchanged, ConfigFile DEFERRED.

R2c1 реализован/проверен, **REVIEW_PENDING**: buffered inventory death после native disable
терял carried stack. O_InventoryLifecycle теперь сохраняет NPC belongings до exact-marker
terminal cleanup; InventoryDropService читает R_OwnedBy зарегистрированного dormant owner.
Нет нового writer/roster/таймера/схемы. Поддержанный virtual stack становится физической
выкладкой один раз; её quantity/ID переживают disk/cold restore и две жизни. Живой HOME
сохраняет прежний owned item ID. Native smoke scene создана/сохранена через MCP.
project.godot изменён штатным Dialogue Manager importer: только добавлен npc_return.dialogue
в POT sources; set delta verified, внешнего rewrite settings не было.

Main/rooms ещё profiles path — временная граница R1c, не постоянная dual resident модель.
Lost main пока placed merchant: до guest-перевода нужны семь barter-ролей. Девятый физический
дом — provider physical_homes_and_privacy. Ранние имена/образы/реплики — обратимые prototypes,
не финальный канон. R2c2 сроки/визиты/реальные выплаты и полный R3 не реализованы.

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

Commit R2c1, immutable review от BASE `bdd05240b7d03037eacd76c6ed2cce8d6549b82f`, triage/fix.
Пока review pending — только независимый анализ обещаний. Затем R2c2: существующий
CustomerNpcLifecycleBinding→NpcServiceRole.mark_dead окончательно ставит customer_dead/finish,
finish_evening делает FAILED. Сохранить job/visit/package/bonus/history и старые нарушения,
отложить личный срок до первого вечера фактического возврата без нового слота/награды;
мировые сроки отдельно. Учитывать blocked-space return и Night target morning, а не часы.
После R2 завершить R1c вместе с конкретными barter/home providers; проверить authored placed
merchant, удалить старую замену live residents. Полный авторский R3 остаётся обязательным.

## Validation / review

R2c1 actual **PASS/CLEAN**, .artifacts/godot_agent/:
- `gut-20261016-233656753`: 20/413, actual damage, оба обычных observer orders + buffered
  inventory after native disable, retained return, disk, second death, living HOME identity;
- `gut-20261016-233816349`: existing inventory 17/135;
- red `233619934`: 19/20, buffered path lost physical stack (0 instead of 1);
- initial ordinary orders `233536557`: 19/19 PASS — подозрение общего отказа не подтвердилось;
- native MCP path diagnostics three files CLEAN; formatter/lint, strict architecture,
  structure, persistence baseline PASS; staged gate before commit.
Two-process smoke **PASS**, combined tests/artifacts/ logs:
`npc_return_belongings-write-20261017-093835601.log`,
`npc_return_belongings-restore-20261017-093843728.log`.
Own isolated slot, actual carried quantity/ID, buffered death, cold restore, day3/day5 returns;
manual snapshot I/O, not claimed scheduled-Night or rendered QA. RV-006 buffered item-loss
исправлен в текущем R2c1 checkpoint; **REVIEW_PENDING**, repair0/2.

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

R1c/authored placed merchant, R2c2/full obligations, full R3 and owner acceptance remain open;
вся задача не DONE. Required missing authoring data не заменяется случайной генерацией.
Rendered milestone budget **0/8**; по последнему указанию владельца не спрашивать повторно
в пределах неиспользованного лимита. Исчерпанные physics/H4/C4 budgets не переиспользуются.
Windows build этого внутреннего checkpoint NOT_RUN; build/visual acceptance — после связного R2.
