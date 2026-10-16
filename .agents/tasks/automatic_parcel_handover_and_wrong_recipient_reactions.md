# Выдача посылок — автоматический захват и реакции на чужой заказ

Status: **IN_PROGRESS**
BASE_SHA: `f7cbd1e6cca18f9dd52f58b7697fcb87b43bb02c`
TARGET_SHA: `91d5e63a06baf7d0987e6532c3b041f83cfd24c2` - occupied-hands LOS review PASS; task IN_PROGRESS

Created: 2026-10-15. Related: [согласованность посылок](completed/package_contents_and_packaging_consistency.md), [Жуткий](creepy_npc_unpredictable_stalking.md), [Скромник](shy_npc_gaze_discomfort_and_wall_order.md).

## Task state
### Goal / acceptance

- Готовый к обслуживанию НПЦ сам пытается взять коробку со стола выдачи; нажатие F не требуется.
- НПЦ забирает предложенную коробку из рук при расстоянии строго **<1 м**, без прицеливания в него.
- Верный заказ проходит обычную выдачу/осмотр/оплату; чужой вызывает реакцию по таблице ниже.
- Бугай: сначала25% присвоить; если не присвоил —50% бросить в игрока, иначе обычный отказ.
- Цепной дьявол:50% бросить чужую коробку в игрока, иначе отказаться.
- Бугай благодарит за присвоенную посылку; игрок может запугать его ради возврата с риском атаки.
- Вампир/Бугай/Цепной дьявол отбрасывают чужую посылку со святым символом в сторону.
- Огненный элементаль:25% сжечь подходящую чужую посылку либо15% повредить коробку.
- После распознавания чужой коробки без присвоения — блок повторного захвата **180 секунд**.
- Нет повторного броска вероятности каждый тик, повторных выхватываний и двойного зачёта выдачи.

### Current / authorization

