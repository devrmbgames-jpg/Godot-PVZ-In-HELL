# История выполненных задач

Предыдущая история: [архив №2, 2026-10-03](task_history_archive/0002-20261003.md). [Все архивы](task_history_archive/README.md).

При превышении **12 КиБ** перенести файл целиком в следующий нумерованный архив; сохранять цепочку ссылок и адаптировать относительные пути.

- 2026-10-03 — R24 M4: копируемый CustomerPrototype, внешний профиль/событие/диалог, выбор сцены и диалога профилем, интересы для ctx, отдельные анимации обслуживания с приоритетом Walk/Combat. Focused2/2,17 + изменённая проверка диалога1/1,13. Полный прогон не повторялся. Инструкция content/entities/customers/README.md; ручной QA qa_tasks/world_customers_commerce.md. Windows экспорт после commit.

- 2026-10-03 — M4 Windows57533cb1 main/test: actual-scene120-frame startup PASS, .export/LATEST.cmd и TEST_LEVEL.cmd обновлены. LOW console help/scroll: проектный adapter, видимый курсор, колесо/скроллбар, help command/group из реестра; addon не изменён. Focused2/2,14. Остальное расширение консоли продолжается.

- 2026-10-03 — LOW console Stages10–15:28 новых команд по текущим игровым API, live visit option, справка/примеры/группы, diagnostics hazards/valves. Только именованные debug_slots в Morning; R7/P2 сохранение во время push/cart FIXED и подтверждено review.22 старые regressions PASS,6 новые parser tests52 + R7 alone1/1,14; actual-main developer_console smoke PASS. Полный GUT не повторялся. R23/R24/console переведены OWNER_QA: полносуточный игровой срез вручную проверяет владелец.

- 2026-10-03 — Final Windows9d06320c main/test exported, both actual-scene120-frame startup PASS. Launch .export/LATEST.cmd / TEST_LEVEL.cmd. Все новые R24 механики и console28/help/scroll включены. Ручной полный проход main_level передан владельцу по его запросу; статус OWNER_QA, успешная игровая приёмка не заявлена.

- 2026-10-03 — R26 автоприём правильной посылки в1.5м через прежний delivery/refusal/inspection owner; CarryPlacement удобный объём наведения, безопасный ступенчатый путь под полку, повторный захват сохранён.44/44 related GUT417; existing physical placement и actual-main8 placement/retrieve smoke PASS. Review чистый; полный срез/рендер не запускались. QA qa_tasks/customer_handoff_placement.md. Новые запросы R27–R30 записаны, R25 LAST.

- 2026-10-03 — R27 строгая очередь уже имеет общий запрет второго живого C_CustomerAgent в штатном/debug spawn;7 timing +6 handoff =13/13,129. Новая регрессия проверяет6 фаз и закрытый accounting outcome. R1 compile-time supply preload cycle FIXED загрузкой того же ресурса при _init; mutation автоприёма остаётся только CustomerFlow. R26 Windows main b699f423 startup PASS, LATEST обновлён.

- 2026-10-03 — R29 CharacterBody при ходьбе ограниченно толкает свободные лёгкие RigidBody через central impulse.15кг/180Н/3мс настраиваются, Strength масштабирует. Frozen/held/stored/living/floor исключены. Native physics8/8,41: лёгкая коробка освобождает путь без подъёма, тяжёлая/замороженная блокирует, прежние контакты и тележка сохранены. Player QA ожидается.

- 2026-10-03 — R28 физическое содержимое:4 pickups RigidBody, все8 supply типов имеют содержимое; пустая оболочка safe/light, hazard ownership перенесён, snapshot/inspection/inventory поддержаны. Review R1 доставки и R2 carry mass FIXED. Related42/42,543 + review contents10/10,187/commerce6/6,101; полный крупный milestone463/463,3861,53scripts, hazards smoke PASS20261003-165946277. QA qa_tasks/physical_package_contents.md; Windows main/test export после commit. Rendered/player QA ожидается.

- 2026-10-03 — R28 Windows5e9b17a4 main/test actual-scene120-frame startup PASS; launchers updated. R30 M0:1416 binary AtlasTexture .res from10 supplied Kenney XML; bounds/name/roundtrip PASS, repeat0writes. Runtime fallback parses XML once only if resource absent. Remaining settings/rebind/prompt UI in progress.

- 2026-10-03 — R30 M1–M3: SettingsMenu общий HUD, user://settings.cfg, modal pause/cursor lifecycle, keyboard/mouse/gamepad rebind/conflict/reset, safety Escape/Back, input sensitivity/deadzone/audio/video/reduced motion; актуальные AtlasTexture в HUD/terminal/inventory/commerce/dialogue/settings. Review R1 modifier overlap FIXED/confirmed. Related111/111,811; review8/8,53; full крупный milestone471/471,3914,54scripts; actual-main settings_input smoke PASS20261003-173619701; final fallback1/1,6. Owner QA qa_tasks/settings_and_controls.md, full slice/device/audio/visual ждёт владельца; R25 LAST. Windows main/test export после commit.

