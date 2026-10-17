# Торговые роли — скупка, изготовление и отложенные заказы

Status: **IN_PROGRESS**
Technical: **IN_PROGRESS**
Execution order: **120**
Reference baseline: `d6ea70fe8a00071ee9a5b57aa4a7e647e108ea27`
Source: [полное исходное ТЗ и доказательства](references/task-refactor-2026-10-17/district_resident_barter_and_buyback.md.txt).

Эта карточка владеет текущим исполнением. Полный объём требований сохранён в Source;
правила чтения и автономного продолжения — в [README](README.md).


## Goal / acceptance

Семь торговых ролей и снабжение ПВЗ по полному Source/GDD. Дьявол: MORNING,
30–70%, запрет святого символа, по одной единице 1–2 выбранных типов за 150% после
грузовика. Скромник: сложные рецепты/точные совпадения, несколько изделий, первый
неудачный набор за кампанию как подарок/подсказка, дальнейший мусор и подаренное лишнее.
Все каталоги, время, реальные вещи/деньги, последствия чужого содержимого, независимый
терминал Ангела и отложенные результаты остаются требованиями, не сокращены этим резюме.

## Current

T1a — обратимый native prototype Дьявола npc/9: физический контейнер, действие у
реального NPC, native confirmation с отдельным новым нажатием после CHANGED, ordinary
30–70% и один premium unit/type/day по 150% BASE. Бросок/quote не продают вещи.
C_Buyback хранит дневной прайс/источники/остатки, C_Commerce — durable receipts,
R_BuybackReserved — краткий live резерв, WalletService — единственное начисление.
Факт ReceivingSupplyCompleted публикуется после последнего фактического arrival до конца
MORNING; demand выбирается из immutable ledger projection, не manifest/count/catalog.
Provenance живёт в C_InventoryItem и pending loot, сохраняется transfer/drop и receipt;
исторические actual/declaration/recipient не подменяются продажей. Неучтённая коробка
сохраняет package ID без выдуманного archive ID даже после поздней регистрации;
непустой historical archive ID обязан совпадать с arrival.
Встречные synchronous commerce/truck guards закрывают callback admission; live item reserve
блокирует pickup/inventory/truck. Snapshot/restore запрещены внутри транзакции.
Schema32: closed records, native prefab/profile preflight, actual source/price/once-payment,
premium cap и отказ до live mutation. Старый файл отклоняется, миграции нет.
Native container/panel/action/role assets созданы/сохранены через MCP. Companion resave
расширен только для двух точных fingerprinted NPC role providers, UID сохранены.
Это технический prototype: holy_artifact — явно временное сопоставление святого символа;
финальное размещение/канон, Карга и полное T1–T4 acceptance остаются открыты.

## Work packages

| Пакет | Проверяемый результат |
| --- | --- |
| T1 | Контейнерная скупка: фактический состав → подтверждение → revalidation → однократная оплата/выбытие; сохранённые дневные цены/спрос/лимиты. |
| T2 | Производство Скромника: полный набор, несколько изделий/приоритеты, первая льгота, подарок/мусор и результат следующим утром. |
| T3 | Публичные магазины и независимые отложенные заказы Ангела/Охотника/ПВЗ, штатные часы, кошелёк и единственная выдача. |
| T4 | Полное авторское наполнение семи ролей, реальные площадки и интеграционная матрица Source. |

Каждая сделка/заказ уже в своём пакете проходит restore/failure/retry. Не переносить
идемпотентность или защиту чужих заказов в отдельную «финальную» техническую задачу.

## Entry points / dependency gates

Начать с исследованных commerce/container/catalog/wallet/recipe/night owners в Source,
готовой CommercePanel, package contents и typed-персональных ролей.
[Жители R1/R2](district_authored_residents_and_resurrection.md) предоставляют stable trader ID;
[A01](pvz_a01_commerce_panel_scene_first.md) уже технически принят, его owner QA не блокирует T1.
[Закупки общества](npc_living_society/procurement_and_intermediaries.md) используют эти
транзакции/запасы, не создают конкурирующий публичный магазин и не меняют 30–70%/150%.
Торговля не ждёт завершения всей социальной симуляции или отложенного B01.

