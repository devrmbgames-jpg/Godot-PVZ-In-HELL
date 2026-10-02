# R24 — Двери, посылки, торговля и поведение клиентов

Status: **IN_PROGRESS**

## Task state

### Goal
Реализовать дополнения владельца от 2026-10-03 поверх текущего R23. Предыдущие требования остаются в очереди; этот документ создаётся до начала реализации новых пунктов.

### Constraints / acceptance

- Работать и фиксировать изменения только в dev; master — только чтение.
- Сохранять CharacterBody игрока, NavigationAgent NPC, физический grab и живые ownership/session Relationships. Не устанавливать и не менять addons.
- Каждый завершённый крупный этап сопровождать Windows-сборками основной и тестовой сцены в `.export/`.
- Игрок сам проходит полный срез. Ручные сценарии и ожидающая приёмка принадлежат `qa_tasks/`.
- Новые реализации опираются на существующие Health, unpack, inventory, commerce, anchoring, customer flow и игровые события.

### Milestones

- [x] M0: архивировать разросшуюся историю, оставить ссылки и правило дальнейшей ротации.
- [x] M1: разрушимые двери и тестовые наполненные посылки.
- [x] M2: мебель, зона выдачи, доставка и настраиваемый каталог торговца.
- [ ] M3: интервалы/уход клиентов, ограничения завершения смены, кабинки и осмотр посылок.
- [ ] M4: шаблон клиента, съедобные останки и вероятностный ценный дроп.
- [x] M5: виньетки, шаги, покачивание камеры, переключение debug HUD.
- [x] M6: типизированные события терминала, посылок и дверей.
- [ ] Узкие проверки изменённых контрактов, независимая проверка существенного результата, экспорт между крупными этапами; ручной QA передать игроку.

### Decisions

R23 продолжает текущую реализацию замечаний. Пересекающиеся новые требования уточняют старые: QA-04 допускает немедленную груду съедобного мяса для прототипа; QA-18 получает общую тестовую виньетку; QA-06 расширяется интервалами посетителей и минимумом таймаута ухода. Это не два независимых владельца одной механики.

### Current

M0 и M1 завершены. M3 интервалы/уход и M4 съедобные останки реализованы; кабинка/ограничения смены/шаблон клиента остаются в очереди. R23 QA03/04/05/06/09/10/13/14/15/17/18/19 реализованы. M5 завершён: Footstepper игрока/NPC, камера с малым покачиванием, совместимые виньетки ранения/голода/взгляда, debug_hud. M5 Windows main/test startup PASS; M6 события реальных действий игрока реализованы. Следующий шаг: R23 QA07/08 варианты общения клиентов. Каталог/доставка M2 и остальные прежние требования сохранены.

### Validation

M5: focused GUT3/3,23 assertions; один полный прогон на крупном milestone — GUT409/409,3185 assertions,44 scripts (`.export/m5-full-gut.log`). Read-only review: no material findings. Structure/diff PASS; formatter unavailable SKIP. Windows startup следует при экспорте. Исторические доказательства M1/M3/M4 ниже; ручной полный срез/звук/комфорт камеры ожидают игрока.

### Owner QA / blockers

Полный срез проверяет владелец. Игровых блокеров сейчас не установлено; ручной сценарий добавлять в `qa_tasks/` по мере готовности этапов.

## Требования

### История

- [x] Когда `task_history.md` превышает 12 КиБ, архивировать целиком в `task_history_archive/`, начать новый короткий файл со ссылкой на предыдущий архив. У архивов должна быть последовательная цепочка ссылок; сохранять фактические доказательства и существующие ссылки.

### Двери

- [x] Вариант двери с навесным замком: замок можно сломать, после чего дверь разблокируется.
- [x] Вариант двери с `C_Health`: саму дверь можно сломать; открытый проход больше не блокирует игрока/NPC.

### Посылки и мебель

