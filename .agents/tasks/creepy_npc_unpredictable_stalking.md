# Жуткий — скрытное сближение и неожиданный испуг без поломки выдачи

Status: **IN_PROGRESS**
BASE_SHA: `af2fe86f0fefa1ad023a4acc03c06e5ad1ddea7a`
TARGET_SHA: M3a native authoring checkpoint pending commit/review

Created: 2026-10-15. Автор: запрос владельца. Related: [R26.2](completed/r26_2_npc_archetypes_and_variation.md), [R26.3](completed/r26_3_npc_behavior_trees.md), [R27.5](completed/r27_test_lab_and_npc_rooms.md).

## Task state

### Goal / acceptance

- При желании поговорить «Жуткий» быстро подкрадывается со спины, пока игрок его не видит.
- При приходе на выдачу возможен такой же близкий неожиданный контакт, совместимый с обслуживанием.
- Уточнение владельца2026-10-15: достижение близкой точки за спиной **считается сервисным прибытием**.
  Когда сортирующий коробки игрок оборачивается, НПЦ сообщает, например: «Посылка №3».
- Вне выдачи попытка возможна рядом с игроком, если нет срочного ухода, бегства или иной обязанности.
- Успешный испуг: НПЦ приблизился строго ближе **2.5 м**, после чего игрок увидел его.
  После этого новая попытка запрещена минимум **30 секунд**.
- При обнаружении НПЦ ведёт себя буднично; не замирает постоянно под взглядом, не кружит за спиной.
- Игрок может насторожиться и помешать попытке; точный момент и направление не должны читаться сразу.
- Очередь, разговор, назначенная посылка, выдача, тайм-ауты и обязательный уход сохраняют контракты.

### Current / authorization

Активный `/goal` разрешает реализацию задач; прежнее «только план» больше не действует.
M1 review PASS `673e57f0d51e0c1fa49c360307f78048a534cc25` (BASE `738767d150923d868c3090387f85609c2bbc1185`): no findings, architecture/style PASS, reviewer execution NOT_RUN, repair0/2. Closed schema25 owns sequence/decision/last-success/eligibility timestamps; unsupported24 rejects with original bytes retained. No migration.
M2 review PASS `6843e23e94c1ffb8f8d4784660f6783f09f67e22` (BASE `405ab8dac765f70dfd616c38e5937dbdd3cc1cfc`): no findings, architecture/style PASS, reviewer execution NOT_RUN, repair0/2. Free episodes implemented: sensed new-context/terminal-reading opportunity with TTL; one keyed choice/skip and captured delay/sector/extra cooldown; native BT exposes begin → wait → fixed hidden approach. R_NpcStalkingTarget owns the real player incarnation. World/reset/departure/death/role/combat/camera loss cancel only that episode; saved eligibility remains. Immediate actual visibility ends it, with neutral episode memory only at strict<2.5m and minimum30active seconds after success.
Expiry alone and reset/load do not create another desire; a new suitable sensed window is required. Routes have8s default budget, at most2 meaningful replans and a range leash. S_NpcIntent owns transient speed1.5x; physical body/max_speed authority remains. Old permanent-memory veto,0.5s exposure and stationary visible hold paths removed. Historical fixed memories still drive dialogue.
Prototype defaults remain unverified tuning; service rear approach/arrive/number announcement (M3), final save/service acceptance and authorized rendered QA remain open,0/8. Owner's unrelated empty BlackboardPlan metadata is preserved in the working tree and excluded from the behavior commit. The separate parcel QA approval remains pending.

M3a prepares the required editor-owned insertion into the nested service-arrival selector. Companion MCP now supports fingerprinted `insert_nested`, bounded direct task paths and exact child-order guards; it preserves the rest of the native graph/UID, rejects inspected/dirty/stale/recursive targets, and permits direct Customer task scripts. Live disposable insertion/save/UID preservation and offline cleanup completed; production service tree unchanged. Review pending; M3 runtime is still NOT_IMPLEMENTED.

## Current owners