## Next

Получить targeted re-review T1a RV-001/RV-002 после repair cycle 1/2 по точным SHA.
До результата checkpoint REVIEW_PENDING; принятые дефекты исправлены и проверены ниже.
Затем T1b Карга (EVENING, только кости/артефакты, prototype явные цены) и полный T1
integration/QA. До T4 нельзя выдавать prototype цены, holy mapping или площадки за канон.
T2–T3 остаются обязательными пакетами, не заменяются универсальным магазином.
Независимое чтение Source §8 во время review: есть bones, blood_flask, work_clothes;
сырой цепи, одежды из цепей и мусора нет. spiked_chains — отдельное физическое оружие,
не допустимый alias сырой цепи. Нужны отдельные reversible prototype assets/recipe.
Полная колба требует actual condition/emitter проверки (C_HazardEmitter.fired), не только key.
Первый failed непустой набор — один раз за кампанию; successful leftovers как подарок
не расходуют льготу; exact remaining match идёт перед complexity/priority subset.
Это входы T2, реализации/канона ещё нет; девять физических домов отдельного provider PLANNED.


## Validation / review

T1a original review: BASE `927fd5ab7c321505f229be80b8797794680a4daa` →
TARGET `f13078ecf28d0af35480c8eba4306d140ecbaef5`, read-only reviewer /root/review_c3.
Main triage: оба P2 приняты; scoped repair cycle **1/2**, targeted re-review **REVIEW_PENDING**.
- RV-001 (R1) FIXED in repair commit: exact WeakRef reservation endpoints вместо повторного
  разрешения ID; завершение retirement в captured World при смене ECS.world; busy/incomplete
  receipt не DUPLICATE. Native callback replacement и World switch регрессии.
- RV-002 (R2) FIXED in repair commit: пустой history сохраняет unknown-at-extraction после
  позднего arrival; непустой history проверяется строго. Survivor + signed sale disk roundtrip.
RED before repair: `gut-20261017-011729405` — 25/28, только три новых случая FAIL.
GREEN repair: lifecycle28/602 `gut-20261017-012047927` PASS/CLEAN; cold write/restore
`tests/artifacts/buyback-write-20261017-112133372.log`, `buyback-restore-20261017-112141492.log`
PASS. MCP three exact paths CLEAN; formatter3, strict architecture, structure/persistence PASS.
Checkpoint не DONE, полный T1 и rendered acceptance ещё открыты.
Native GUT PASS/CLEAN (raw .artifacts/godot_agent/gut-20261017-*):
- buyback lifecycle25/529 `010517641`: actual extraction/provenance, wallet/disk restore,
  callbacks, death/actual return, 9 corruptions, native NPC action/confirm/cancel/focus,
  actual two-arrival BASE_SUPPLY, встречные truck/buyback callbacks.
- package contents29/356 `010046815`; MCP authoring8/80 `004716786`.
- schema32 golden generation15/818 `010125573`, normal read15/819 `010152103`.
- basic buyback7/46 `010824357`; truck cargo22/149 `010546580`;
  принятый R2 return/orders31/619 `010714476` на schema32 — PASS/CLEAN.
Cold two-process PASS: `tests/artifacts/buyback-write-20261017-105915099.log`, restore
`buyback-restore-20261017-105923219.log`: fresh prefab ID, saved seed/prices/limit,
foreign history, duplicate retry, следующая ordinary продажа. Slot isolated/удалён.
MCP fresh path diagnostics46/46 CLEAN; fallback reload43 сам по себе PASS не считался.
Formatter/lint46 files, strict architecture, structure, schema inventory и staged gate PASS.
Raw failed fixture/provenance trials сохранены; engine waiver не расширялся.

## Owner QA / blockers

Каталоги/цены/баланс не считать утверждёнными автоматически. Огнестрел и эффекты
экипировки остаются исходным out-of-scope, не новыми недоделками этой задачи.
Финальная авторская/визуальная приёмка открыта; технические T1–T3 разблокируют потребителей отдельно.

Rendered/playtest T1a **0/8**; проверять в оставшемся бюджете без повторного запроса
по указанию владельца. Windows QA build/ручная визуальная приёмка T1a NOT_RUN.
