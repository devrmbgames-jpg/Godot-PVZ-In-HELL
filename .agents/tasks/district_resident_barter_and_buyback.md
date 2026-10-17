# Торговые роли — скупка, изготовление и отложенные заказы

Status: **IN_PROGRESS**
Technical: **IN_PROGRESS**
Execution order: **120**
Reference baseline: `d6ea70fe8a00071ee9a5b57aa4a7e647e108ea27`
Source: [полное исходное ТЗ и доказательства](references/task-refactor-2026-10-17/district_resident_barter_and_buyback.md.txt).

Карточка — текущее исполнение; Source сохраняет полный обязательный объём §1–12/B1–B15.
Prototype не заменяет acceptance; процесс [README](README.md).

## Goal / acceptance

Семь торговых ролей и снабжение ПВЗ. Дьявол MORNING, 30–70%, запрет holy_artifact,
premium150% за одну единицу каждого из 1–2 фактически прибывших типов. Карга EVENING,
явные ставки bones/артефактов. Скромник: exact-first/complexity/priority, несколько изделий,
первая неудача — кампанийный подарок/подсказка, позднее мусор, успешные остатки — подарок.
Реальные вещи/деньги, подтверждение, provenance/посылочные последствия, независимые
терминалы, срок accepted+1, once output IDs, native authoring, смерть/возврат и save обязательны.

## Current / authority

T1a/T1b reviewed technical prototypes: отдельные контейнеры npc/9 Дьявола и npc/6 Карги.
C_Buyback — прайс; C_Commerce — receipts; WalletService — деньги. Спрос лишь после
ReceivingSupplyCompleted фактического BASE_SUPPLY/ledger, не плана. Карга EVENING-only
без supply-зависимости, prototype ставки5/45/45 не объявляются каноном.
T2a reviewed prototype npc/3: C_Commerce.crafting_batches — единственная durable история,
C_Crafting — native profile/transient retry/reservations, R_CraftingReserved — live резерв.
Frozen CraftingStep/requirements/output/trash/hint, replay расхода без нынешнего каталога;
full blood читает actual health.current/not depleted. Подарки/льгота/частичная выдача/долг
сохраняются, смена ID контейнера не сбрасывает кампанию. Native raw_chain/chain_clothes/trash;
пример bones+raw_chain+полная blood_flask, simple bones→work_clothes. Эффекты одежды не добавлены.
T3a reviewed prototype магазина Карги: immutable ET_NpcRoles.role_profiles keyed permanent npc/6
из captured C_NpcIdentity, не archetype. EVENING med/healing_potion/cookie/meat_pie;
реальные native pickups и штатные FOOD/MED_ITEM effects. Prototype цены12/32/35,
еда15/45/лечение20. Actual ray/resolver→Торговля(priority20)→native скупка с передачей focus.
T3b reviewed prototype ПВЗ: прежние food/med/bubble_wrap сохранены, scanner/marker добавлены,
исходные native tools/actions; prototype цены120/20. Prefab prepay gate, next-morning debt/once,
цена/×1/утро/площадка в UI. Прежний оплаченный food order сохраняет владельца ПВЗ.

T3c IN_PROGRESS: C_AngelOrders — отдельные catalog profile/receipt+queue/sequence;
C_OrderReceiving — собственный transient placement/retry; выданные тела передаются native level,
а не становятся дочерними терминалу (его перенос не перемещает мебель). S_AngelOrderDelivery — свой lifecycle,
старый S_OrderDelivery исключает C_AngelOrders. Общие Wallet и явный physical placement;
CommerceService.current не владеет Ангелом. Native terminal/panel/receiving marker и typed profile,
shelf-only prototype, не каноническая home placement. Заморожены цена/день/домашний hint/ID,
paid/issued/received разделены, тело world-owned, границы async ticket и публикации проверяются.
Schema35/closed records, деньги/ID/native capability preflight; unsupported reject/preserve.

## Work packages / dependencies