- [NpcStalkingQueries](../../content/domains/npc/services/npc_stalking_queries.gd) observes role/phase/perception/real target/opportunity/clock gates; [Rules](../../content/domains/npc/rules/npc_stalking_rules.gd) owns pure distance/history arithmetic.
- [Witness](../../content/domains/npc/systems/s_npc_stalking_witness.gd) owns recurring real-camera sampling and bounded sensed desire; [Service](../../content/domains/npc/services/npc_stalking_service.gd) explicitly commits/consumes/releases one episode, with callback revalidation.
- [DEF_NpcStalking](../../content/domains/npc/definitions/def_npc_stalking.gd) holds immutable authored defaults; [native tree](../../content/domains/npc/ai/trees/bt_npc_stalking.tres) exposes eligibility and non-restarting begin/wait/approach sequence, below existing higher-priority branches.
- [Solver](../../content/domains/npc/solvers/npc_stalking_solver.gd) uses actual camera/frustum/LOS, bounded segment samples, native navigation and three rear sectors; intent/navigation/physics owners execute motion.
- [NpcDialogueService](../../content/domains/npc/services/npc_dialogue_service.gd) retains conversation authority; STALKING_NOTICED is historical dialogue data, not a permanent behavior ban.
- [NpcServiceRole](../../content/domains/customers/services/npc_service_role.gd) still owns queue/counter/service arrival. Active roles forbid free episodes; M3 must add a bounded SERVICE strategy without moving the free branch above service or duplicating arrive/handoff.

## Исследование и выводы для проекта

