# R30 — Иконки кнопок, настройки и переназначение управления

Status: **OWNER_QA**

## Task state

### Goal

Меню настроек и управления клавиатурой/геймпадом; HUD/UI показывают кнопки иконками Kenney PNG вместо текстовых названий; актуальное решение M4 заменяет прежние AtlasTexture/XML.

### Design plan

Опыт игрока: управление можно подстроить под себя, а подсказки всегда показывают фактическую кнопку текущего устройства. Опоры: доступность, предсказуемость, единая визуальная система.

Цикл: открыть настройки → выбрать параметр/действие → изменить и увидеть актуальную кнопку → применить → вернуться к игре; после перезапуска выбор сохранён. Решение игрока — удобное личное назначение, при конфликте явное переназначение/отмена.

1. Resource milestone: отдельные предоставленные PNG, приоритет outline; единый InputPromptCatalog возвращает Texture2D. XML, общие листы и generated .res удалены по замечанию владельца (M4).
2. Settings milestone: единое модальное меню с возвратом в игру, audio/video параметрами, применением и сбросом. Реализовать доступные движку параметры без нерабочих обещаний.
3. Input milestone: список semantic actions, отдельно клавиатура и геймпад; capture следующего допустимого события, Escape/Back отменяют, конфликты разрешаются явно, analog axes учитывают направление/deadzone. Сохранение binding и default reset.
4. Prompt milestone: централизованное определение Texture2D для актуального binding/устройства; заменить текст кнопок в HUD, терминалах, диалогах, инвентаре, меню настроек и остальных проектных UI. Названия действий остаются текстом.
5. Целевые проверки иконок/rebind/persistence и один relevant smoke на завершении; владелец тестирует реальную клавиатуру/геймпад и читаемость.

Риски: невозможно выйти из меню после назначения; конфликт с консолью/модальным захватом; иконка не совпадает с InputMap; неверное изображение gamepad family. Параметры: sensitivity/deadzone, audio levels и применимые video options; восстановление defaults всегда доступно.

Гипотеза QA: для любого изменённого действия подсказка показывает новую кнопку; смена активного устройства меняет иконки, настройки переживают запуск и не мешают Carry/Dialogue/Console.

### Constraints / acceptance

- Источник res://resources/kenney/kenney_input_prompts/<family>/Default/: целые PNG, outline при наличии, иначе обычная кнопка. XML/листы и generated resources/input_prompts удалены; отдельные PNG пользователя не менялись.
- Назначения клавиатуры и геймпада меняются в меню, сохраняются и восстанавливаются после запуска; предусмотреть сброс, отмену, конфликты и недоступные кнопки.
- Все подсказки/подсветки игровых кнопок в HUD, UI и настройках используют Texture2D отдельного PNG актуального binding. Учитывать активное устройство и несколько назначений.
- Сохранить приоритет Modal/Console/Carry и существующие semantic InputMap actions; не терять навигацию и выход из меню при переназначении.
- Настройки — отдельный понятный экран, минимальные реально поддерживаемые audio/video/input параметры, без фиктивных переключателей.
- Dev only; master read-only. R25 документация выполняется последней.

### Milestones

- [x] Исторический M0 XML/atlas:1416 ресурсов. Отменён владельцем; M4 заменил на отдельные PNG, сохранив event→icon mapping.
- [x] Добавить меню настроек и сохранение рабочих параметров.
- [x] Добавить capture/rebind клавиатуры и gamepad, конфликты/сброс/сохранение; заменить button hints во всех проектных UI.
- [x] Целевые проверки ресурсов/rebind/persistence и QA-сценарий. Windows main/test be10abab export/startup PASS; player device QA ожидается.

### Current

M4 реализован: InputPromptCatalog возвращает целые PNG/Texture2D из пяти семейств Default, outline имеет приоритет, остальные кнопки и directions используют обычный PNG; unsupported button использует иконку устройства. Все HUD/UI/settings consumers обновлены. Удалены1417 generated files (1416.res + README),30 sheet PNG/XML/import, старый каталог и генератор.1488 отдельных PNG пользователя сохранены с неизменными SHA256.34 удалённых sheet/code files, включая изменённый XML, сохранены в .export/r30-m4-removal-backup; manifests проверены. Export не требует XML. Настройки, InputMap, binding/capture/pause/Carry contracts сохранены. Следующий шаг — commit и main/test Windows exports; затем owner device/visual QA. R25 LAST.

