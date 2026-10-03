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