Valve описывает ограниченную вариативность времени/места и чередование пиков напряжения с отдыхом в [The AI Systems of Left 4 Dead, Mike Booth, слайды63,77–80](https://cdn.akamai.steamstatic.com/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf). Применение здесь: локальные эпизоды с пропусками возможностей и паузами; глобальный AI Director для одного социального НПЦ не требуется. Конкретные интервалы ниже — наше предложение.

Thomas Grip объясняет риск слишком понятных механических правил и чрезмерной случайности в [интервью о монстрах SOMA](https://www.gamedeveloper.com/design/the-tricky-design-problem-of-i-soma-i-s-memorable-monsters).
Он также описывает, как ожидания о реакции игроков не подтвердились в плейтестах. Применение:
стабильные ограничения и будничная маскировка намерения, разнообразные возможности; эффект страха
нельзя объявлять доказанным по одному алгоритму или автоматическим тестам.

В [разборе Alien: Isolation](https://frictionalgames.com/2014-10-thoughts-on-alien-isolation-and-horror-simulation/)
Grip подчёркивает окружение, звук и выводы игрока: использовать пространственные подсказки;
телепортация, обязательный скример, невидимость и принудительный разворот камеры не входят в задачу.

## Предлагаемое поведение

Ощущение: обычный неприятный посетитель иногда оказывается неожиданно близко, а после обнаружения
его намерение остаётся двусмысленным. Опоры: физически честное движение, неравномерный ритм,
сохранённая возможность игрока помешать и беспрепятственная работа выдачи.

| Этап | Действие и выход |
| --- | --- |
| Обычное поведение | Расписание/очередь/занятие; подкрадывание не является постоянной целью. |
| Интерес к разговору | Одно ограниченное социальное намерение; выбирается подходящая возможность. |
| Скрытое сближение | Выбран задний сектор и маршрут; быстрое обычное физическое движение. |
| Близкая позиция | Вне выдачи — короткое ожидание; при выдаче — обычное сервисное ожидание на месте. |
| Обнаружен | Немедленно прекратить скрытное сближение, перейти к будничному занятию/обслуживанию. |
| Пауза | После успеха минимум30 с; окончание паузы лишь разрешает новую возможность. |

### Выбор возможности и защита от «магнита»

- Вне обслуживания нужны желание поговорить, допустимая близость и реально воспринятый игрок.
  «Игрок рядом» создаёт возможность, а не безусловный приказ преследовать.
- Желание имеет срок жизни и потребляется/откладывается после попытки; не бросать вероятность каждый тик.
  Чтение терминала повышает привлекательность момента через существующий TerminalQueries.reading.
- Пропускать часть подходящих возможностей, разнообразить задержку и задний/боковой маршрут.
  Зафиксировать выбор один раз на эпизод через DecisionRandomRules и последовательность попыток.
- После обнаружения издалека — завершить эпизод и сделать отдельную короткую паузу перед оценкой.
  Поворот игрока обратно не должен немедленно возобновлять ту же попытку.
- Цель фиксируется на короткий интервал; не вращать её вокруг игрока каждый кадр.
  Перестраивать маршрут при существенном изменении ситуации, с лимитом частоты и числа пересчётов.
- У каждого эпизода есть предел длительности и удаления от своей зоны. Убегающего игрока бесконечно
  не догонять. Недостижимая/видимая/опасная цель возвращает НПЦ к его обычной обязанности.
- Под наблюдением продолжать правдоподобное занятие: смотреть на окружение, пройти к очереди,
  подождать в допустимой точке. Не подменять это постоянным hold, как у «Плачущего ангела».

### Скрытность, скорость и фиксация испуга

- «Игрок смотрит» — настоящая активная камера, её frustum и LOS до образцов тела, включая периферию.
  За стеной событие не срабатывает. Для целей ИИ использовать только доступное восприятие игрока.
- Пока путь скрыт, выбирать быстрый допустимый маршрут. Несколько задних точек оценивать по
  времени достижения, запасу до видимой области и безопасности, а не всегда по одному углу.
- Близкая цель учитывает радиусы обоих тел и зазор: без проталкивания игрока, пересечений и телепорта.
  Взгляд влияет на намерение до следующего физического шага; не ждать редкого фонового AI-такта.
- Успех фиксировать один раз, когда участник активной/только завершённой близкой попытки был вне обзора,
  вошёл в дистанцию <2.5 м и затем стал виден. Это технический критерий, не измерение эмоций игрока.
  Случайная встреча в очереди/обычный разговор не создаёт фальшивый успех.
- Дальний взгляд срывает попытку, но не считается близким испугом. Быстрый валидный взгляд вблизи
  учитывается; антидребезг не должен требовать прежние0.5 с непрерывного рассматривания.
- При успехе запретить новую попытку минимум30 с активного gameplay-времени; пауза меню не истекает
  за игрока. Добавочная задержка допустима. Повторные взгляды не создают новые события этого эпизода.
- После успеха обычное общение, получение посылки и уход разрешены сразу: cooldown запрещает испуг,
  а не всю деятельность НПЦ. Камера, управление игроком и открытие modal-диалога не захватываются.

### Интеграция с выдачей — обязательный контракт

- Не поднимать общую stalking-ветку выше SERVICE. Переиспользовать расчёт скрытого пути внутри
  ограниченной стратегии подхода сервисной ветки с владельцем намерения SERVICE.
- Допуск по can_approach и резерв через claim_counter остаются обязательными. Не обходить очередь;
  не уводить ожидающих позади других клиентов к игроку и не удерживать их обслуживание ради испуга.
- Разрешать близкую заднюю точку как альтернативное место обслуживания текущего «Жуткого»
  в рабочей зоне, с действующим допуском очереди, резервом и тайм-аутом. Одна попытка на посещение.
- Достижение такой точки переводит визит через штатный arrive в готовность к обслуживанию.
  Прибытие и объявление номера разделены: обычное приветствие не должно раскрыть его раньше поворота.
  После поворота игрока и действительного обнаружения НПЦ сообщает номер **своей назначенной**
  посылки существующим способом коммуникации: например, «Посылка №3». Не начинать реплику за кадром,
  не захватывать камеру/modal и не повторять её каждый кадр. Незарегистрированный номер не выдумывать.
- [Общий автоприём](automatic_parcel_handover_and_wrong_recipient_reactions.md) действует и у этого контакта:
  коробка из рук <1 м, прежние проверки назначения/результата, без F и возврата к стационарной стойке.
  Контакт фиксируется на время обслуживания; бесконечно таскать NPC за спиной игрока запрещено.
  Это режим существующей сервисной роли/связи, а не второй владелец визита или разрешение выдавать удалённо.
- При удалении игрока, потере допустимого контакта или невозможности пройти — обычная стойка
  либо штатное завершение по существующим правилам, без дублирования arrive/приветствия/выдачи.
- При срыве попытки до допустимого прибытия, истечении бюджета или отсутствии пути — обычная стойка.
  Не сбрасывать elapsed/сроки, не создавать повторный визит, не менять назначение коробки или номер.
- Во время передачи, принятого диалога, проверки, оплаты, осмотра и ухода подкрадывание запрещено.
  Сервисный контакт за спиной — явно разрешённое расширение текущих условий прибытия/выдачи;
  остальные проверки и единственный владелец сервисного состояния сохраняются.
- Срочное бегство/опасность, бой, смерть, активный разговор и обязательный уход выше попытки.
  Прерывание освобождает только свой токен движения; не отменяет чужую ветку, роль или резерв.

## Начальные настройки прототипа — требуют проверки

| Параметр | Предложение |
| --- | --- |
| Зона интереса вне обслуживания | Начать с существующих8 м и бонуса терминала4 м; гистерезис выхода. |
| Близкая цель | Примерно0.9–1.4 м между центрами, с обязательным физическим зазором. |
| Ускорение скрытого подхода | Масштаб1.3–1.8 от обычного шага; сброс при выходе из ветки. |
| Предел свободной попытки | 6–10 с; не более2 существенных перепланирований за эпизод. |
| Сервисный обход | Не более4–6 с; запас времени на альтернативное прибытие или возврат к стойке. |
| Близкое ожидание | Свободная попытка1–2 с; при выдаче — обычные сроки ожидания клиента. |
| Пауза после успеха | Минимум30 с + выбранная однажды добавка0–30 с; не запуск по таймеру. |
| Пауза после дальнего обнаружения | Ориентир8–15 с, без повторного захода сразу после отвода взгляда. |

## Владение состоянием и поверхность будущих изменений

- DEF_NpcStalking/.tres хранит настройки; существующий нативный BT выбирает намерение.
  Witness/выделенный System владеет наблюдаемостью и регулярным временем, Service — фиксацией событий.
  Solver считает кандидаты/пути, NpcIntentArbiter и текущие владельцы маршрута/физики исполняют движение.
- Краткоживущая попытка/токены остаются в C_NpcStalking; долговечные next_eligible/номер эпизода принадлежат одному typed-состоянию в NPC aggregate. Живая цель — Relationship/существующее связывание, не сохранённая ссылка на Node. Не заводить параллельные таймеры в BT и Service.
- STALKING_NOTICED сохранить как исторический факт для диалога и старых сохранений, убрать его
  роль вечного запрета. Новые события имеют идентичность эпизода; старый фиксированный incident_id
  не должен поглощать все будущие испуги. Не удалять старую память для «сброса» поведения.
- Загрузка не обнуляет оставшийся cooldown и не перебрасывает выбранную задержку; маршрут/экспозиция
  пересоздаются безопасно. Для новых durable-полей явно определить совместимость закрытого save-codec.
- Смена сцены, смерть, потеря цели/восприятия, pause, brain reset и смена participation очищают
  только временную попытку. Не снимать cooldown обычным reset; тестовая комната по своему контракту
  создаёт нового NPC при полном повторном входе.
- Основные владельцы: перечисленные stalking-файлы, C_NpcStalking, S_NpcStalkingWitness,
  NpcRecord/save-boundary, bt_npc_stalking, bt_npc_service и узкие сервисные approach/arrive leaves.
  Native сцены/деревья и ресурсы редактировать по editor-ownership; сторонние addons не менять.

### Validation
- M1 native GUT71/71,1925 assertions/stderr0/PASS: rules8/54 (`074357096`), baseline13/748 (`074400372`), stalking14/111 (`073531451`), creepy_dialogue36/1012 (`074441039`); prefix `gut-20261016-` in `.artifacts/godot_agent/`. Native ParseFiles5/0/PASS (`20261016-074546279`); heavy baseline isolated parser1/0/exit0 (`creepy_m1_isolated_parser.{stdout,stderr}.log`), shutdown-only retention KNOWN_ENGINE_LIMITATION/DEFERRED; combined6 wrapper had FAIL only warning classification (`20261016-073708383`). MCP6 checked/empty/scripts0; formatter6/strict architecture0/structure/persistence inventory/agent changes PASS. Rendered0/8. Home fixture fix `738767d150923d868c3090387f85609c2bbc1185` reviewed PASS; see parcel QA card.
- M2 native GUT93/93,2237 assertions/PASS: stalking27/245 (`082042439`), district_snapshot16/205 (`082121026`), creepy_dialogue36/1012 (`082153700`), baseline13/748 (`082242320`), all stderr0; active retained/fresh binary restore1/27/exit0 (`creepy_m2_active_disk.stdout.log`). Native ParseFiles16/0/PASS (`20261016-082737973`); other3 heavy fixtures compiled/executed by GUT. MCP19 unique scripts checked/empty/scripts0; formatter19/strict architecture0/structure/persistence inventory PASS. Native BT saved through MCP with UID preserved. Delay token/publication cleanup/opportunity-expiry red probes retained; final fixes PASS. Terminal fixture46 orphan observation resolved by settled teardown in `14c2294cfb1f35c71d3c03711c21479270e2d42e`, reviewed PASS; native27/245 now has no orphan report. Independent [scope](completed/terminal_package_row_orphans.md) records55-cycle WeakRef evidence; no shutdown-only exemption. Rendered0/8; M2 review terminal PASS.

- M3a native companion GUT11/11,96 assertions/PASS (`gut-20261016-085036312`); ParseFiles3/0/PASS (`parsefiles-20261016-085114490`), stderr0. MCP3 checked/empty/scripts0; live native create/nested insert/read UID PASS (`.artifacts/godot_agent/mcp_nested_insert_probe.json`), registry revision6 and positive dispatch confirmed. Initial stale-schema refusal returned TRANSPORT_OUTCOME_UNKNOWN without production mutation; script reload refreshed registration. MCP disposable removal refused discovery>10000, unchanged; clean editor quit/exact offline deletion/guarded restart completed. Incremental formatter3/strict architecture0/structure PASS; rendered0/8. Immutable review pending.

## План проверки будущей реализации

- GUT: наблюдение/окклюзия/край FOV, разворот камеры во время шага, недоступный путь и движущийся игрок.
- Граница2.5 м:2.49 считается;2.5 и больше — нет. Один эпизод → одно событие. Дальний взгляд — срыв.
- Пауза: до30 с повтор запрещён; после30 с без новой возможности не стартует. Pause/загрузка/reset
  не обходят запрет, старый STALKING_NOTICED не выключает механику навсегда.
- Вариативность проверять фиксированными seed/эпизодами: одинаковый seed повторяем, разные возможности
  допускают пропуск, выбор сторон/задержек; нет нового броска на каждом тике и кругового прилипания.
- Реальная выдача с несколькими клиентами: очередь, резерв, первая/повторная посылка, настоящий arrive,
  прибытие за спиной, реплика номера только после обнаружения, передача на месте без возврата к стойке,
  отход игрока/блокировка/тайм-аут пути, осмотр/оплата/уход без дублей; чужая коробка не принимается.
- Обновить [test_npc_stalking](../../tests/gut/test_npc_stalking.gd), включая прежние тесты постоянного
  запрета и запрета при сервисной роли; сохранить их гарантии прерывания и добавить сервисную стратегию.
  Покрыть test_district_service, test_district_service_queue, сохранения и тестовую creepy-комнату.
### Owner QA / blockers

- Owner QA: несколько встреч при работе у терминала, переносе коробок, движении и намеренных
  разворотах. Проверить неожиданность, будничную реакцию, возможность заметить заранее и отсутствие
  помех выдаче. Автотесты не доказывают субъективный испуг; rendered QA только с разрешения владельца.

### Next

Collect M3a immutable review/triage before using its authoring operation. Then M3b implements bounded rear SERVICE approach, ordinary arrival, visibility-gated own-number announcement, and real handoff/queue/timeout/save integration. M2 gates/review are complete; no findings. Preserve task IN_PROGRESS until full runtime/service/save acceptance and authorized QA.
M3b owner map: Customer role state and live player Relationship belong to Customers; shared personal sequence/cooldown/notice history stays NpcRecord via the explicit stalking service. The native rear subtree inserts at service tree task_path [1,1,3,1], before standard approach strategies, after normal can_approach/claim_counter. Use a fixed contact destination and bounded4-6s route; preserve phase-clock ownership and normal fallback. Customer greeting currently announces before actual camera observation, so rear arrival must suppress greeting/number until seen. Preserve inspection return to the reached contact. Required once-per-appearance choice should survive reset/save; any new durable field requires a version bump and old-file rejection/preservation. Relevant fixtures: test_npc_stalking, test_district_service/queue, creepy_dialogue and native persistence baseline. No service runtime/schema edits made by M3a.
Gameplay QA requires task-specific authorization and remains open; parcel-handover QA permission is separately pending. Do not mark this task DONE before runtime/service/save acceptance and required owner QA.
