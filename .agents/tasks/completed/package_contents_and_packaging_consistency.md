# Посылки — соответствие содержимого, физических свойств и размера упаковки

Status: **DONE**
BASE_SHA: `5694fab2edd8d1fb5976acd7b85ac9c06f5002fd`
TARGET_SHA: `594639d706c47edeffda8d9ff5b82e353fbd54b5` — review PASS, cargo QA6/6 PASS

Created: 2026-10-15. Основание: замечание владельца о **UID-1-TL08C**.
Related: [R27.5](r27_test_lab_and_npc_rooms.md), [R26.1](r26_1_physical_items_and_effects.md).

## Task state

### Goal / acceptance

- Посылка с твёрдым артефактом не обозначается жидкой и не получает поведение жидкого груза.
- Признак «жидкая» следует реальному содержимому, а не случайно выбранному шаблону коробки.
- Большая упаковка предназначена для одного крупного предмета либо многих мелких в одной упаковке.
- Содержимое, количество, упаковка, история и игровые физические свойства согласованы.
- Ошибка устраняется в сформированном отправлении: подпись и UI не маскируют неверные gameplay-данные.

### Current

Cargo QA6/6 PASS (authorized six named cases; no NPC visual acceptance). QA-001/P2 FIXED: title visibility `865db6c21469e9b4475a54c1fd5e89f701018247`, height180 BASE above. QA-002/P2 FIXED in TARGET: Visual-only blood offset+0.03m, verified visible above floor with unchanged collision sphere. All three checkpoints reviewed architecture/style PASS, reviewer execution NOT_RUN. Main GUT24/24,656 assertions/stderr0: terminal7/28 (`054013512`), cargo5/101 (`054748440`), physical_payloads12/527 (`055548519`); strict architecture/structure/agent/staged PASS. Opening counts1/1/1/1/8/1, repeat0, no empty-shell hazards; full/empty slot restore and old-schema rejection/bytes+World preservation PASS. Evidence `.artifacts/cargo-qa-fd0dda76/observations.json`; isolated QA slots only.

Выполнение авторизовано текущим `/goal` по `.agents/tasks`; прежняя пометка «ждать отдельную
команду» относилась к исходному планированию до этого goal. UID-1-TL08C — пример владельца;
его точная запись текущей игровой сессии пока не восстановлена.

M1/M2a/M2b завершены после независимых review/triage: typed cargo/capacity Rules, шесть native
packing .tres, сцены barrel/long и cargo references всех 16 catalog items. Уникальные SHA и native
evidence сохранены ниже; item UID и 224 прежних свойства сохранены. Финальная приёмка6/6 завершена.

M2c завершён: RV-001/P1 FIXED; cargo phase определяет C_LiquidTilt, rupture однократно расходует
payload через released. Passive restore получает selected_item до compilation; evidence ниже.

M2d.1 завершён после review: detached PackageShipmentPlan выбирает qty/packing/variant/full mass.
Explicit quantity не изменяется; RNG purpose/canonical ordering обеспечивают retry.

M2d.2 завершён после fix/re-review: RV-002/RV-003 FIXED, новых material findings нет.
ReceivingBatch фиксирует quantity/packing paths до создания тела; C_PackageContents владеет составом.
Compiler и saved preflight проверяют quantity/capacity/exact scene; fresh/reused restore не reroll.
Native Trait allowlist и недостающий clothing cargo комнаты shy обновлены через editor/MCP.
Schema21/PVZH1: решение владельца 2026-10-16 — «Отклонять старую схему, файл сохранять».
M2d.3 завершён после review: arrival projection фиксирует количество/packing; PackageCargoRules дают
массу/теги/hazards для history ID, terminal detail/sort/icons, stickers и debug HUD.
Preflight проверяет capacity/live agreement/ID mass и hazard, в том числе без физического тела.
Native/static проверки, immutable review и разрешённая cargo QA завершены; доказательства ниже.
## Установленная поверхность и гипотеза причины

- [ReceivingDeliveryService](../../../content/domains/packages/services/receiving_delivery_service.gd)
  в baseline выбирал коробку и selected_item независимо. M2d.2 теперь подбирает сцену по грузу;
  arrival projection сохраняет фактические item/quantity/packing.
- [ET_PackageState](../../../content/domains/packages/authoring/et_package_state.gd) теперь создаёт
  жидкостную capability по фактическому selected cargo; прежний shell tag больше её не определяет.
- [PackageHistoryService](../../../content/domains/packages/services/package_history_service.gd)
  формирует новый ID из actual full mass/hazard и native bounds; прежние ID не переписывает.