- [x] Тестовая посылка распаковывается в небольшую полку **1,5 × 3 × 1,5 м**, две секции. Полку можно закрепить молотком.
- [x] Тестовая посылка выдаёт **пять аптечек**.
- [x] Тестовая посылка выдаёт **пять кусков хлеба**.
- [ ] Торговец продаёт большую тяжёлую полку **3 × 3 × 1,5 м**; игрок может закрепить её молотком.
- [ ] Купленная мебель появляется в специальной authored зоне возле торговца; игрок тащит её сам.
- [ ] Торговец предлагает платную доставку предметов на дом.
- [ ] Каталог и расписание торговца настраиваются ресурсами, допускают несколько разновидностей торговцев.

### Посетители и смена

- [x] Увеличить authored интервал между посетителями; не спавнить следующего сразу при удалении предыдущего.
- [x] Уходящий клиент остаётся до достижения конечной точки либо до истечения **более трёх минут**; убрать прежнее быстрое исчезновение.
- [ ] Настраиваемые ограничения окончания смены: пока в здании посетитель / пока не прошло заданное время / пока не пришли все запланированные посетители. Предусмотреть выбор/сочетание условий без отдельной сложной системы.
- [ ] После получения посылки клиент может пойти в одну из специальных зон — приватных кабинок, затем вернуться и решить, забирает её или отказывается.
- [ ] Некоторые клиенты с authored вероятностью распаковывают посылку при осмотре и забирают или отказываются от полученного предмета. Сохранять явную Relationship для владения посылкой/результатом; существующие опасные эффекты распаковки должны реально срабатывать.
- [ ] Подготовить копируемую сцену-прототип клиента с поведением и анимациями, настраиваемыми диалогами, интересами, параметрами и челленджами.

### Смерть и обратная связь

- [x] После смерти клиент оставляет доступные для осмотра/разрубания/еды останки. Для прототипа разрешена немедленная груда кусков мяса.
- [x] Останки съедобны и утоляют голод; с authored вероятностью выпадают ценные предметы, например аптечка.
- [x] Простая тестовая виньетка для ранений, голода и запрета смотреть на существо; эффекты совместимы и очищаются при прекращении причины.
- [x] Подключить персонажам footstepper из `res://addons/footstepper/`, чтобы слышались шаги. Подключать существующий addon, не менять его исходники.
- [x] Лёгкое покачивание камеры игрока с настройкой/отключением для проверки и reduced motion.
- [x] Команда консоли включает/выключает весь debug HUD, позволяя тестировать чистую игру и отладочный вариант.

### Игровые события

- [x] Игрок открыл/закрыл терминал.
- [x] Игрок взял/поставил посылку.
- [x] Игрок открыл/закрыл дверь.
- [x] События содержат игрока и конкретный объект, срабатывают один раз после фактического перехода и доступны будущему поведению NPC/скриммерам.

### M1 active implementation contract

Сначала двери: сохранять door_template и C_Openable authority; навесной замок — внутренний узел той же двери, HP на владельце; C_BreakableDoor выбирает PADLOCK/LEAF без второго Entity/session. Уничтожение замка разблокирует, дверь с Health освобождает проход. Использовать существующий damage pipeline; health/lock состояние сохранять через текущий snapshot boundary, не возвращать разрушенный authored объект после load. Добавить оба варианта в тестовую сцену с отдельными местами. Далее посылки с физическим содержимым.

M1 unpack contract: optional DEF_Package.unpack_scene and existing content_quantity; C_PackageContents.released is a saveable one-shot guard, separate optional component so old PackageState save schema remains unchanged. Opened lifecycle spawns individual floor-projected physical contents, inventory quantity1 each. Small18kg/large75kg shelves have open cavities and real panel colliders, C_Anchorable and current physical grab. Optional hazard_on_opened uses existing autonomous emitter.

### M1 validation