Активный `/goal` авторизует выполнение задач; прежнее «только планирование» предшествует ему.
M1a/b reviewed: общий CustomerParcelOffer рук/стола, строгий<1 м/LOS, опора, READY прежде WRONG, tie-break, резерв и повторный gate до _resolve_delivery.
M2a review PASS `81043b87741609aaf9d05368e047a838aab2cfd6`: item holy/fire metadata,16 .tres/22 prefab agreement; reviewer validation NOT_RUN, repair0/2. M2b reviewed: DEF_NpcParcelReaction CAPABILITY у4 архетипов, чистый chooser с переданными rolls; architecture/style PASS, validation NOT_RUN, repair0/2.
M2c1 carry reviewed, RV-002/003 fixed; fresh C_GrabControl/C_CarryLoad/C_Strength, Strength6/offset0.35 м, existing R_HeldBy/solver/cleanup; architecture/style PASS, reviewer validation NOT_RUN.
M2c2 fire reviewed: actual remaining item metadata, one-shot consumption/mass before debris, native hazard retained without repeat from empty shells; catalog quantity/history/schema22 unchanged. Unknown legacy stubs remain unknown. No material findings; architecture/style PASS, reviewer validation NOT_RUN, repair0/2.
M2d runtime reviewed: common wrong-offer commit, native KEEP/throw/fire, GameClock pair180s block, closed incident codec/schema23 and held reconstruction. RV-004/005 fixed in `fd0dda76885715ec13d1a27a96c70c631f5394b1`; targeted architecture/style PASS, reviewer execution NOT_RUN, repair1/2. Intimidation remains open.
M2e1 review PASS `905db54ec1cd99c60dbf58eca0f568634a984668` (BASE `d6ac88d3aca65756d651af5aff96149802fbc6ea`): pure single-roll chooser and closed captured outcome/Strength/roll/tick, schema24/native golden; completed history and pending RETURN/ATTACK preserve data without replay. No findings; architecture/style PASS, reviewer validation NOT_RUN, repair0/2. Independent lifecycle regressions review PASS `411598f5a71f9c2b756ca0f2256c3ac2bf328d49`: disable/remove thief preserves physical parcel, closes pair once, no false order settlement; no findings, architecture/style PASS, reviewer validation NOT_RUN, repair0/2.
M2e2 runtime `6ded6ad04670e07f653f5ceea6f798343aeae8cb` reviewed; RV-006 fixed/targeted review PASS in BASE above, architecture/style PASS, reviewer execution NOT_RUN, repair1/2. Native demand/committed attack/physical return and unchanged phase clocks/schema24 are implemented. M2e3 scoped occupied-hands LOS parity: confirmed own held body blocked demand despite native targeting exclusion; reach now excludes own hand/Carry bodies while placement retains them as obstacles. M2e3 review PASS in TARGET above: no findings, architecture/style PASS, reviewer execution NOT_RUN, repair0/2; visual0/8.
Holy precedence/абсолютные огненные исходы — выбранные авторские defaults с Inspector overrides; отдельного подтверждения владельца по двум пересечениям не было.
M2f integration implemented without runtime changes: returned theft reaches only the rightful recipient/payment; actual destruction releases the thief before its typed fact, preserves registration/history, and leaves LOST manual. Explicit LOST closes the unstarted rightful order; complaint replay adds no second charge. Review pending for this test checkpoint; task IN_PROGRESS.
RV-002 [P1] FIXED(`6c7e9778124c63bb5432e02a0bcdf88dde203016`, targeted re-review PASS): source `68832a6ba5543fdc1a8eb4f0541bf2a291b5d78f`, persisted NPC Strength needs schema22; updated native golden/manifest, schema21 rejected with unchanged bytes.
RV-003 [P2] FIXED(`6c7e9778124c63bb5432e02a0bcdf88dde203016`, targeted re-review PASS): same source, authored Strength0 conflicts with save preflight; positive export/validation, invalid-value regression and fresh/reused Strength0.1 round-trip.
RV-001 [P2] FIXED(`f7cc855c9e18149b2f2ebbd597c44b24f737feab`, handoff14/124): source `9cc2bf517589a1d3f682adbe75a6b83e163eb094` разыменовывал customer до gate. Targeted re-review architecture/style PASS, reviewer validation NOT_RUN; RV-002/003 fixed; visual NOT_RUN,0/8.
RV-004 [P1] FIXED(`fd0dda76885715ec13d1a27a96c70c631f5394b1`, targeted review PASS): source `308b32ee913b73d4b73d50f44166619984e0892f`, release callbacks invalidated reach/LOS/WRONG/identity before NPC grip. Shared post-release gate preserves package/body/visit identity and automatic policy; real move-away/reassignment regressions pass.
RV-005 [P2] FIXED(same fix SHA as RV-004, targeted review PASS): same source, MANUAL FIRE outlived synchronous guard. Capture rejects pending/executing buffers; Night certifies its drained enclosing batch, restore cancels obsolete queues. Adapter matches pinned GECS `14d4282e5c1cb2713c187706ba2f5ff4e315d36e`; MANUAL DAMAGE/BURN/executing-callback regressions pass.
RV-006 [P1] FIXED(`f7cbd1e6cca18f9dd52f58b7697fcb87b43bb02c`, targeted review PASS): source `6ded6ad04670e07f653f5ceea6f798343aeae8cb`, same-NPC callback preserved grip but left journal COMPLETED, blocking claim/fresh reconstruction. Captured World/flow/journal/Component/raw IDs gate HELD reconciliation; different owner untouched. Actual callback, later no-reroll claim and retained/fresh disk ownership regressions pass.
Владелец подтвердил: Бугай сначала25% присвоить, затем50% бросить при неприсвоении; запугивание5 процентных пунктов за Strength; блок персонален для пары.

## Единый контур автоматического предложения

- Один scheduled владелец выявляет кандидатов со стола/из рук и подаёт typed-запрос. BT выбирает
  допустимость намерения; синхронный Service атомарно решает предложение. Не создавать второй
  независимый маршрут зачёта рядом с ручной выдачей, осмотром или существующим автоприёмом.
- Допускается только живой готовый участник текущего сервисного контакта/домашней встречи;
  прохожие без роли не вырывают складские коробки. Очередь, резерв и специальный контакт Жуткого
  сохраняются. Один стол обслуживает текущего разрешённого получателя, а не всех стоящих рядом.
- Стол: коробка внутри DeliveryArea и действительно оставлена на поверхности, без живого хвата.
  Один лишь пролёт брошенной коробки через Area не означает предложение. F не нужен;
  старый совместимый вызов, если сохранён, использует ту же операцию и те же блокировки.
- Из рук: только реальные CARRY/RIGHT_HAND/LEFT_HAND игрока; не инвентарь/тележка/чужие руки.
  Предложение — близость коробки к доступной точке захвата NPC и физически свободная линия к ней,
  а не расстояние между центрами персонажей или попадание прицелом в лицо.
