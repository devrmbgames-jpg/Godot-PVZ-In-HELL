# Торговые роли — скупка, изготовление и отложенные заказы

Status: **IN_PROGRESS**
Technical: **IN_PROGRESS**
Execution order: **120**
Reference baseline: `d6ea70fe8a00071ee9a5b57aa4a7e647e108ea27`
Source: [полное исходное ТЗ и доказательства](references/task-refactor-2026-10-17/district_resident_barter_and_buyback.md.txt).

Карточка владеет текущим исполнением; Source сохраняет полный обязательный объём,
включая B1–B15. Процесс — [README](README.md), prototype не заменяет полный acceptance.

## Goal / acceptance

Семь торговых ролей и снабжение ПВЗ по Source/GDD. Дьявол: MORNING, 30–70%,
запрет святого символа, одна premium единица каждого из 1–2 реальных типов за 150%
после грузовика. Карга — EVENING, кости/артефакты по явной таблице.
Скромник: exact-first, сложность/приоритет, несколько изделий, первая неудача как
подарок/подсказка за кампанию, последующий мусор, успешные остатки — подарок.
Все каталоги, реальные вещи/деньги, чужое происхождение/посылочные последствия,
сроки, независимый терминал Ангела и отложенные заказы остаются обязательными.

## Current

T1a/T1b технические prototypes reviewed: native отдельные контейнеры Дьявола npc/9
и Карги npc/6, NPC action → confirmation → повторная проверка → резерв/оплата/выбытие.
Дьявольский спрос основан на завершённом фактическом BASE_SUPPLY/ledger, не плане;
цена/лимит сохраняются. Карга EVENING-only, без зависимости от утреннего supply.
C_Buyback владеет прайсом, C_Commerce — receipts, WalletService — единственные деньги.
Prototype цены Карги 5/45/45 (bones/holy_artifact/unholy_artifact), святой mapping Дьявола
holy_artifact и размещение не объявляются каноном.

T2a IN_PROGRESS — native prototype мастерской npc/3. C_Commerce.crafting_batches —
единственная история расхода/подарков/льготы/обещаний. C_Crafting — immutable profile
и transient retry/reservations; R_CraftingReserved — короткий live резерв.
Локальное подтверждение всего состава без взгляда/диалога с NPC. Чистый planner:
exact whole remainder → полностью выполнимые complexity/priority → повтор на остатке.
Сырая цепь/одежда из цепей/мусор — отдельные явно prototype Definitions и native тела;
spiked_chains не alias. Full blood проверяет actual health/emitter, не имя.
Первый failed непустой набор — подарок и надпись следующим утром, без мусора;
успех с подарком grace не тратит. Позже failed даёт authored trash.
S_Crafting исполняет ready_day=accepted+1: bounded native placement внутри ящика,
blocked debt сохраняется, каждый output ID выдаётся один раз, следующая партия после pickup.
Смерть/возврат NPC не отменяют очередь. Новый ID ящика не сбрасывает кампанию;
отсутствие точки сохраняет долг, возвращение прежнего ID позволяет продолжить.
Schema34/closed frozen steps + requirements/trash/hint/native profile identity preflight
и restore tickets включены; accepted plan не зависит от текущего каталога;
старые схемы отклоняются, файл сохраняется. Денежных операций у изготовления нет.

## Work packages

| Пакет | Проверяемый результат |
| --- | --- |
| T1 | Контейнерная скупка, явное подтверждение, once money/removal, реальные дневные цены/спрос/лимиты. |
| T2 | Полная партия Скромника, несколько изделий/приоритеты, первая льгота, подарки/мусор, следующее утро. |
| T3 | Прямые магазины, независимые отложенные заказы Ангела/Охотника/ПВЗ, часы/оплата/once выдача. |
| T4 | Полное авторское наполнение семи ролей, реальные площадки и матрица B1–B15 Source. |