- Baseline class regression confirmed by native artifact-over-legacy-liquid tests. Historical UID-1-TL08C file was not recovered or migrated; unsupported schemas are rejected/preserved by the owner's decision, verified again in runtime QA. Acceptance covers newly committed supported-schema composition, not a retroactive old-file correction.
- Не путать признак LIQUID с буквами диагностического ID: по текущему PackageHistoryId
  T — токсичный класс, следующая L — большой размер. Сам этот фрагмент не доказывает жидкое содержимое.

## Планируемый контракт содержимого и упаковки

- Сначала выбрать заказанный предмет и фактическое количество. Затем определить совместимые
  свойства груза и подходящую авторскую упаковку; только затем создавать тело/компоненты и историю.
  Не выбирать случайную «жидкую коробку» независимо от её наполнения.
- Покупательская категория, агрегатное состояние, опасность и габариты — разные сведения.
  REAGENT не означает автоматически жидкость; тяжёлый предмет не означает автоматически большой.
  Для текущего каталога сочетание «артефакт + жидкая посылка» запрещено по требованию владельца.
- Определить typed-описание физических свойств содержимого: жидкость/твёрдое, масса единицы,
  требования к объёму/габаритам и реальные опасности. Использовать авторские данные/возможности,
  а не имена предметов, строки описания или список исключений по item ID.
- LIQUID, наклон/утечка и эффекты разлива допустимы лишь при реальном жидком содержимом.
  Артефакту нельзя оставить поведение bottles только из-за происхождения упаковочного шаблона.
  При этом собственные опасности настоящей кислоты/крови/огненной жидкости сохраняются.
- Размер упаковки следует одному крупному предмету либо реальному набору мелких: учитываются
  количество и вместимость/габариты. Большую коробку нельзя обосновать одним обычным мелким предметом.
  Одна крупная бочка допустима в подходящей большой упаковке; партия мелких должна действительно
  извлекаться в заявленном количестве. Не увеличивать количество задним числом ради внешнего вида.
- Подготовить совместимые native упаковочные профили и typed-правила вместимости/размера.
  Для первого этапа достаточно ограниченных авторских классов; сложный универсальный 3D-packing
  не является целью. Порог «много мелких» задаётся данными конкретного профиля и проверяется тестами.
- Масса тела, признаки переноски/повреждения, история, терминал, сканирование и текст запроса читают
  один согласованный план отправления. Масса полной коробки учитывает содержимое и упаковку;
  после вскрытия применяется контракт пустой оболочки. Архив сохраняет факты поступления.
- План состава фиксируется однажды, до компиляции способностей и записи поступления. Повтор
  размещения, сканирование и загрузка не перебрасывают содержимое, количество и тип упаковки.
- Не мутировать общие DEF_Package/DEF_InventoryItem; authored .tscn/.tres остаются редактируемыми.
  Сохранять ссылки на определения и поддерживаемые typed-поля manifest, без ресурсов с несохраняемыми
  случайными runtime-путями и без генерации сцен/скриптов во время игры.
- Не переприсваивать существующие UID/package_id, номер выдачи или получателя для исправления свойств.
  Schema19 отклонять, файл сохранять по решению владельца; архивную историю не переписывать.
  Проверить совместимость текущего закрытого save-codec и restore.
- Автоматическая регистрация — завершённая задача (`completed/package_automatic_arrival_registration.md`);
  здесь не менять момент назначения номера, назначения получателя и правила выдачи.

### Validation

- PASS baseline reproduction: GUT1/1,7 assertions, `gut-20261015-235404960`, stderr empty.
  Disposable fixture сохранён в `.artifacts/package_content_baseline_probe.gd`; это наблюдение
  прежнего дефекта, не регрессия правильного поведения. UID-1-TL08C не объявляется проверенным.
- PASS M1 native GUT8/8,49 assertions (`gut-20261015-235704192`), stderr empty: quantity/capacity,
  rotation/mass/phase/ties. MCP4 checked/empty; ParseFiles4/0 (`parsefiles-20261015-235651420`),
  formatter4, role3, strict architecture0/structure PASS.
- PASS M1 immutable-SHA review: `8364a7ed7450c4b5b0da7fafb66c36fc27ab0d6d` →
  `d331a86c89547c3bf23be2392adfdc0f31cfc301`; no material findings, architecture/style PASS;
  reviewer validation NOT_RUN, проверки выше выполнены Main.
- PASS независимый native замер16 items/4 shells: GUT1/1,40 assertions (`gut-20261015-235844827`),
  `.artifacts/package_physical_inventory_probe.gd`, PHYSICAL_CATALOG stdout. Бочки0.8×1×0.8 м
  шире package_big0.588 м; коса0.94×1.64×0.13 м требует long; M1 Rules не используются.
