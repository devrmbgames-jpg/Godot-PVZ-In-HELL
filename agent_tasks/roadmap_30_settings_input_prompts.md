# R30 — AtlasTexture, настройки и переназначение управления

Status: **OWNER_QA**

## Task state

### Goal

Меню настроек и управления клавиатурой/геймпадом; HUD/UI показывают кнопки иконками Kenney AtlasTexture вместо текстовых названий.

### Design plan

Опыт игрока: управление можно подстроить под себя, а подсказки всегда показывают фактическую кнопку текущего устройства. Опоры: доступность, предсказуемость, единая визуальная система.

Цикл: открыть настройки → выбрать параметр/действие → изменить и увидеть актуальную кнопку → применить → вернуться к игре; после перезапуска выбор сохранён. Решение игрока — удобное личное назначение, при конфликте явное переназначение/отмена.

1. Atlas milestone: детерминированный XML generator, отдельные .res AtlasTexture по регионам существующих sheet PNG, таблица кнопок; проверить границы и полноту данных. В gameplay UI использовать ресурсы, XML парсить один раз, когда нет .res файлов.
2. Settings milestone: единое модальное меню с возвратом в игру, audio/video параметрами, применением и сбросом. Реализовать доступные движку параметры без нерабочих обещаний.
3. Input milestone: список semantic actions, отдельно клавиатура и геймпад; capture следующего допустимого события, Escape/Back отменяют, конфликты разрешаются явно, analog axes учитывают направление/deadzone. Сохранение binding и default reset.
4. Prompt milestone: централизованное определение AtlasTexture для актуального binding/устройства; заменить текст кнопок в HUD, терминалах, диалогах, инвентаре, меню настроек и остальных проектных UI. Названия действий остаются текстом.
5. Целевые проверки генератора/rebind/persistence и один relevant smoke на завершении; владелец тестирует реальную клавиатуру/геймпад и читаемость.

Риски: невозможно выйти из меню после назначения; конфликт с консолью/модальным захватом; иконка не совпадает с InputMap; неверное изображение gamepad family. Параметры: sensitivity/deadzone, audio levels и применимые video options; восстановление defaults всегда доступно.

Гипотеза QA: для любого изменённого действия подсказка показывает новую кнопку; смена активного устройства меняет иконки, настройки переживают запуск и не мешают Carry/Dialogue/Console.

### Constraints / acceptance

- Источник res://resources/kenney/kenney_input_prompts/: читать существующие XML и соответствующие листы; сгенерировать отдельные AtlasTexture .res для кнопок, не нарезать PNG.
- Назначения клавиатуры и геймпада меняются в меню, сохраняются и восстанавливаются после запуска; предусмотреть сброс, отмену, конфликты и недоступные кнопки.
- Все подсказки/подсветки игровых кнопок в HUD, UI и настройках используют AtlasTexture актуального binding. Учитывать активное устройство и несколько назначений.
- Сохранить приоритет Modal/Console/Carry и существующие semantic InputMap actions; не терять навигацию и выход из меню при переназначении.
- Настройки — отдельный понятный экран, минимальные реально поддерживаемые audio/video/input параметры, без фиктивных переключателей.
- Dev only; master read-only. R25 документация выполняется последней.

### Milestones

- [x] Изучить XML/atlas: сгенерированы все1416 ресурсов из10 XML; event→icon mapping реализован.
- [x] Добавить меню настроек и сохранение рабочих параметров.
- [x] Добавить capture/rebind клавиатуры и gamepad, конфликты/сброс/сохранение; заменить button hints во всех проектных UI.
- [x] Целевые проверки XML/ресурсов/rebind/persistence и QA-сценарий. Windows main/test be10abab export/startup PASS; player device QA ожидается.

### Current

M0: PromptAtlasCatalog и utils/generate_input_prompt_atlases.gd. Готовые binary AtlasTexture в content/resources/input_prompts/<family>/<default|double>/*.res. На отсутствие .res — одноразовый XML fallback/cache по листу (уточнение владельца сохранено). M1–M3 реализованы: общий HUD обеих сцен создаёт SettingsMenu. Modal token сохраняет Carry/другие захваты; меню владеет паузой/курсорным режимом только на время открытия. Настройки громкости/fullscreen/vsync/reduced motion/sensitivity/deadzone действуют и сохраняются отдельно от игрового snapshot в user://settings.cfg. Keyboard/mouse и gamepad назначаются отдельно; modifiers и signs осей сохраняются, конфликты требуют подтверждения. Escape/Back сохраняют safety exit, клавиша консоли зарезервирована. Семантические [input=action] snapshots рендерятся InputPromptLabel через AtlasTexture; показаны все modifiers/альтернативы. HUD, terminal, inventory, commerce, dialogue и settings используют актуальные иконки; XML включён в export для fallback. Финальные Windows main/test be10abab экспортированы; оба actual-scene120-frame startup PASS, launchers обновлены. Next: owner QA основного игрового среза и устройств. R25 остаётся LAST после предыдущих задач и QA-исправлений.

### Validation

M0: генератор проверил границы, уникальность имён и roundtrip каждого из1416 binary .res (.export/r30-atlases.log). Повторная генерация:1416 проверено,0 записано (.export/r30-atlases-idempotent.log). Structure PASS. GUT/rendered gameplay для генерации не запускались. M1–M3: related111/111,811 (.export/r30-related-gut.log); после review settings8/8,53 (.export/r30-settings-review-gut.log). Финальный крупный milestone:471/471,3914,54 scripts (.export/r30-milestone-full-gut.log), без пропущенных скриптов/ошибок парсинга. Последний узкий check добавленного fallback:1/1,6 (.export/r30-prompt-fallback-gut.log). Actual-main raw input/settings/capture negative axis/cancel/exit smoke PASS: tests/artifacts/settings_input-20261003-173619701.log. Structure/diff PASS. Единственное окружение Windows предупреждение certificate store. Rendered/device acceptance не выполнялась.

Final local fix: S_PlayerInput очищает накопленный mouse/button input и drop tracking на NOTIFICATION_PAUSED. Только связанная drop-поверхность3/3,16 (.export/r30-pause-drop-gut.log); полный GUT повторно не запускался.

### Review findings

- R1/P2 FIXED, reviewer confirmed: Ctrl+E и E пересекаются при runtime non-exact InputMap matching; InputBindingCodec.overlaps/confirmed removal теперь учитывают базовую клавишу без модификаторов, знак joy axis сохраняется. Регрессия проверяет actual InputMap.event_is_action до/после назначения.

- R2/P2 FIXED (self-review): во время Settings pause release кнопки мог не поступить paused producer, а pending look/drop сохранялся до resume; engine pause notification сбрасывает producer-owned input/derived drop tracking.

### Owner QA / blockers

[Сценарий настроек/управления](../qa_tasks/settings_and_controls.md); [полный день](../qa_tasks/full_day.md). Нужны настоящие keyboard/gamepad, fullscreen/vsync/audio/плотность UI и визуальная читаемость. Для редких кнопок без соответствующей картинки Kenney используется общая иконка клавиатуры/устройства, сохраняющая AtlasTexture contract. Полный срез выполняет владелец по его явному запросу.