Каждый пакет включает свой restore/failure/retry; обязательства не откладываются
в отдельную финальную техническую задачу. Полные T1–T4 и owner acceptance не DONE.

## Entry points / dependency gates

[Жители R1/R2](district_authored_residents_and_resurrection.md) дают stable личности/реальные
смерть и возврат. [A01](pvz_a01_commerce_panel_scene_first.md) технически принят;
его owner QA не блокирует производителей. [Внутренние закупки](npc_living_society/procurement_and_intermediaries.md)
используют эти владельцы, не создают конкурирующий публичный магазин/кошелёк.
Финальные комнаты/площадки — provider physical_homes_and_privacy, PLANNED; prototypes
не заменяют его и не телепортируют NPC. B01 ConfigFile остаётся DEFERRED, PVZH1 сохранён.

## Next

T2a original checkpoint `2ba6993392232d31bded11a4a7c59e0692983802`;
review BASE `dcfbc440220c38560423d821e10370ff1227caf4` → TARGET `2ba6993392232d31bded11a4a7c59e0692983802`,
/root/review_c3: ARCHITECTURE FAIL, STYLE PASS, runtime NOT_RUN. Оба P2 приняты и
ремонтированы в следующем scoped commit; targeted re-review1/2 ещё REVIEW_PENDING.
- RV-003 FIXED(code/test; fix SHA после commit): frozen CraftingStep/копии requirements,
  output quantities/definitions, trash и hint_text. Source §9: preflight проверяет расход
  принятой последовательности без выбора по текущему каталогу; отключённый каталог не
  отменяет долг, но новые сделки недоступны. Schema34, old reject/preserve без миграции.
- RV-004 FIXED(code/test; тот же fix commit): finite health.current>0/not depleted/C_Death,
  actual HealthMutationService.apply depletion до terminal publication не даёт full blood.
Закончить scoped commit и targeted immutable review. T2a остаётся IN_PROGRESS:
cold diagnostic gate FAIL/UNKNOWN PagedAllocator, Windows QA/rendered NOT_RUN.
После reviewed checkpoint продолжить T3; финальные цены/рецепты/площадки и T4 открыты.

## Validation / review

T2a original staged gate PASS38; repair targeted review REVIEW_PENDING, не DONE.
Repair native RED `023119341`:43/46 tests,990/998 asserts (три новых regression failures).
GREEN lifecycle46/1019 `023416051` PASS/CLEAN: изменение quantity/output/ingredients/priority,
отключение каталога, новая передача с обновлённым рецептом, frozen hint/trash,
actual depleted blood и 12 premutation corruptions; прежние43 cases сохранены.
Schema34 golden generation15/838 `023448871`, normal reader15/839 `023523623` PASS/CLEAN.
MCP fresh checked8 + ранее5 reports CLEAN, scripts_instantiated0; formatter12,
strict architecture/structure/persistence inventory/diffcheck PASS.
Cold repair functional write+restore PASS, **overall gate FAIL/UNKNOWN**:
`tests/artifacts/buyback-write-20261017-123608751.log` и
`.artifacts/crafting-review-cold-restore.{stdout,stderr}.log` (native exit0).
Во втором процессе обновлены recipe output/count/requirement по тем же путям;
выданы прежние2 clothes/расход1, подарки/IDs/grace/день/once money неизменны.
Verbose `.artifacts/crafting-review-cold-verbose.log`: retained151 GDScript,
35 GDScriptNativeClass,4 Resource; surviving Nodes не перечислены. Эта shutdown-категория
DEFERRED по owner policy; mixed PagedAllocator не waived, runner FAIL сохранён.
Самостоятельная engine leak investigation/изменение typing ради shutdown не открыты.