- Предлагаемый точный метрический контракт: расстояние от авторской точки захвата NPC до ближайшей
  физической поверхности коробки <1 м, с LOS/запретом захвата сквозь стену. Проверить на больших коробках.
- Сначала доступная собственная коробка; если её нет — одна чужая. При нескольких кандидатах
  стабильный порядок/близость; один НПЦ не обрабатывает всю стопку в одном тике.
- Пакет в руках не считается одновременно лежащим на столе. На время операции он резервируется;
  два NPC/источника не могут одновременно выбрать и освободить один и тот же хват.
- Pause/консоль/modal, смерть, уход, бой, осмотр, потеря роли/цели и завершённый визит отменяют
  незафиксированную попытку. Подтверждение повторно проверяет lifetime, дистанцию и текущего держателя.

## Чужая коробка: порядок решения

Сначала валидность/доступность, затем принадлежность. Правильный заказ не проходит таблицу чужих.
Далее особый случай святого символа, затем последовательность решений по профилю, затем отказ.
Native default holy_rejection_first=true даёт приоритет святому над броском/присвоением; авторский override явный.

| NPC / содержимое чужой коробки | Порядок решения и итоговые исходы |
| --- | --- |
| Большинство NPC | Отказ «Это не моя посылка»; коробка остаётся у игрока/на столе. |
| Вампир, Бугай, Цепной дьявол + святой символ | Отбросить в сторону; не присваивать и не целиться в игрока. |
| Бугай без святого символа | Сначала25% присвоить; иначе50% бросить, иначе отказ. Итоги:25%/37.5%/37.5%. |
| Цепной дьявол без святого символа | 50% бросок в игрока;50% обычный отказ. |
| Вампир без святого символа | Обычный отказ. |
| Элементаль + разрушаемое огнём содержимое | 25% сжечь;15% повредить коробку;60% обычный отказ. |
| Элементаль + иное содержимое | 15% повредить коробку;85% обычный отказ. |

- У Бугая первая проверка25%; вторая50% выполняется только после неприсвоения:0.75*0.5=37.5%
  броска и37.5% отказа. Каждый результат фиксируется один раз; это не прежние50/25/25%.
  Для Элементаля native default — абсолютные25%/15%/60%; damage_after_not_burned=false, без второго броска.
- Признаки содержимого читаются из фактического manifest/количества/typed-свойств предметов,
  не из имени, текста описания или устаревшего bottles-рецепта. Святой символ определяется
  реальной holy-возможностью содержимого, а не классом «любой артефакт».
- Для огня добавить авторское свойство «разрушается огнём»: кислота, кровь, одежда, игрушка, еда,
  аптечка и другие подходящие предметы согласно требованию владельца. Новые предметы участвуют
  через данные; не закреплять конечный список item ID в алгоритме NPC.
- Предлагаемая модель знает состав предлагаемых посылок для этих особых реакций; не заставлять
  всех NPC автоматически вскрывать коробку ради распознавания и не раскрывать состав в UI игрока.

## Физическая реакция и учёт

- Обычный отказ может произойти без вырывания коробки. Для броска/присвоения сначала атомарно
  снять реальный хват игрока через владельца, затем оформить хват NPC или единственный бросок.
  Нельзя оставлять две R_HeldBy, фантомный слот игрока или коробку, всё ещё движущуюся за его руками.
- Проверить/авторовать штатные возможности и физические точки хвата NPC: присвоенная коробка
  реально удерживается/переносится, не скрывается как будто успешно выданная и удалённая из мира.
- Бросок в игрока — настоящий импульс/скорость с атрибуцией NPC, направлением на зафиксированную
  позицию цели и возможностью промаха/преграды. Отбрасывание святого — свободное боковое направление.
  Урон игроку/коробке возникает через существующие физические impact/damage owners.
- При отбрасывании коробка может повредиться от столкновения; не подменять это безусловной потерей HP.
  Не телепортировать коробку обратно в руки или в недостижимое место.
- Сожжение фиксирует реальное уничтожение/повреждение посылки и соответствующего содержимого
  через штатный lifecycle. Не только визуальное пламя/удаление Node: история и фактический исход
  сохраняются. Нельзя после сожжения выдать из этой же коробки неповреждённое сожжённое содержимое.
- При15% повреждения величина урона — отдельный авторский параметр; вероятность15% не означает15 HP.
  Опасности жидкости и её реальные эффекты остаются у профильных владельцев.
