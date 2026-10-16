# NPC CharacterBody — короткое отбрасывание и удерживаемый предмет

Owning task: [.agents/tasks/npc_characterbody_and_bounded_impact.md](../../.agents/tasks/npc_characterbody_and_bounded_impact.md).
Status: **NOT_RUN**. Разрешение на rendered/gameplay QA этой задачи: **NOT_GRANTED**.
Бюджет milestone: максимум **8** проверок; использовано **0/8**, подготовлено **6** случаев.
Другие QA-разрешения и исчерпанные бюджеты сюда не переносятся.
Reviewed runtime SHA: `d6f599dafc85af4d25f2b788a94aa75f5540a6ea`.
Build: [PVZInHell.exe](../../.export/windows/20261016-204405Z-d6f599da-npc-characterbody-bounded-verified/PVZInHell.exe),
launcher: [.export/LATEST.cmd](../../.export/LATEST.cmd).
Native export command/menu/level startup PASS (120 frames each, stderr0 for both startup runs).
Export process shutdown diagnostics: Resource/RID DEFERRED by owner; generic ObjectDB/PagedAllocator
UNKNOWN/mixed, not diagnostic PASS. Earlier DLL-lock export logs retained; final export has no
DLL-copy error. Native MCP runtime of the reviewed source is an alternative rendered target.
Build dirty flag records pre-existing GECS metadata, project-owned runtime was committed.

## Подготовка после разрешения

Использовать актуальную Windows QA-сборку или соответствующий reviewed MCP runtime.
Изолированные native NPC test rooms: Бугай для физических случаев, Ангел для наблюдения.
Обычные сохранения не перезаписывать; если нужен слот, только отдельный `qa_npc_characterbody_*`.
Стабильное исходное положение/здоровье между случаями восстанавливать существующим lifecycle,
не выдавать подготовительное размещение за движение. Не менять массу, профиль урона, личность,
лимиты или частоту физики ради результата. Настройки planar3/up1/decay10 пока прототипные.

## Ограниченные случаи

| № | Одна проверка | Критерий | Результат |
| --- | --- | --- | --- |
| 1 | Один сильный свободный бросок тяжёлой бочки в стоящего обычного NPC на ровном полу. | Короткий читаемый толчок, ориентир до1м; допустимый урон сохраняется, источник/бросивший различаются. Нет дальнего скольжения или запуска вверх. | NOT_RUN |
| 2 | Удерживаемым ящиком давить10с на NPC у вертикальной стены. | Предмет упирается/пружина уступает; захват сохраняется. NPC не проходит сквозь стену и не разгоняется. После прекращения давления нет отложенного запуска. | NOT_RUN |
| 3 | Один раз подвести удерживаемую бочку под опору NPC и затем отпустить её обычным действием. | Удерживаемая опора не переносит NPC вверх; отпускание не высвобождает накопленную скорость. Не подменять отпускание броском. | NOT_RUN |
| 4 | Два последовательных свободных удара в NPC у конца узкого прохода/угла под низким потолком. | Геометрия удерживает капсулу; нет прохода через угол/потолок, увеличивающейся реакции или выстрела после освобождения. | NOT_RUN |
| 5 | Один удар по идущему NPC, затем дать ему продолжить свой маршрут. | Собственная скорость/поворот головы восстанавливаются; Walk/Idle и шаги соответствуют фактическому движению, маршрут не подтверждает выдачу сам по себе. Оценить отсутствие рывка анимации. | NOT_RUN |
| 6 | Один свободный удар по наблюдаемому Ангелу, затем отвести взгляд. | Во время наблюдения тело/анимация неподвижны, после — обычное движение без накопленного старта. Авторская невосприимчивость к IMPACT сохраняется: отсутствие потери HP у Ангела не означает потерю контакта. | NOT_RUN |

Каждый начатый rendered случай расходует бюджет, в том числе FAIL/INCONCLUSIVE.
Фиксировать tested SHA/build, фактические действия и ограниченное evidence; не повторять случай
автоматически ради PASS. Новый непредусмотренный visual/playtest запуск требует остатка
соответствующего разрешения. Native GUT/smoke не расходуют этот rendered бюджет.

## Приёмка

Headless метрики не доказывают чувство массы/читаемость. Владелец отдельно оценивает короткий
толчок и устойчивость удерживаемого предмета у стены. Пока обязательные случаи не оценены,
owning task остаётся открытой; NOT_RUN/INCONCLUSIVE не считать PASS или DONE.

## Техническая матрица Source

Матрица reviewed в `d6f599dafc85af4d25f2b788a94aa75f5540a6ea`; подробные timestamps и команды
хранятся в owning task. Headless PASS ниже не заменяют rendered acceptance.

| Обязательный контракт | Фактическое техническое evidence |
| --- | --- |
| Все live NPC/customer/trader roots и Traits | Native room6/1452 для десяти архетипов, handoff14/125, remains7/76; native authoring preflight и reviewed scenes. |
| Общий callback без копии player input | Foundation003af971, migration23e26a25 и repair5a2cf2a6 reviewed; неизменённая unbounded ветка player8/41. |
| Общие caps, light/heavy/raw/barrel/throw damage | Impact21/1016, contact6/40, attribution4/18; настоящие native удары и committed actor receipts. |
| Held spring/support, release/throw | Impact проверяет authored/raw grip, обычную unheld платформу; final shared carry92/438. |
| Стена/угол/потолок/узкий проход, без latent launch | Impact21/1016: реальные коллайдеры, падающий multi-normal corner, согласованность cache/body, освобождение после давления. |
| Freeze и stationary damage | Gaze16/122; physical fixture явно nonimmune, авторская невосприимчивость Ангела сохранена. |
| Своя скорость, голова, terrain/delta, path/avoidance | Impact: actual12mps, независимый взгляд, step/slope,60/120Hz; intent6/22, traffic12/81, final navigation smoke. |
| Анимация/шаги/attack callbacks | Impact Walk/Idle при противоположном intent; district7/64 и inherited fixture; attacks22/160. |
| Dormancy/activation, death, placement/reset | Activation12/119, remains7/76, gaze transition/reset caches; нет второго mutable freeze owner. |
| Stable identity/recipes и active/dormant restore | Disk participation snapshot9/162; схема для этой миграции не менялась; incoming cache transient и очищается. |
| Handoff/parcel slots/outcomes | Handoff14/125, parcel holder7/48, текущая demand dialogue48/614. |
| Читаемый короткий толчок и held-wall feel | NOT_RUN, случаи выше,0/8; отдельное task-specific разрешение обязательно. |