Original T2a native PASS/CLEAN, .artifacts/godot_agent/gut-20261017-*:
Native PASS/CLEAN, .artifacts/godot_agent/gut-20261017-*:
- recipes6/34 `014844963`: exact, complexity, quantity/order, gifts, actual typed recipes, invalid ranks.
- lifecycle43/941 `021003187`: full blood/raw chain, multi outputs, gifts/grace/hint/trash,
  actual death/return, partial disk restore, blocked placement, native UI cancel/new click,
  reserve/7 corruptions, queued restore, foreign extraction/late archive, nested payload,
  missing/recreated point. Inherited reviewed T1/R2 consumer cases включены.
- pickup93/444 `020221616`; truck23/156 `020603222` — реальные consumers нового резерва.
- schema33 golden generation15/832 `015726132`, normal reader `021529327` PASS/CLEAN.
Cold write/restore PASS: `tests/artifacts/buyback-write-20261017-121338345.log`,
`buyback-restore-20261017-121346447.log`: оба покупателя + pending crafting, fresh native
точки/ID, следующий день/2 реальные вещи, повторы без денег/копий, готовое состояние saves.
MCP 38/38 exact paths CLEAN; formatter38 PASS; strict architecture/structure/persistence PASS.
Native сцены/ресурсы через MCP. После move нового ingredient script в contracts два recipes
пересохранены native ResourceSaver при штатно закрытом editor; UIDs сохранены, editor restarted.
Offline wrapper `offlinescript-20261017-015511306` остаётся FAIL: оба resave в stdout,
но late editor-autoload ECS compile + mixed shutdown diagnostics; waiver не расширен.
Обычные runtime GUT/cold после resave CLEAN. Temporary authoring script удалён.
`020752050` — FAIL нового fixture, пытавшегося capture при pending commands;
исправлен snapshot до очереди, запрет pending capture отдельно проверен в `021003187`.

T1b review PASS: BASE `370020fcf796c211eaf341940befc71ddd17b206` →
TARGET `dcfbc440220c38560423d821e10370ff1227caf4`; /root/review_c3: no material findings,
ARCHITECTURE/STYLE PASS, reviewer runtime NOT_RUN, repair0/2. Native31/682 `012726127`;
двухпроцессные artifacts `buyback-write-20261017-112805993` / restore `112814113` PASS.
T1a original BASE `927fd5ab7c321505f229be80b8797794680a4daa` →
TARGET `f13078ecf28d0af35480c8eba4306d140ecbaef5`; оба P2 приняты и FIXED:
- RV-001 `370020fcf796c211eaf341940befc71ddd17b206`: exact WeakRef endpoints,
  retirement в captured World, busy/incomplete receipt не DUPLICATE.
- RV-002 тот же fix SHA: historical unknown сохраняется после late arrival,
  непустой history строго проверяется. RED25/28 `011729405` → GREEN28/602 `012047927`.
Targeted re-review1/2 PASS: BASE `f13078ecf28d0af35480c8eba4306d140ecbaef5` →
TARGET `370020fcf796c211eaf341940befc71ddd17b206`; /root/review_c3 no material findings,
ARCHITECTURE/STYLE PASS, reviewer runtime NOT_RUN. Sold-ID spoof snapshot остаётся запрещён.
Полный исходный набор T1 schema32/contents/truck/golden/runtime evidence — commit f13078ec.

## Owner QA / blockers

Канон/баланс/полные каталоги/физические площадки и B12 визуальная приёмка открыты;
эффекты одежды/огнестрел — исходный out-of-scope, не объявлены реализованными.
Первая prototype подсказка достижима: bones ×1 → физическая work_clothes; пример владельца
bones+raw_chain+полная blood_flask → chain_clothes реализован отдельным рецептом.
Raw chain ещё не финальная позиция снабжения; T4 обязан дать реальные пути получения.
Windows QA build/rendered T1 и T2 NOT_RUN. Бюджеты T1 **0/8**, T2a **0/8**;
в пределах milestone выполнять без повторного вопроса по последнему указанию владельца.
Соседние исчерпанные NPC budgets не возобновляются. REVIEW_PENDING/QA не выдавать за DONE.
