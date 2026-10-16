# Посылки — соответствие содержимого, физических свойств и размера упаковки

Status: **IN_PROGRESS**
BASE_SHA: `ee8c23b2c3f4140ff2749fb7dcffa55c6c2c7100`
TARGET_SHA: `82e6ea5a6ad7b2ba91dbd98fef8c8ff104fb09b9`

Created: 2026-10-15. Основание: замечание владельца о **UID-1-TL08C**.
Related: [R27.5](completed/r27_test_lab_and_npc_rooms.md),
[R26.1](completed/r26_1_physical_items_and_effects.md).

## Task state

### Goal / acceptance

- Посылка с твёрдым артефактом не обозначается жидкой и не получает поведение жидкого груза.
- Признак «жидкая» следует реальному содержимому, а не случайно выбранному шаблону коробки.
- Большая упаковка предназначена для одного крупного предмета либо многих мелких в одной упаковке.
- Содержимое, количество, упаковка, история и игровые физические свойства согласованы.
- Ошибка устраняется в сформированном отправлении: подпись и UI не маскируют неверные gameplay-данные.

### Current

Выполнение авторизовано текущим `/goal` по `.agents/tasks`; прежняя пометка «ждать отдельную
команду» относилась к исходному планированию до этого goal. UID-1-TL08C — пример владельца;
его точная запись текущей игровой сессии пока не восстановлена.

Минимальная эквивалентная комбинация воспроизведена штатным native GUT: выбранный holy_artifact
при compilation bottles получает C_LiquidTilt и массу 30 кг, тогда как presentation убирает LIQUID.
M1 реализован: DEF_ItemCargo хранит фазу, unit mass/envelope, hazards и fragile; DEF_PackagePacking
хранит native варианты, внутренние габариты, padding ratio, лимиты количества/массы и явный порог
bulk/single-large. PackagePackingRules выбирает минимальную подходящую оболочку канонически,
проверяя поворот единицы, общий объём и массу; не меняет количество и не использует global RNG.
Packages читает inventory cargo по узкому read-контракту только для этого Rules. Текущие поставки и
сохранения ещё не изменены. До интеграции M2 исходный дефект не считается исправленным.
Новые immutable данные не являются вторым runtime authority. M1 review PASS; material findings
отсутствуют, triage завершён без требуемых исправлений. Общая задача остаётся IN_PROGRESS.

M2a завершён после verification/review: через native editor/MCP сохранены package_barrel/package_long и шесть .tres
профилей упаковки. Inner envelopes меньше реальных collision envelopes; сохранены унаследованный
package compiler, Box_C/Marks/Condition и исходные сцены. Native-проверка всех 16 catalog envelopes
подтверждает доступную упаковку для единичного груза, включая barrel/scythe, и toy ×8 → large.
Поставки ещё используют прежний путь; authored profiles будут подключены в M2b вместе с shipment
plan/quantity/cargo properties. M2a review PASS, material findings нет, triage завершён без
требуемых исправлений; исходный gameplay-дефект ещё не исправлен, общая задача IN_PROGRESS.

M2b завершён после verification/review: 16 native .tres cargo-профилей привязаны к immutable DEF_InventoryItem через
editor/MCP. Массы/габариты совпадают с native телами; rupture_hazard совпадает с их реальным
C_HazardEmitter, включая разные blood_spill у колбы и blood_pool у бочки. Максимальное количество
единиц — авторский cap перед выбором оболочки, не увеличение количества после выбора. Capacity
Rules проверяет этот cap. Все 224 прежних native свойства и 16 UID item definitions сохранены.
Receiving/история/codec ещё не подключены к новому cargo contract; исходный дефект пока не закрыт.
M2b review PASS, material findings нет, triage завершён без требуемых исправлений.
Вопрос обработки несовместимых schema19 задан владельцу; до решения
load/schema не меняются. Независимая подготовка и проверки cargo завершены.
## Установленная поверхность и гипотеза причины

- [ReceivingDeliveryService](../../content/domains/packages/services/receiving_delivery_service.gd)
  выбирает сцену коробки и selected_item разными решениями. Подобранный артефакт может оказаться
  в исходном рецепте bottles с LIQUID и чужими описанием, массой и опасностями.
- [ET_PackageState](../../content/domains/packages/authoring/et_package_state.gd) создаёт C_LiquidTilt
  по definition.tags; selected_item сам по себе этот рецепт не заменяет.
- [PackageHistoryService](../../content/domains/packages/services/package_history_service.gd)
  сохраняет ordered_item отдельно, но массу/класс опасности читает из DEF_Package; размер — из коллайдера.
  [PackageSceneRules](../../content/domains/packages/rules/package_scene_rules.gd) выбирает вариант
  без проверки совместимости с выбранным предметом и количеством.
- Это подтверждённое расхождение источников, но точная запись UID-1-TL08C не восстановлена.
  Сохранить пример как критерий воспроизведения, не объявлять его проверенным runtime-дефектом.
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
  Для старых несогласованных активных посылок явно определить миграцию рецепта/состояния; старую
  архивную историю не переписывать молча. Проверить совместимость закрытого save-codec и restore.
- Автоматическая регистрация — завершённая задача (`completed/package_automatic_arrival_registration.md`);
  здесь не менять момент назначения номера, назначения получателя и правила выдачи.

### Validation

