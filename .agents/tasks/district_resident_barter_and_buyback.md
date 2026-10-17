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
FIXED в `28f7d0270bb7f57129a76dba81f5b4dcbdf1441f`. Targeted re-review1/2 PASS:
BASE `2ba6993392232d31bded11a4a7c59e0692983802` → TARGET `28f7d0270bb7f57129a76dba81f5b4dcbdf1441f`,
/root/review_c3: no material findings, ARCHITECTURE/STYLE PASS, runtime NOT_RUN.
- RV-003 FIXED(`28f7d027`, lifecycle46/1019): frozen CraftingStep/копии requirements,
  output quantities/definitions, trash и hint_text. Source §9: preflight проверяет расход
  принятой последовательности без выбора по текущему каталогу; отключённый каталог не
  отменяет долг, но новые сделки недоступны. Schema34, old reject/preserve без миграции.
- RV-004 FIXED(`28f7d027`, actual depletion regression): finite health.current>0/not depleted/C_Death,
  actual HealthMutationService.apply depletion до terminal publication не даёт full blood.
T2a остаётся IN_PROGRESS:
cold diagnostic gate FAIL/UNKNOWN PagedAllocator, Windows QA/rendered NOT_RUN.
T3a original `172b9d45d79cee3f341cc0a30131b2ffdc998df2`, review BASE
`28f7d0270bb7f57129a76dba81f5b4dcbdf1441f` → TARGET `172b9d45d79cee3f341cc0a30131b2ffdc998df2`:
/root/review_c3 ARCHITECTURE FAIL / STYLE PASS / runtime NOT_RUN, один P2 принят.
RV-005 FIXED(`4c94c5dbd5812d2a5854b01f182e490cc823dff5`, native40/845): Source §1, role_profiles теперь keyed
permanent npc/6 из captured C_NpcIdentity.initial_fields; archetype не раздаёт магазин
другой личности. Legacy merchant fallback/SCENE provider сохраняются, live World lookup нет.
Targeted review1/2 PASS: BASE `172b9d45d79cee3f341cc0a30131b2ffdc998df2` →
TARGET `4c94c5dbd5812d2a5854b01f182e490cc823dff5`, /root/review_c3, no material findings,
ARCHITECTURE/STYLE PASS, runtime NOT_RUN. ET_NpcRoles выбирает
C_Trader по immutable role_profiles/role_trade_action, merchant job не меняется.
Карга получает evening-only аптечку/лечебное зелье/печенье/мясной пирог, реальные
отдельные Definitions/native pickups/food effects и существующее MED_ITEM лечение.
Prototype цены12/32/35, еда15/45, лечение20; это не финальный баланс.
Общий вход «Торговля» priority20 доступен через actual ray/resolver; native кнопка
панели переходит к прежней скупке с корректной передачей modal focus.
Новая схема не нужна: только authored config/unsaved derived C_Trader, schema34 сохраняется.
T3b original `d18f25bd31723b2a8c0a65f3d077d3ea51a8d908`; review BASE
`4c94c5dbd5812d2a5854b01f182e490cc823dff5` → TARGET `d18f25bd31723b2a8c0a65f3d077d3ea51a8d908`,
/root/review_c3: ARCHITECTURE FAIL / STYLE PASS / runtime NOT_RUN, один P2 принят.
RV-006 FIXED(code/test; fix SHA после commit): Source §10, food/med возвращены;
scanner/marker добавлены к прежним food/med/bubble_wrap, без решения удалять старое.
Исходные native tool prefabs/actions/tuning; prototype цены120/20.
Order prepay проверяет prefab compatibility; прежние queued next-morning/once/block/restore
сохраняются. Native entry «Снабжение ПВЗ», до оплаты цена/×1/утро/площадка выдачи.
Старый оплаченный food order сохраняет владельца ПВЗ после замены нового каталога.
Next: scoped RV-006 repair commit и targeted review1/2 BASE
`d18f25bd31723b2a8c0a65f3d077d3ea51a8d908` → новый TARGET. Затем T3c — отдельный владелец терминала/очереди Ангела.
Ангел/Охотник/Бугай/Элементаль и финальные цены/рецепты/площадки/T4 открыты.

## Validation / review

T3b native45/969 `031026261` PASS/CLEAN: 5 новых cases +40 inherited role/lifetime,
реальный terminal button→order panel, собственный ассортимент/цена/день/место до оплаты,
unsupported prefab no payment/receipt/queue, actual S_OrderDelivery two native tools,
old paid food after catalog update, blocked debt + disk restore, moved/deleted issued bodies
без respawn/оплаты. Finance8/76 `030918885`, normal schema34 golden15/839 `030933789`
PASS/CLEAN. MCP fresh5/5 native-path CLEAN, formatter5/strict architecture/structure/
persistence inventory/diffcheck PASS. Native Definition/terminal caption edits через MCP.
RV-006 repair45/981 `031331377` PASS/CLEAN: native UI показывает все5 доступных
предложений, включая прежние food/med, старый оплаченный заказ и tool once/retry сохранены.
MCP fresh2/2 CLEAN; formatter2/architecture/structure/diffcheck PASS.
T3b targeted review REVIEW_PENDING, Windows/rendered NOT_RUN, бюджет0/8; не DONE.

T3a native GUT39/832 `025525478` PASS/CLEAN: 8 новых actual cases +31 inherited
R2/T1, реальные эффекты еды/лечения, отдельные Defs/prefabs/цены, closed phase,
full/poor no payment, stable owned ID/receipt disk/death/return, реальный луч игрока
→ resolver → магазин → native кнопка скупки → release focus, без денег за навигацию;
actual SCENE compiler rejects conflicting role map/missing authored C_Trader без World writes.
Shared panel consumer29/386 `025254581` PASS/CLEAN; normal schema34 golden15/839
`025328180` PASS/CLEAN, неизменённый fixture читается с новым public-shop authoring. Его прежний fixture обращался
к CharacterBody как RigidBody.freeze: `025225354` FAIL, test-only pause исправлен.
MCP fresh7/7 native-path diagnostics CLEAN, scripts_instantiated0. Formatter8,
strict architecture/structure/persistence inventory/diffcheck PASS.
Native scene/resource authoring через MCP, исходный food_pickup не изменён.
T3a RV-005 RED39/40 `030010100`: лишние C_Trader/action у npc/106, один shared Profile.
GREEN40/845 `030113498` PASS/CLEAN, прежние39 cases сохранены; используется native pure build_plan.
MCP fresh2/2 CLEAN; formatter2/architecture/structure/diffcheck PASS для repair.
T3a Windows/rendered NOT_RUN, бюджет0/8; targeted repair review1/2 PASS по SHA выше.

T2a original staged gate PASS38; repair gate PASS10; targeted review PASS1/2, не DONE.
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

Original T2a evidence сохранено в `2ba6993392232d31bded11a4a7c59e0692983802`:
recipes6/34, lifecycle43/941, pickup93/444, truck23/156, schema33 golden/reader,
MCP38/38 и cold write/restore PASS. Это historical evidence, не новая schema34 проверка.
Offline authoring wrapper `offlinescript-20261017-015511306` остаётся FAIL: native
resave выполнен, но late autoload compile/mixed shutdown; waiver не расширен.

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