| Пакет | Полный результат |
| --- | --- |
| T1 | Контейнерная скупка, подтверждение, once деньги/выбытие, реальные цены/спрос/лимиты. |
| T2 | Полная партия Скромника, несколько изделий/приоритеты, льгота/подарки/мусор, следующее утро. |
| T3 | Прямые магазины, отдельные Ангел/Охотник/ПВЗ, часы/оплата/once выдача. |
| T4 | Все семь ролей, реальные авторские площадки, полные каталоги/баланс, B1–B15. |

Каждый пакет включает свой restore/failure/retry. Полные T1–T4/owner acceptance не DONE.
[Жители R1/R2](district_authored_residents_and_resurrection.md) дают проверенные stable identities/death/return.
[A01](pvz_a01_commerce_panel_scene_first.md) technical accepted, owner QA не блокирует producers.
PhysicalHomes/Privacy PLANNED — финальные комнаты/площадки, prototypes их не заменяют.
[Внутренние закупки](npc_living_society/procurement_and_intermediaries.md) используют эти owners.
B01 ConfigFile DEFERRED, PVZH1 сохранён; миграции старых схем не добавляются.

## Next

T3c: staged gate и отдельный commit от BASE `adbb708b93347c55880234702a3291fda6168a7e`.
Затем read-only exact-SHA review/triage; пока review pending — только независимая работа.
Т3d Охотник, Бугай/Элементаль и полное T4 остаются открыты. Не добавлять неготовое gunplay.

## Validation / current review

T3c native GUT **13/174 PASS/CLEAN**, `gut-20261017-034428004`:
actual native action/UI/cancel/confirm/focus, price/date/place prepay; wrong/unsavable prefab,
phase/poor/blocked no payment; bidirectional absent owners, busy PVZ; separate blocked debt/retry;
disk/in-place restore, multiple frozen promises, moved/deleted bodies, old ticket/world switch,
11 premutation corruptions, native publication capture/reentrant guards. MCP fresh8+8 CLEAN,
scripts_instantiated0; final4 native paths CLEAN. Editor4 historical errors относятся только
к intentional authoring_cycle_* invalid fixtures, не изменённым Angel paths.
Shared native placement consumer11/204 `gut-20261017-034458600` PASS/CLEAN;
schema35 golden generation15/846 `034143410` PASS/CLEAN, normal reader15/847 `034256397` PASS/CLEAN.
Formatter19/strict architecture/structure/inventory/diffcheck PASS; staged/review ещё NOT_RUN.
Cold functional write+restore PASS, **overall FAIL/UNKNOWN** mixed shutdown:
`tests/artifacts/angel_furniture-write-20261017-133751654.log`,
`.artifacts/angel-cold-restore.{stdout,stderr}.log` (native exit0). Partial2/3 issued,
changed catalog/price/hint, moved/deleted issued bodies, remaining debt once, no second payments.
Write had UID warnings before editor scan; restore has no UID warnings. Mixed ObjectDB347Resources/
PagedAllocator still not waived. No repeated cold runs merely for green labels or leak investigation.
Native MCP rename отказал unchanged: project discovery>10000. Сохранённый Editor штатно закрыт;
native ResourceSaver rename исправил def_ filename/reference; guarded Editor restart PID24788.
Wrapper `offlinescript-20261017-033629945` FAIL (mixed shutdown), functional rename PASS;
final native GUT/cold paths verify saved result. No temporary script committed.
Auto-review: широкий loop отклонён unchanged; corrected только4 новых Angel edges.
T3c Windows/rendered NOT_RUN, **0/8**; до оставшегося лимита не спрашивать повторно.

## Prior immutable review / finding evidence

T3b BASE `4c94c5dbd5812d2a5854b01f182e490cc823dff5` → original `d18f25bd31723b2a8c0a65f3d077d3ea51a8d908`:
P2 RV-006 принят, FIXED `adbb708b93347c55880234702a3291fda6168a7e` (Source§10, food/med retained).
Targeted1/2 BASE d18f25bd(full above) → TARGET adbb708b(full above), /root/review_c3:
no material findings, ARCHITECTURE/STYLE PASS, runtime NOT_RUN. Native45/981 `031331377` CLEAN;
original45/969 `031026261`, finance8/76 `030918885`, golden15/839 `030933789` CLEAN.
MCP/style/architecture/structure/inventory/staged gates PASS; Windows/rendered0/8 NOT_RUN.