GUT58/58,469 assertions (7scripts), `.export/doors-contents-final-gut.log`: real knife/hammer windows, padlock cannot unlock before damage, leaf clears both colliders, tombstones intact/broken snapshot/Night; five individual food/med items, physical opening, inventory eating/healing, one-shot across repeated lifecycle/load, opened hazard dedup; small shelf real ground support, actual hammer fastening and anchored snapshot. Existing unfix test now waits its authored duration (QA06 extended default). Strict actual-primitive `doors_contents-20261003-063148543.log` PASS; separate read-only door/contents reviews found no material findings. Structure/diff PASS; formatter unavailable SKIP. Full-day/visual QA belongs to owner.

### QA04 / M4 edible remains milestone

Implemented immediate edible pile permitted by latest owner scope. Authored DEF_NpcRemains:3 physical meat/bone pickups,25 hunger relief each,25% extra medkit. C_NpcRemains.released persists independently; O_NpcRemains reacts to real lethal DamageResult, not restored C_Death. Visitor removal releases remains as normal unowned inventory entities; persistent Trader stays a hidden/frozen noncolliding tombstone, cannot trade, open panel closes/releases input. No extra live Entity ownership authority; existing R_OwnedBy handles pickup.

Validation: GUT40/40,332 assertions (4scripts), `.export/npc-remains-final-gut.log`; real damage/partial/repeated hits, chance0/1, pickup/food consumption, native collision/avoidance, open/dead trading UI, visitor death cleanup, saved death/remains/Night. Strict actual-main `npc_remains-20261003-064735213.log` PASS. Structure/diff PASS; formatter SKIP. Separate read-only review found no material findings. Next: publish Windows milestone, then QA03 inventory grid; client prototype and other M4 requirements remain pending.

### Active M5 prototype contract (recorded before implementation)

Player experience: sense walking and danger while retaining instant aiming, clear center view and agency. Pillars: readable feedback; unchanged native input/physics. Walking -> quiet Footstepper audio/at most1.2cm camera displacement -> grounded movement readable; hunger/wounds/gaze -> distinct edge tint -> eat/heal/look away.

Use existing read-only addon in fully manual mode for both native CharacterBody and rigid NPCs. Project-owned presentation reads actual grounded displacement plus locomotion intent; no steps/bob while stationary, airborne, dead, modal or transported. NPC sound is spatial3D; player2D. Tiny camera-local translation only, never HeadRoot/ray/arms or rotation; configurable/disableable, quickly returns neutral. Combine injury/hunger with existing gaze Canvas shader, leave center/UI clear and avoid new flashing. Expose authored amplitudes/cadence/volume/opacities. Owner playtest hypothesis: audible steps distinguish nearby moving NPCs, bob does not impair turns/aim, edge tint identifies cause.

Previous combined Windows803fbcd3 main/test startup PASS includes QA03/13/10. Full game/visual/audio acceptance remains owner QA. Small edits static; justified task-filtered checks only; full run reserved for major milestones.

### M5 implementation / validation

Project-owned CharacterFeedback reads actual grounded displacement plus movement intent. Existing addon uses fully manual footsteps, project adapter safely supports rigid NPCs without modifying addon. Player2D / NPC3D, no steps while idle/airborne/dead/modal/transported. Camera translation up to1.2cm, configurable reduced motion/disable, no body/head/ray/arms/rotation writes. Existing gaze shader combines amber hunger/red wounds/purple gaze edge feedback. Ordinary feedback survives debug_hud off.

Targeted3/3,23 assertions validates real audio voices, native rigid NPC adapter, camera-only movement and stop gates. Full suite once at M5:409/409,3185 assertions,44 scripts,33.281s. Separate read-only review clean; no rendered/audio playtest claimed. Owner checklist in qa_tasks/world_customers_commerce.md.

### Active M6 contract (recorded before implementation)

Reuse GECS World events with one typed PlayerInteractionEvent carrying six transition kinds, actor/object stable IDs and parcel ID. Subscribers query the affected object; only actors marked C_PlayerInputController generate player events. Terminal emits after visible/capture transition; parcel emits once after accepted grip and after real release (including transfer/throw, not a claim of floor contact), not failed/stale grip/teardown. Doors emit when native reported fraction reaches requested endpoint within authored/named tolerance, not at command acceptance or while blocked. Pending door attribution is transient R_OpenableRequestedBy, not an Entity pointer in Component. Cancel/supersede pending intent without replaying load state. No new System or parallel event bus. Justified focused transition tests only; no second broad run after M5.