- 2026-10-03 — R30 final pause-input fix: clear producer pending mouse/buttons and drop tracking on NOTIFICATION_PAUSED; no accidental throw/view jump on resume. Only related drop3/3,16 PASS (.export/r30-pause-drop-gut.log); full milestone not repeated. Main60b92d56 startup PASS, final main/test exports after fix commit.

- 2026-10-03 — Финальные Windows QA be10abab dev: main .export/windows/20261003-074906Z-be10abab-settings-input-final-main/PVZInHell.exe; test .export/windows/20261003-075037Z-be10abab-settings-input-final-test/PVZInHell.exe. Оба actual-scene120-frame startup PASS, launchers обновлены.10 source XML включены для missing-.res fallback. Полный срез и device/visual/audio acceptance переданы владельцу; R25 LAST после QA-исправлений.

- 2026-10-03 — Очистка log-артефактов:336 ненужных промежуточных/повторных/старых экспортных логов удалено,7542725 bytes /7.19MiB.75 referenced/latest smoke/current Windows logs сохранены; файлы/mtime/границы workspace проверены до удаления, защищённые файлы после него существуют. Билды/исходники/сохранения не менялись; tests/engine не запускались. Task agent_tasks/log_artifact_cleanup.md DONE.


## 2026-10-03 — R31–R33: ресурсы, походка, приседание и бег

Планы записаны до реализации (66ab4683). R31 root resources migration:1417 unchanged hashes, atlas1416/0writes. R32 shared stride/audio/bob, реже шаги и ниже пояс при crouch; targeted5/5,33. R33 typed C_Stamina + owning S_Sprint, Shift/left stick hold/toggle, strength capacity/carry drain/recovery, common native speed multiplier, main/test component overrides, HUD/debug/read-only console/help, snapshot reserve/runtime reset. Full484/484,3996,55; subsequent heavy-load-only9/9,55. Native main raw input/settings/real console parser smoke PASS20261003-183557159. Reviewer R1 optional stamina target FIXED/confirmed. Player QA pending; qa_tasks/sprint_stamina.md. Только dev; пользовательские правки сохранены. Windows builds — следующий шаг. R25 остаётся LAST.


R33 Windows ecd95df9: main20261003-084015Z/test20261003-084159Z, оба actual-scene120 startup PASS; launchers обновлены. Очистка6 failed sprint smoke logs (4529 bytes), успешные evidence/build logs сохранены. Player QA PENDING.


## 2026-10-03 — R34: главное меню и игровые слоты

План e5b31ff6 записан до реализации. Главное меню new/load/settings/exit и игровой save/load/new/main/exit, standalone settings без actor, подтверждение потери прогресса. Morning manual slot + существующий night autosave, main/test отдельные; detached graph preflight до смены live world; новый старт не читает/не удаляет старые файлы. Параметры сохраняются также при переходах. Related30/30,203; full491/491,4029,56; real GUI clicks/session lifecycle smoke192144176 и raw settings input192408372 PASS. Reviewer R1 FALSE_POSITIVE (indentation), R2 FIXED/confirmed (preferences). QA qa_tasks/main_menu_and_saves.md ожидает игрока; rendered/full slice/device не запускались. Windows exports следующий шаг. Только dev, unrelated user changes сохранены; R25 LAST.


R34 Windows97a0ef71: main20261003-092610Z/test20261003-092744Z, оба menu120 + actual-level120 headless startup PASS; launchers обновлены. Player QA PENDING. Удалены2 failed GUI smoke logs1795bytes и временный selective project index, успешные evidence/build logs сохранены.


## 2026-10-03 — R30 M4: отдельные PNG вместо неверного атласа

Владелец отменил AtlasTexture/XML контракт. InputPromptCatalog и все UI consumers используют целые PNG/Texture2D; outline при наличии, обычный PNG/иконка устройства fallback.1417 generated files,30 sheet PNG/XML/import, старый каталог/генератор удалены;1488 отдельных PNG unchanged SHA256. Изменённый исходный XML и остальные удаляемые sheet/code сохранены в .export/r30-m4-removal-backup перед разрешённым повторным automatic review. Settings10/10,74, raw settings smoke194114840 PASS; structure/diff PASS, full/rendered не повторялись. Owner device/visual QA pending; Windows exports следующий шаг. Dev only; unrelated user changes сохранены.


R30 M4 Windows f7c1b8cc: main20261003-094515Z/test20261003-094648Z, оба menu120 + actual-level120 startup PASS; новые PNG включены, старые atlas paths отсутствуют. Launchers обновлены, включая полный help bd59ecad. Player QA pending.