- PASS baseline reproduction: GUT1/1,7 assertions, `gut-20261015-235404960`, stderr empty.
  Disposable fixture сохранён в `.artifacts/package_content_baseline_probe.gd`; это наблюдение
  прежнего дефекта, не регрессия правильного поведения. UID-1-TL08C не объявляется проверенным.
- Более ранние standalone probes имели compile/runtime errors и не являются PASS evidence.
- PASS M1: native GUT8/8,49 assertions, `gut-20261015-235704192`, stderr empty; один мелкий,
  реальная партия, один крупный, rotation/shape, gross mass/padding, phase/hazards, invalid/ties.
- PASS M1: MCP4 scripts checked/empty, scripts_instantiated=0; native ParseFiles4/0,
  `parsefiles-20261015-235651420`, exit0/stderr empty. Formatter4, role validator3 production,
  strict architecture0 lexical findings и project structure PASS.
- PASS M1 immutable-SHA review: `8364a7ed7450c4b5b0da7fafb66c36fc27ab0d6d` →
  `d331a86c89547c3bf23be2392adfdc0f31cfc301`; no material findings, architecture/style PASS;
  reviewer validation NOT_RUN, проверки выше выполнены Main.
- PASS независимый native замер 16 catalog bodies и 4 оболочек: GUT1/1,40 assertions,
  `gut-20261015-235844827`, stderr empty. Значения PHYSICAL_CATALOG в stdout, fixture
  `.artifacts/package_physical_inventory_probe.gd`. Не использует M1 Rules или новый data contract.
  Подтверждено: реальные бочки 0.8×1.0×0.8 м не помещаются в package_big с узкой осью 0.588 м;
  коса 0.94×1.64×0.13 м требует отдельной длинной native упаковки. Замеры обосновывают варианты M2a.
- PASS M2a native GUT4/4,119 assertions, `gut-20261016-000254104`, stderr empty; загружены
  шесть .tres, реальные .tscn и все 16 catalog bodies; новые scene UID различны, compiler valid.
  MCP1 checked/empty; native parser1/0, `parsefiles-20261016-000318383`, exit0/stderr empty.
  Formatter1, role validator2 native сцены, strict architecture0 и structure PASS.
- PASS M2a immutable-SHA review: `b2f406ca172228e7ca49b62aa646f17a906cd5a4` →
  `53a58f95e3dbff26f969e8100b3abb2047110fb7`; no material findings, architecture/style PASS,
  reviewer validation NOT_RUN. Изменение сцен выполнено в editor/MCP, а не raw rewrite.
- PASS M2b GUT14/14,360 assertions: packing_rules8/53 (`gut-20261016-001149130`),
  packing_assets4/187 (`001152518`), cargo_catalog2/120 (`001259114`), stderr empty.
- PASS M2b native preservation probe1/1,225 assertions (`001332620`), stderr empty;
  `.artifacts/cargo_authoring_preservation_probe.gd` сравнивает все прежние native properties
  с `.artifacts/cargo_native_baseline.json`. Отдельно 16 прежних resource UID сохранены.
- PASS M2b MCP6 checked/empty, scripts_instantiated=0; native parser6/0
  (`parsefiles-20261016-001436777`), formatter6, role3, strict architecture0 и structure PASS.
  M2b immutable-SHA review по BASE_SHA/TARGET_SHA PASS: no material findings, architecture/style
  PASS; reviewer validation NOT_RUN, native проверки выполнены Main.
- Rendered/visual QA NOT_RUN,0/8.

## План проверки будущей реализации

- Сначала воспроизвести пример владельца или минимальную эквивалентную комбинацию: артефакт,
  выбранный для исходного bottles. Сравнить UI/историю с C_LiquidTilt, тегами, массой и unpack.
- Параметризованные native/GUT: твёрдый артефакт не LIQUID, без наклонной утечки/чужого разлива;
  настоящие жидкости сохраняют свои эффекты. Масса/класс опасности соответствуют реальному грузу.
- Упаковка: один мелкий предмет, один крупный (бочка), партия мелких и неподходящая вместимость;
  физическая сцена и количество извлечённых предметов соответствуют согласованному плану.
- Реальные поставки нескольких дней и NPC-комнат: размер/теги/описание не зависят от старого
  шаблона, сохраняются предпочтения НПЦ и ровно согласованное число посылок.
- Повтор размещения/регистрация/save-load: нет повторного выбора, потерянных UID или номеров;
  старые сохранения и архивные записи обрабатываются по явно выбранной совместимой политике.
- Поверхность: test_package_order_rules, test_package_contents, test_entity_package_traits,
  test_package_history_id, test_receiving_limits, test_npc_test_rooms и профильные restore-тесты.
### Owner QA / blockers

- Owner QA: осмотреть/вскрыть артефакт, жидкость, бочку и партию мелких; сравнить фактическую
  коробку, маркировку и запись истории. Точные runtime/visual результаты пока **NOT_RUN**.

### Next

M2c: once-committed shipment plan/quantity до compiler, подключение
receiving/contents/physics/history/UI и явная save-совместимость после решения владельца о schema19.
При restore compiler сейчас запускается до saved overlay; construction
context должен получить выбранный plan заранее, а preflight — проверить его до мутации World.
В UI мигрировать также weight sort/detail терминала, stickers PackageConditionView, debug HUD и
hazard icons: они пока читают старые mass/tags/hazard hooks из DEF_Package. Компонент состава и
неизменяемая arrival projection должны быть единственными источниками новых физических фактов.
Затем профильные native регрессии и обязательный owner QA. До закрытия всех acceptance задача не DONE.
