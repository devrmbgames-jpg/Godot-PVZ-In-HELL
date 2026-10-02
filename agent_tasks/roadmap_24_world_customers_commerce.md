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
- [ ] M2: мебель, зона выдачи, доставка и настраиваемый каталог торговца.
- [ ] M3: интервалы/уход клиентов, ограничения завершения смены, кабинки и осмотр посылок.
- [ ] M4: шаблон клиента, съедобные останки и вероятностный ценный дроп.
- [ ] M5: виньетки, шаги, покачивание камеры, переключение debug HUD.
- [ ] M6: типизированные события терминала, посылок и дверей.
- [ ] Узкие проверки изменённых контрактов, независимая проверка существенного результата, экспорт между крупными этапами; ручной QA передать игроку.

### Decisions

R23 продолжает текущую реализацию замечаний. Пересекающиеся новые требования уточняют старые: QA-04 допускает немедленную груду съедобного мяса для прототипа; QA-18 получает общую тестовую виньетку; QA-06 расширяется интервалами посетителей и минимумом таймаута ухода. Это не два независимых владельца одной механики.

### Current

Новые требования записаны, M0 выполнен: история 16 336 байт сохранена целиком в архив №1, текущий файл короткий и содержит ссылку. R23 QA-18/19/05 завершены по реализации и узкой проверке. QA-06 и интервалы/уход M3 реализованы: пауза30с после физического удаления, endpoint либо минимум181с. M1 двери/посылки завершён; большая75кг полка подготовлена для M2. M1 Windows main/test91e00d6c exported, actual-scene/120-frame startup PASS. Active next milestone QA-04/M4: immediate edible meat, optional valuable loot. Observe actual lethal DamageResult rather than restored C_Death; preserve persistent Trader tombstone and one-shot guard. Затем остальная очередь. Также выполнен пункт debug HUD: `debug_hud on/off/toggle`; остальные дополнения ещё не реализованы.

### Validation

M0: сохранение прежнего содержимого целиком; запись требований. M3 интервалы/уход: GUT195/195,1207 assertions (11 scripts); final UI/timing9/9,52; strict actual-main gaze/darkness smokes PASS. ReviewR4 FIXED/rereviewed. Structure/diff PASS; formatter SKIP. Остальные дополнения не проверены.

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
- [ ] Простая тестовая виньетка для ранений, голода и запрета смотреть на существо; эффекты совместимы и очищаются при прекращении причины.
- [ ] Подключить персонажам footstepper из `res://addons/footstepper/`, чтобы слышались шаги. Подключать существующий addon, не менять его исходники.
- [ ] Лёгкое покачивание камеры игрока с настройкой/отключением для проверки и reduced motion.
- [x] Команда консоли включает/выключает весь debug HUD, позволяя тестировать чистую игру и отладочный вариант.

### Игровые события

- [ ] Игрок открыл/закрыл терминал.
- [ ] Игрок взял/поставил посылку.
- [ ] Игрок открыл/закрыл дверь.
- [ ] События содержат игрока и конкретный объект, срабатывают один раз после фактического перехода и доступны будущему поведению NPC/скриммерам.

### M1 active implementation contract

Сначала двери: сохранять door_template и C_Openable authority; навесной замок — внутренний узел той же двери, HP на владельце; C_BreakableDoor выбирает PADLOCK/LEAF без второго Entity/session. Уничтожение замка разблокирует, дверь с Health освобождает проход. Использовать существующий damage pipeline; health/lock состояние сохранять через текущий snapshot boundary, не возвращать разрушенный authored объект после load. Добавить оба варианта в тестовую сцену с отдельными местами. Далее посылки с физическим содержимым.

M1 unpack contract: optional DEF_Package.unpack_scene and existing content_quantity; C_PackageContents.released is a saveable one-shot guard, separate optional component so old PackageState save schema remains unchanged. Opened lifecycle spawns individual floor-projected physical contents, inventory quantity1 each. Small18kg/large75kg shelves have open cavities and real panel colliders, C_Anchorable and current physical grab. Optional hazard_on_opened uses existing autonomous emitter.

### M1 validation

GUT58/58,469 assertions (7scripts), `.export/doors-contents-final-gut.log`: real knife/hammer windows, padlock cannot unlock before damage, leaf clears both colliders, tombstones intact/broken snapshot/Night; five individual food/med items, physical opening, inventory eating/healing, one-shot across repeated lifecycle/load, opened hazard dedup; small shelf real ground support, actual hammer fastening and anchored snapshot. Existing unfix test now waits its authored duration (QA06 extended default). Strict actual-primitive `doors_contents-20261003-063148543.log` PASS; separate read-only door/contents reviews found no material findings. Structure/diff PASS; formatter unavailable SKIP. Full-day/visual QA belongs to owner.

### QA04 / M4 edible remains milestone

Implemented immediate edible pile permitted by latest owner scope. Authored DEF_NpcRemains:3 physical meat/bone pickups,25 hunger relief each,25% extra medkit. C_NpcRemains.released persists independently; O_NpcRemains reacts to real lethal DamageResult, not restored C_Death. Visitor removal releases remains as normal unowned inventory entities; persistent Trader stays a hidden/frozen noncolliding tombstone, cannot trade, open panel closes/releases input. No extra live Entity ownership authority; existing R_OwnedBy handles pickup.

Validation: GUT40/40,332 assertions (4scripts), `.export/npc-remains-final-gut.log`; real damage/partial/repeated hits, chance0/1, pickup/food consumption, native collision/avoidance, open/dead trading UI, visitor death cleanup, saved death/remains/Night. Strict actual-main `npc_remains-20261003-064735213.log` PASS. Structure/diff PASS; formatter SKIP. Separate read-only review found no material findings. Next: publish Windows milestone, then QA03 inventory grid; client prototype and other M4 requirements remain pending.
