# Настройка клиентов и кабинок

Поведение конкретного визита задаёт `DEF_Customer` в событии `DEF_CustomerSchedule`. Движение использует настоящий NavigationAgent и native rigid body; живые назначения, владение и резервирование — Relationships.

Для осмотра включить `private_inspection`. `inspection_seconds` задаёт время внутри кабинки (по умолчанию12с), `inspection_unpack_probability` — шанс открыть коробку, `inspection_keep_probability` — шанс забрать результат. Политики `accepts_opened`, `accepts_damaged`, `voluntary_refusal` продолжают действовать. Решение и расчёт выдачи откладываются до возвращения. При отсутствии доступной кабинки используется обычная выдача. Недостижимый путь ограничен `approach_timeout`, затем клиент возвращает заказ.

Разместить экземпляры `inspection_booth.tscn` на доступном navigation mesh. Позиция корня — цель; каждый включённый C_InspectionBooth резервируется одним NPC. Это прототип зоны с надписью и отметкой, будущие стены/двери кабинки авторит уровень. Основная карта: x8.5/10.5,z−4.3 в клиентской комнате по DebugMarkers; primitive: x8/12,z−16. Runtime не читает скрытые DebugMarkers.

`InspectionParcelSlot` — неинтерактивный дочерний physical slot. Реальная коробка закрепляется существующими R_StoredIn/R_SlotMountedOn и RemoteTransform при explicit mounted synchronization; после освобождения native physics возвращается. R_InspectionCargo владеет оригиналом/результатами на время осмотра, R_InspectingAt резервирует кабинку. Player grab/inventory/open не обходят владение. Death/removal/Night освобождают вещи, финальная выдача не начисляется за потерянную/уничтоженную коробку.

Распаковка идёт через обычный PackageOpening/lifecycle/contents/hazards с NPC в роли открывшего. Для содержимого назначить `DEF_Package.unpack_scene` и `content_quantity`, для опасности — `hazard_on_opened`. Отказ оставляет вещи доступными игроку; принятие удаляет их один раз. Пустая коробка при отказе сохраняет регистрацию. Debug status над NPC показывает фазу, таймер и вероятности.

В обычном расписании покупатель книг осматривает и принимает с вероятностью75%; покупатель одежды осматривает, с вероятностью50% распаковывает заглушку рабочей одежды и отказывается по прежней политике. Остальные сценарии по умолчанию сохраняют обычную выдачу.

## Копируемый клиент

Исходник: [customer_prototype.tscn](customer_prototype.tscn); профиль: [def_customer_prototype.tres](../definitions/def_customer_prototype.tres); событие: [def_customer_prototype_event.tres](../definitions/def_customer_prototype_event.tres); диалог: [customer_prototype.dialogue](../dialogue/customer_prototype.dialogue). Пример события не включён в обычное расписание автоматически.

1. Скопировать сцену и внешний профиль. В профиле назначить `customer_scene_path` на новую сцену, `dialogue_resource_path` на копию диалога. Пустые пути сохраняют общую сцену расписания и стандартный диалог.
2. Скопировать событие, назначить его `customer` на новый профиль, выбрать посылку и день; добавить событие в `DEF_CustomerSchedule`. Профиль визита управляет общением, интересами, осмотром, таймерами, челленджами и политикой выдачи. `interests` доступны диалогу через `ctx.interests_text()`; это описательные данные, а не скрытый выбор атак.
3. В сцене сохранить наследуемые тело, NavigationAgent, InspectionParcelSlot и компоненты. Назначить реальные клипы в AnimationPlayer и имена `idle_animation`, `walk_animation`, `inspection_animation`, `receiving_animation`, `dialogue_animation`. Пока специальные клипы заменены Idle. Неизвестный клип использует обычный Idle; реальное движение выбирает Walk, активная атака сохраняет приоритет. Root motion не перемещает физическое тело.
4. В копии диалога менять текст и ветки через существующий `ctx`. Сохранить используемые входы `direct`, `followup`, `challenge`, `riddle`, `false_taken`, `voluntary_refusal` и вызываемые переходы/действия. Отсутствующий вход не захватывает управление и не оставляет клиента в фазе диалога.

До трёх ближних и трёх дальних атак остаются независимыми настройками C_NpcCombat. Для анимационных атак использовать существующие `npc_attack_hit()`, `npc_attack_finished()` из E_NpcCharacter. Простой автоматический выбор можно выключить через `automatic_attack_selection`, когда внешнее поведение, например LimboAI, будет вызывать существующий запрос атаки. Шаблон не вводит второй граф поведения или отдельный жизненный цикл клиента.