Windows cfda84a0 character-feedback main/test exported, both actual-scene/120-frame startup PASS. Owner audio/visual acceptance pending.

### M6 implementation / validation

PlayerInteractionEvent.EVENT = player_interaction, six typed kinds; affected object is World event entity. Actor/object references plus stable IDs and package_id. Terminal reports committed visible/modal transitions; parcel pickup reports successful grip, placement reports actual release/transfer/throw, not floor contact. Failed/repeated actions, NPC, removal/death/invalid grip/Night cleanup do not publish player placement. Door endpoint tolerance2% uses physical fraction, transient R_OpenableRequestedBy is consumed before publication and canceled/superseded/reset at load/Night. Existing report_fraction callers remain compatible.

Focused GUT5/5,48 assertions (`.export/player-interaction-events-gut.log`). Independent review R5/P2 invalid-grip handle_input falsely notified placement: FIXED, equivalent cleanup now suppresses notification. Changed regression alone rerun1/1, additional assertions logged in `.export/player-interaction-events-review-fix.log`. No broad rerun/smoke. Structure/diff PASS. Owner full-slice acceptance pending; no screamer/behavior subscriber invented.

### Active M2 contract (recorded before implementation)

Optional DEF_TraderProfile owns authored catalog, first day/repeat days/open phases, paid home delivery fee and delay. Existing C_Trader.catalog remains fallback; different trader catalogs no longer require global terminal-order whitelist membership. Furniture is an appended inventory definition kind with world prefab path, maximum quantity1; it never becomes a weightless inventory grant. Large shelf is existing3x3x1.5m75kg anchorable prefab. Shop has authored FurniturePickup marker with nearby placement candidates; prepare floor-supported, collision-free detached physical entity before wallet commit, then register once under operation identity. Spawn as sibling, not under moving NPC. Blocked/unsupported zone must not charge; duplicate operation must not respawn.

Trader delivery pays item price+authored fee, uses appended receipt mode and existing persistent PendingDelivery/Morning OrderReceiving/home zone. Generic furniture placement extends that existing fulfillment owner, preserves static stack pickup path/old records. Blocked paid deliveries stay pending/retry; fulfilled identity guard prevents replay after load/consumption. UI shows store schedule, physical pickup vs inventory, delivery fee/day and blocked reason. No second commerce bus, live cross-Entity refs or addon changes. Relevant commerce/physical fulfillment/persistence tests at coherent completion; full run only if major milestone warrants it.

### M2 implementation / validation

DEF_TraderProfile owns independent catalog/day recurrence/open phases/courier fee and delay, legacy catalog fallback preserved. Large3x3x1.5m75kg shelf stays native physical/anchorable furniture, never inventory. Marker pickup tries free floor-supported volume before charging; stable operation identities prevent duplicates. Paid home courier reuses persisted pending deliveries/Morning receiving area; blocked deliveries retry without another payment. Panel scrolls offers and shows physical pickup, price+fee/day/schedule; overhead store label follows actual profile. Configuration: content/definitions/gameplay/commerce/README.md.

Targeted commerce12/12,128 assertions PASS. Independent review R6/P2 malformed prefab accepted before courier payment: FIXED by shared intrinsic furniture validation and required enabled pickup collider/C_InventoryItem; changed courier regression alone1/1,16 assertions PASS, rereview closed. Full suite once at this major commerce milestone426/426,3375 assertions,47 scripts (.export/m2-full-gut.log). Actual-main physical furniture pickup/home delivery smoke PASS (trader_furniture-20261003-082140977.log); smoke fixture parse cast corrected before successful run. Structure/diff PASS; no rendered/full-slice check. Owner checklist qa_tasks/world_customers_commerce.md; exports follow commit.