- PASS M2a native GUT4/4,119 assertions, `gut-20261016-000254104`, stderr empty; загружены
  шесть .tres, реальные .tscn и все 16 catalog bodies; новые scene UID различны, compiler valid.
  MCP1 checked/empty; native parser1/0, `parsefiles-20261016-000318383`, exit0/stderr empty.
  Formatter1, role validator2 native сцены, strict architecture0 и structure PASS.
- PASS M2a immutable-SHA review: `b2f406ca172228e7ca49b62aa646f17a906cd5a4` →
  `53a58f95e3dbff26f969e8100b3abb2047110fb7`; no material findings, architecture/style PASS,
  reviewer validation NOT_RUN. Изменение сцен выполнено в editor/MCP, а не raw rewrite.
- PASS M2b GUT14/14,360 assertions: packing_rules8/53 (`gut-20261016-001149130`),
  packing_assets4/187 (`001152518`), cargo_catalog2/120 (`001259114`), stderr empty.
- PASS M2b native preservation1/1,225 assertions (`001332620`), stderr empty: fixture
  `.artifacts/cargo_authoring_preservation_probe.gd` сверил cargo_native_baseline.json;16 UID intact.
- PASS M2b MCP6 checked/empty, scripts_instantiated=0; native parser6/0
  (`parsefiles-20261016-001436777`), formatter6, role3, strict architecture0 и structure PASS.
  M2b immutable-SHA review `ee8c23b2c3f4140ff2749fb7dcffa55c6c2c7100` →
  `82e6ea5a6ad7b2ba91dbd98fef8c8ff104fb09b9` PASS: no material findings, architecture/style PASS;
  reviewer validation NOT_RUN, native проверки выполнены Main.
M2c checks:
- PASS GUT84/84,1124 assertions: entity_package_traits8/70 (`gut-20261016-002823692`),
  package_contents20/280 (`004655871`), world_snapshot41/520 (`004330104`),
  package_order_rules7/201 (`002636252`), package_packing_rules8/53 (`002702683`); stderr empty.
- PASS MCP15 checked/empty, scripts_instantiated=0; ParseChanged15/0 (`002941078`), final
  S_LiquidTilt ParseFiles1/0 (`003248017`). Formatter15, role12, strict architecture0,
  project structure и persistence baseline PASS. Saved fields/schema не менялись.
- PASS headless main-level receiving_scan, `tests/artifacts/receiving_scan-20261016-104548265.log`,
  exit0/explicit PASS/no errors. Регистрация, сканер, терминал и второе утро сохранены.
- Первичный review `5bc785f40485f99cd1c1d0a7e7335dd254e71f11` →
  `ca0e1409eaca761988f8913cb242953baac36a4e` нашёл RV-001/P1; это не PASS milestone.
- PASS RV-001 fix: contents20/20,280 assertions (`gut-20261016-004655871`), snapshot41/41,520
  assertions (`004330104`); native parser8/0 (`parsechanged-20261016-004531866`), MCP8 checked/empty,
  formatter8/role6/strict architecture0/structure/persistence baseline PASS. Schema19 fields intact.
- PASS targeted re-review `ca0e1409eaca761988f8913cb242953baac36a4e` →
  `f893cb3395dd3b86572009c58f55a558424e31cb`: RV-001 FIXED, no material findings,
  architecture/style PASS, reviewer validation NOT_RUN; repair/re-review1/2 завершён.

M2d.1 checks:
- PASS GUT7/7,141 assertions (`gut-20261016-010014338`), stderr empty: actual quantities/mass,
  barrel/scythe, incompatible counts, capacity gaps, retry/order/global RNG, invalid inputs.
- PASS MCP3 checked/empty, scripts_instantiated=0; native ParseChanged3/0 (`20261016-010018806`),
  formatter3, role2, strict architecture0 и structure. Native materialization здесь не запускается.
- PASS immutable-SHA review `1562b58a6df0dbb00e8d6d3f1a742de425c89d28` →
  `cc696412a8cf43ca4c88028719ce60cb42e15521`: no material findings, architecture/style PASS,
  reviewer validation NOT_RUN. Triage: новых кандидатов нет. Visual QA на том checkpoint NOT_RUN; финальная6/6 выше.

M2d.2 validation: GUT149/149,4234 assertions across11 focused files; targeted review PASS.
- entity_traits9/79 (`011602662`), contents21/305 (`014029406`), snapshot44/598 (`013924781`),
  receiving_limits22/161 (`011405337`), truck16/118 (`012632796`), roster10/846 (`011647070`),
  shipment7/141 (`011920650`), save_data6/40 (`011924899`), cargo3/129 (`012205035`),
  rooms6/1452 (`012512928`), golden baseline5/365 (`011627642`); prefix `gut-20261016-`.