- Присвоение не меняет назначенного получателя/номер и не начисляет оплату за чужой заказ.
  Физическое владение Бугая фиксируется отдельно от законного назначения; реплика «Спасибо за подарок».
- Его собственный заказ не считается выданным чужой коробкой. У настоящего адресата сохраняется
  правильный исход: коробку ещё можно вернуть. При окончательной утрате/уходе вора — явное
  событие потери по действующим правилам, без вечного зависания ожидания/ночи и без дубля посылки.

## Запугивание Бугая после присвоения

- Доступно требование «Эй, это не твоя посылка, а ну верни» для живого инцидента присвоения, а не любого NPC
  с любой коробкой. Возможность сохраняется, пока эта коробка удерживается/может быть возвращена;
  определить ограниченное окно ухода, не блокирующее обслуживание бесконечно.
- Подтверждённое масштабирование в процентных пунктах, S — текущая эффективная Strength игрока:
  `P_attack = clamp(50 - 5*S, 5, 95) / 100`,
  `P_return = clamp(50 + 5*S, 5, 95) / 100 = 1 - P_attack`.
  Примеры: S=0 =>50/50; S=5 =>25/75; S>=9 =>5/95.
- Это один выбор «атака либо возврат», без двух независимых бросков. Strength и случайный результат
  фиксируются при принятии запугивания; повторное нажатие/загрузка не дают перебросить тот же инцидент.
- При возврате снять хват NPC и безопасно вернуть игроку; если его руки заняты — положить в
  доступное место/на стол, без изменения результата на атаку при неудаче размещения.
- При атаке задействуется обычный боевой контракт; коробка остаётся реальным объектом в мире/хвате,
  не исчезает и не помечается возвращённой. Запугивание повторно не становится бесплатным reroll.
- Возвращённую коробку заблокировать от повторного автозахвата этим NPC, иначе он сразу украдёт её снова.

## Блокировка180 секунд и повторные попытки

- Подтверждено владельцем: блок по стабильной паре **npc_id + package_id**, для стола и рук.
  Настоящий получатель может забрать коробку сразу; игрок может свободно убрать, носить и сортировать её.
  Это не freeze физического тела, не запрет общего взаимодействия и не180 с блокировки склада.
- Установить блок сразу при зафиксированном распознавании чужого заказа без присвоения, до реплики,
  броска или повреждения: возвращение отскочившей коробки в радиус не вызывает реакцию вторично.
- Отказ, бросок в игрока/в сторону и повреждение подпадают под правило. При уничтожении сохраняется
  терминальный инцидент; при присвоении повторный захват исключён фактическим владением.
- До истечения срока нет повторных выхватываний, реплик и новых проверок вероятности. Новый вход
  в радиус, перекладывание на стол и ручной вызов совместимой операции блок не обходят.
- Срок идёт в активном gameplay-времени; pause его не расходует. После180 с новая допустимая
  попытка может создать новый инцидент. Это предлагаемая временная семантика, не wall-clock таймер.
- Выбранная реакция/sequence и next_eligible фиксируются одним владельцем typed-состояния предложений.
  Сохранения/brain reset/роль не дают сбросить активный блок или повторить уже выбранную реакцию.
  Новая личность NPC не наследует блок по одному имени/instance_id. Очистка записей ограничена lifecycle.

## Контракты владения и смежные планы

- Scheduled System владеет регулярной проверкой; Services — атомарным предложением/реакцией;
  Component/aggregate — данными эпизода/блока; Relationships — реальным хватом/живыми связями.
  Не делать Service.tick и не переносить подсчёт исходов в Area callback или визуальную анимацию.
- Отдельный стабильный incident_id и единственный commit защищают ledger, деньги, жалобы, броски
  и разрушение от повторов. В physics/deferred callback повторно проверяется актуальность роли/Entity.
- Native Area/точки/стол/слоты — .tscn, профили/метаданные — typed .tres; без display_name checks, новые save-поля требуют совместимости codec.
- План согласованности посылок обеспечивает корректные holy/fire/состав/размер. Автоматическое
  назначение номера при поступлении — другая задача; этот план не меняет регистрацию получателя.
- Общая автоматическая выдача применяется к альтернативному контакту Жуткого и визиту Скромника;
  их локальные планы ссылаются на этот единый контракт, без собственного дубля выдачи.