### Validation

M0: генератор проверил границы, уникальность имён и roundtrip каждого из1416 binary .res (.export/r30-atlases.log). Повторная генерация:1416 проверено,0 записано (.export/r30-atlases-idempotent.log). Structure PASS. GUT/rendered gameplay для генерации не запускались. M1–M3: related111/111,811 (.export/r30-related-gut.log); после review settings8/8,53 (.export/r30-settings-review-gut.log). Финальный крупный milestone:471/471,3914,54 scripts (.export/r30-milestone-full-gut.log), без пропущенных скриптов/ошибок парсинга. Последний узкий check добавленного fallback:1/1,6 (.export/r30-prompt-fallback-gut.log). Actual-main raw input/settings/capture negative axis/cancel/exit smoke PASS: tests/artifacts/settings_input-20261003-173619701.log. Structure/diff PASS. Единственное окружение Windows предупреждение certificate store. Rendered/device acceptance не выполнялась.

Final local fix: S_PlayerInput очищает накопленный mouse/button input и drop tracking на NOTIFICATION_PAUSED. Только связанная drop-поверхность3/3,16 (.export/r30-pause-drop-gut.log); полный GUT повторно не запускался.

### Review findings

- R1/P2 FIXED, reviewer confirmed: Ctrl+E и E пересекаются при runtime non-exact InputMap matching; InputBindingCodec.overlaps/confirmed removal теперь учитывают базовую клавишу без модификаторов, знак joy axis сохраняется. Регрессия проверяет actual InputMap.event_is_action до/после назначения.

- R2/P2 FIXED (self-review): во время Settings pause release кнопки мог не поступить paused producer, а pending look/drop сохранялся до resume; engine pause notification сбрасывает producer-owned input/derived drop tracking.

### Owner QA / blockers

[Сценарий настроек/управления](../qa_tasks/settings_and_controls.md); [полный день](../qa_tasks/full_day.md). Нужны настоящие keyboard/gamepad, fullscreen/vsync/audio/плотность UI и визуальная читаемость. Для редких кнопок без соответствующей картинки Kenney используется общая иконка клавиатуры/устройства, сохраняющая Texture2D contract. Полный срез выполняет владелец по его явному запросу.


## M4 — замена атласов отдельными спрайтами (2026-10-03)

Пользователь отменил AtlasTexture/XML контракт: исходный XML неверно соотносится с изображениями. Удалить resources/input_prompts целиком, листы *_sheet_* PNG/XML и генератор. Использовать предоставленные PNG в resources/kenney/kenney_input_prompts/<family>/Default, предпочитая *_outline.png при наличии. Общий каталог должен возвращать Texture2D целого спрайта; fallback — обычный вариант этой кнопки, затем существующая иконка устройства. Обновить HUD/UI/settings consumers, тесты, export contract; InputMap/rebind/gameplay не менять. Отдельные PNG пользователя сохранять.

План записан до реализации. Проверки: coverage основных клавиш/мыши/gamepad directions и modifiers, целевые settings GUT и один raw settings smoke; structure/diff. Полный прогон не нужен для локальной ресурсной миграции. При существенном ресурcном этапе — Windows main/test exports для owner QA. Визуальная проверка на устройстве остаётся владельцу.


M4 validation: focused settings10/10,74 assertions (.export/r30-m4-settings-gut.log); actual-main raw capture negative-axis/cancel/resume smoke PASS tests/artifacts/settings_input-20261003-194114840.log. Обычные PNG вместо atlas, outline selection, четыре gamepad family/directions, unknown button fallback и modifiers проверены. Все keyboard/mouse mapping stems существуют. Structure/diff PASS; полный suite и rendered не повторялись. Windows exports следующий шаг. Первое пакетное удаление отклонено automatic review; после exact-list backup/hash verification повторная проверка разрешила обратимое удаление. Отдельные PNG сохранены.