- Golden assertions PASS/exit0, wrapper FAIL only at shutdown; likewise native parser13/0/exit0
  (`parsefiles-20261016-011902053`) wrapper FAIL after Resource/RID retention at shutdown.
  Logs retained: KNOWN_ENGINE_LIMITATION / DEFERRED per owner policy, no runtime errors/orphans.
- MCP22 checked/empty, final4 after reload; formatter22/role13/architecture0/structure/baseline PASS.
- Headless receiving_scan PASS (`tests/artifacts/receiving_scan-20261016-111822092.log`); visual0/8.
- Fix native65/65,903 assertions; ParseChanged5/0 (`014043013`), MCP5/formatter5/role4/static PASS.

M2d.3 native:112/112,1629 assertions; prefix `gut-20261016-`:
- presentation5/101 (`020025477`), snapshot45/623 (`020140814`), terminal7/28 (`020215492`),
  debug3/22 (`020221914`), history2/14 (`020231243`), packing8/53 (`020234505`),
  contents21/305 (`020237783`), truck16/118 (`020250112`), golden5/365 (`020259375`).
- Golden assertions PASS/exit0; wrapper FAIL only on shutdown Resource/RID retention.
  Smoke explicit receiving→scan→terminal→next-day PASS; wrapper FAIL only shutdown Resource:
  `tests/artifacts/receiving_scan-20261016-120352319.log`. KNOWN_ENGINE_LIMITATION / DEFERRED.
- Native ParseChanged18/0 (`20261016-020327332`), MCP15 checked/empty, scripts_instantiated0;
  formatter18/role16/strict architecture0/structure/persistence baseline PASS. Visual0/8.

### Review triage

M2d.3 `58b3e2a7fc7cdad7cabb774161aa6654a7e96463` → `b0bee51b3a9c7c6dbacd59de1a304554f42a99a7`: no material findings, architecture/style PASS; reviewer validation
NOT_RUN. Main triage: новых кандидатов/открытых принятых P0/P1/P2 нет; repair0/2. Owner QA на том checkpoint NOT_RUN; финальная6/6 выше.
M2d.2 primary review: `21748810dbdbe0fb18e2a4f94a6a5e6b478abe59` → `2c4ac66dac66ae32db12f66914413ce7f2eb2df9`.
- RV-001 — **FIXED**, P1 source `ca0e1409eaca761988f8913cb242953baac36a4e`:
  native baseline2 FAIL/20 (`gut-20261016-003927943`): повторный rupture damage→destroy/leak→open.
  consume_catalog_rupture фиксирует released/empty mass до callbacks; intact opening сохраняется.
  Fix `f893cb3395dd3b86572009c58f55a558424e31cb`, native61/61/800 assertions/re-review PASS.
- RV-002 — **FIXED**, P1 source `2c4ac66dac66ae32db12f66914413ce7f2eb2df9`:
  SnapshotGraphRules.valid_entities/STORED использовал legacy30kg вместо actual4kg в слоте max8kg.
  Fix `4f2048eb19b76015072654cd4630f2c1098a0ada`: saved full/empty mass через PackageShipmentRules.
- RV-003 — **FIXED**, P1 same source: WorldSnapshotService.can_restore не сверял retained scene.
  Тот же fix: preflight отвергает large-saved/small-live для одного ID до любых изменений.
  Native baseline3 FAIL/44 (`gut-20261016-013751617`), fix44/44 (`013924781`).
  Re-review `2c4ac66dac66ae32db12f66914413ce7f2eb2df9` → fix: оба FIXED, no material findings;
  reviewer validation NOT_RUN. Repair/re-review1/2 завершён.

### Owner QA / blockers

- Owner-authorized cargo QA6/6 PASS: [карточка](../../../.qa/tasks/package_contents_and_packaging_consistency.md), native fixtures/real owners, rendered1920×1080. No further visual cases; NPC feel/visual remains outside this task's acceptance.
- Windows QA `20261016-060031Z-594639d7-cargo_acceptance`: export/menu120/level120 PASS, dirty=true from preserved preexisting edits; `.export/LATEST.cmd`. Rendered acceptance used live MCP source, exported binary player QA remains NOT_RUN as stated in build_info. Earlier export evidence stays in Git/artifacts; Editor gracefully closed before current export.

### Next

Задача завершена и архивирована после всех6 разрешённых cargo случаев, review/triage и актуального Windows QA export. Продолжать выдачу/реакции и запугивание в отдельной owning task; здесь открытых принятых P0/P1/P2 и pending review нет.