### Validation
- M2f native incidents44/44,513 assertions, stderr0/PASS (`gut-20261016-072137887`); native ParseFiles1/0/PASS (`20261016-072224723`), MCP1 checked/empty; incremental formatter/strict architecture0/structure/agent changes PASS. Existing receipt/manual-loss15/154 remains PASS (`gut-20261016-065659875`); visual0/8.
- M1b GUT106/106,815 assertions, stderr0: counter13/89 (`032611400`), handoff13/118 (`032352514`), inspection12/163 (`032430965`), service17/103 (`032506237`), queue51/342 (`032537132`); prefix `gut-20261016-` in `.artifacts/godot_agent/`.
- Native ParseChanged9/0 (`20261016-033337292`), MCP9 checked/empty/scripts0; formatter9/role9/strict architecture0/structure/persistence inventory PASS. Новая вывеска стойки сохранена editor/MCP.
- M2a GUT14/14,302 assertions, stderr0: capabilities4/69 (`034803629`), cargo_catalog3/129 (`034836853`), receiver_effect7/104 (`034855192`); prefix `gut-20261016-`.
- M2a native ParseChanged2/0 (`20261016-034913378`), MCP2 checked/empty/scripts0 после guarded restart; formatter2/role2/strict architecture0/structure/persistence inventory PASS. Gameplay/visual NOT_RUN,0/8.
- Native authoring `offlinescript-20261016-034709262`:16 saves/exit0, no compile errors; wrapper FAIL only shutdown retention KNOWN_ENGINE_LIMITATION/DEFERRED. Первоначальный ранний ECS compile error исправлен отложенной загрузкой ресурсов.
- M2b GUT19/19,1387 assertions, stderr0: reaction_rules9/93 (`035837828`), archetype_catalog4/934 (`035927943`), variation6/360 (`035958958`); native ParseChanged3/0 (`20261016-040031502`), MCP3 checked/empty/scripts0; formatter3/role3 PASS.
- M2b native/MCP создал4 typed .tres и добавил их4 архетипам с сохранением UID; strict architecture0/structure/persistence inventory PASS. Только выбор, не runtime reaction acceptance; visual0/8.
- M2c1 GUT78/78,877 assertions, stderr0: holder6/41 (`041452327`), handoff14/124 (`041543725`), counter13/89 (`041656538`), world_snapshot45/623 (`041739066`); native ParseChanged2/0 (`20261016-041849211`), MCP2 checked/empty, formatter2/strict architecture0/structure/persistence PASS. Native3 scenes saved via MCP; visual0/8. Repairs: holder7/48 (`042516967`), live_roster10/899 (`042537376`), MCP4 checked/empty; schema22 golden5/365 (`042654370`) native exit0, wrapper FAIL only deferred shutdown retention. Repair native ParseChanged4/0 (`20261016-042749699`), formatter4/strict architecture0/structure/persistence/staged PASS.
- M2c2 GUT44/44,510 assertions, stderr0: contents29/356 (`043453283`), receipts_loss15/154 (`043356625`); native ParseChanged6/0 (`20261016-043535910`), MCP6 checked/empty/scripts0, formatter6/strict architecture0/structure/persistence PASS; visual0/8. First new-fixture failures corrected (non-orderable food/legacy stub), final native PASS.
- M2d GUT183/183,1424 assertions/stderr0: incidents23/190 (`050630752`), counter14/94 (`050201833`), grab92/438 (`050434418`), world_snapshot45/623 (`050712862`), package_traits9/79 (`051018663`); golden7/428 (`050024721`) native exit0, wrapper FAIL only shutdown retention. Prefix `gut-20261016-`.
- M2d native ParseFiles15/0/exit0 (`20261016-051107199`) and isolated golden parser1/0; wrappers FAIL only known shutdown retention (full ParseChanged20 reports artificial1 failure, `050821609`), KNOWN_ENGINE_LIMITATION/DEFERRED. MCP20 checked/empty/scripts0; formatter20/strict architecture0/structure/persistence PASS; native game_world Observer saved via MCP, visual0/8.
- M2d repair: GUT74/74,876 assertions/stderr0: snapshot47/642 (`gut-20261016-053116726`), incidents27/234 including MANUAL BURN (`gut-20261016-053256656`). Native ParseFiles7/0/exit0 (`parsefiles-20261016-053211174`), wrapper FAIL only known shutdown retention/DEFERRED; MCP7 checked/empty/scripts0, formatter7/strict architecture0/structure/persistence PASS.
- M2e2/RV-006 + M2e3 native GUT53/53,1111 assertions/stderr0: incidents42/446 (`gut-20261016-071039423`), golden11/665 (`gut-20261016-070131925`), actual callback then retained/fresh disk restore. Own-Carry blocker reproduction failed before LOS repair (`gut-20261016-070951493`); final nativeParse2/0PASS (`20261016-071130014`), MCP2 checked/empty, formatter2/strict architecture0/structure PASS. RV-006 nativeParse2/0PASS (`20261016-070427338`), MCP3 checked/empty; original full parser6/0 (`20261016-065302636`). Native authoring marker PASS/exit0 (`offlinescript-20261016-064119540`), wrapper FAIL known shutdown retention/DEFERRED. Visual0/8.
- M2e1: native GUT48/48,982 assertions: rules11/133 (`gut-20261016-062037952`), golden10/615 (`gut-20261016-062243056`), incidents27/234 (`gut-20261016-062335169`). Golden native exit0, wrapper FAIL only shutdown retention/KNOWN_ENGINE_LIMITATION/DEFERRED; others stderr0/PASS. Schema23 startup rejection preserves file bytes/World. MCP6 checked/empty/scripts0; formatter6/strict architecture0/structure/persistence PASS. Native ParseFiles5/0/PASS (`20261016-062507621`); full6 wrapper FAIL isolated golden1, child parser1/0/PASS (`20261016-062406332`), known shutdown retention/DEFERRED. Visual0/8.
- Lifecycle regression: incidents29/29,255 assertions/stderr0 (`gut-20261016-062740857`), native ParseFiles1/0/PASS (`20261016-062814288`), MCP1 checked/empty; formatter1/strict architecture0/structure PASS. Production unchanged; visual0/8.
- RV-001: focused handoff14/14,124 assertions, stderr0 (`gut-20261016-033859456`); native ParseChanged2/0 (`20261016-033946776`), MCP2 checked/empty, formatter2/role2/strict architecture0/structure PASS.
- delivery_completion native write/restore PASS/PASS, exit0/0: `.artifacts/godot_agent/delivery_completion-m1b-{write,restore}.{stdout,stderr}.log`. Fixture проверяет arrival number/отдельный LOST и физическое поднесение. Wrapper FAIL: неизвестный phase marker и shutdown-only retention (KNOWN_ENGINE_LIMITATION/DEFERRED), не runtime PASS обёртки.
- Одна коробка одновременно в Area и руках, два NPC и deferred устаревший запрос: ровно один commit,
  нет потерянного хвата/двойного получения. Pause/modal/смерть/уход/осмотр не дают фонового захвата.