T3a BASE `28f7d0270bb7f57129a76dba81f5b4dcbdf1441f` → original `172b9d45d79cee3f341cc0a30131b2ffdc998df2`:
P2 RV-005 FIXED `4c94c5dbd5812d2a5854b01f182e490cc823dff5` (Source§1, permanent identity keyed role).
Targeted1/2 BASE172b9d45(full above)→TARGET4c94c5db(full above), /root/review_c3 no findings,
ARCHITECTURE/STYLE PASS, runtime NOT_RUN. RED39/40 `030010100`→GREEN40/845 `030113498` CLEAN.
Original39/832 `025525478`, shared panel29/386 `025254581`, golden15/839 `025328180` CLEAN;
stale CharacterBody fixture freeze corrected. MCP/style/static PASS; Windows/rendered0/8 NOT_RUN.

T2a BASE `dcfbc440220c38560423d821e10370ff1227caf4` → original `2ba6993392232d31bded11a4a7c59e0692983802`:
P2 RV-003 frozen plan/hint/catalog replay and RV-004 depleted blood FIXED
`28f7d0270bb7f57129a76dba81f5b4dcbdf1441f`. Targeted1/2 BASE2ba69933(full above)→TARGET28f7d027(full above),
/root/review_c3 no findings, ARCHITECTURE/STYLE PASS, runtime NOT_RUN.
Native RED43/46 `023119341`→GREEN46/1019 `023416051` CLEAN; schema34 golden generation15/838
`023448871`, reader15/839 `023523623` CLEAN; MCP/style/static/staged38+10 PASS.
Original schema33 native/cold proof remains in original checkpoint, not reused as schema34 acceptance.
Cold repair functional write+restore PASS, **overall gate FAIL/UNKNOWN** mixed shutdown:
`tests/artifacts/buyback-write-20261017-123608751.log`, `.artifacts/crafting-review-cold-restore.{stdout,stderr}.log`.
Verbose `.artifacts/crafting-review-cold-verbose.log`: retained151 GDScript/35 GDScriptNativeClass/4Resource,
no Nodes listed. Owner shutdown category DEFERRED; mixed PagedAllocator not waived. No standalone leak hunt.
Offline authoring `offlinescript-20261017-015511306` wrapper FAIL, successful native resave not a clean gate.

T1b BASE `370020fcf796c211eaf341940befc71ddd17b206` → TARGET `dcfbc440220c38560423d821e10370ff1227caf4`:
/root/review_c3 no findings, ARCHITECTURE/STYLE PASS, runtime NOT_RUN, repair0/2.
Native31/682 `012726127`, cold write112805993/restore112814113 PASS.
T1a BASE `927fd5ab7c321505f229be80b8797794680a4daa` → original `f13078ecf28d0af35480c8eba4306d140ecbaef5`:
RV-001 captured endpoints/World retirement and RV-002 historical unknown provenance FIXED
`370020fcf796c211eaf341940befc71ddd17b206`; RED25/28 `011729405`→GREEN28/602 `012047927` CLEAN.
Targeted1/2 BASEf13078ec(full above)→TARGET370020fc(full above), /root/review_c3 no findings,
ARCHITECTURE/STYLE PASS, runtime NOT_RUN. Cold112133372/112141492 PASS. Sold-ID spoof still rejected.
Historical full T1 schema32/contents/truck/golden/runtime proof retained in original checkpoint.

## Owner QA / blockers

Канон/баланс/полные каталоги/PhysicalHomes и B12 visual acceptance открыты. Raw chain требует
реального пути снабжения T4. Эффекты одежды/огнестрел исходно out-of-scope, не реализованы.
T2a cold mixed diagnostic gate открыт, не весь backlog BLOCKED. Windows/rendered T1/T2 NOT_RUN,
T1 **0/8**, T2a **0/8**; T3a/T3b выше. NPC exhausted budgets не возобновлять.
Последнее owner правило: внутри оставшегося разрешённого лимита повторный вопрос не нужен.
REVIEW_PENDING/NOT_RUN/OWNER_QA не выдавать за DONE.