- Все строки таблицы, приоритет holy, порядок25%→50% и итоги25/37.5/37.5% Бугая, фиксированные seed;
  нет roll на тиках/перезаходе до конца блока. Проверки границ вероятностей вместо flaky Monte Carlo.
- Инцидент присвоения/запугивание: формулы на S=0/1/5/9 и границах clamp, возврат при занятых руках,
  отсутствие reroll/повторной атаки/платежа, потеря/восстановление реального чужого заказа.
- Броски/огонь: правильная атрибуция NPC, реальная повреждаемость/разрушение, количество содержимого,
  история/жалобы и отсутствие фантомной успешной выдачи чужому адресату.
- Блок179.9/180 с, смена источника руки/стол, другой правильный получатель, save-load/reset,
  возврат после запугивания; правило не мешает игроку немедленно убрать коробку.
- Регрессии: test_customer_handoff, district service/queue, package receipts/loss, contents,
  NPC fire/pride, delivery completion, новые typed-reaction/cooldown проверки и save/restore.
### Owner QA / blockers

- Owner QA: плавно положить/поднести посылку, убрать отвергнутую, пережить бросок, вернуть украденную;
  отсутствие спама, ощущения непроизвольного захвата у прохожих и необходимости целиться в NPC.
  Субъективная удобность/физика требуют отдельного разрешённого gameplay QA; сейчас **NOT_RUN**.

### Next
Collect immutable-SHA M2f test review, then prepare runnable QA build and separately authorized NPC gameplay checks. [QA card](../../.qa/tasks/automatic_parcel_handover_and_wrong_recipient_reactions.md) has8 NOT_RUN cases; cargo QA6/6 PASS/task archived; NPC visual0/8; task IN_PROGRESS.
