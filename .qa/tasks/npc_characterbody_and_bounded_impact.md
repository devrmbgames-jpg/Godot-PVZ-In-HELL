# NPC CharacterBody — короткое отбрасывание и удерживаемый предмет

Owning task: [.agents/tasks/npc_characterbody_and_bounded_impact.md](../../.agents/tasks/npc_characterbody_and_bounded_impact.md).
Status: **OWNER_QA**. Разрешение на rendered/gameplay QA этой задачи: **GRANTED: до 6 случаев**, явный ответ владельца 2026-10-17.
Бюджет milestone: максимум **8** проверок; использовано **6/6** (общий потолок8), выполнено **6** случаев: **3 PASS / 3 INCONCLUSIVE**. Выданный лимит6 исчерпан.
Другие QA-разрешения и исчерпанные бюджеты сюда не переносятся.
Reviewed physics SHA: `d6f599dafc85af4d25f2b788a94aa75f5540a6ea`.
Current reviewed MCP runtime SHA: `45cb14b55fddea92bf6d1bbc694c856b24fb2b64` (D2 review no findings).
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
| 1 | Один сильный свободный бросок тяжёлой бочки в стоящего обычного NPC на ровном полу. | Короткий читаемый толчок, ориентир до1м; допустимый урон сохраняется, источник/бросивший различаются. Нет дальнего скольжения или запуска вверх. | INCONCLUSIVE: QA preparation ошибочно записала C_Motion.velocity; debugger break до броска. Native barrel18kg также без C_ThrowDamage; attribution вручную не подтверждена. |
| 2 | Удерживаемым ящиком давить10с на NPC у вертикальной стены. | Предмет упирается/пружина уступает; захват сохраняется. NPC не проходит сквозь стену и не разгоняется. После прекращения давления нет отложенного запуска. | INCONCLUSIVE: реальный grip получен; PNG доframe300 сохранены, но 8s MCP eval timeout прервал 10s случай до проверки release/residue. |
| 3 | Один раз подвести удерживаемую бочку под опору NPC и затем отпустить её обычным действием. | Удерживаемая опора не переносит NPC вверх; отпускание не высвобождает накопленную скорость. Не подменять отпускание броском. | PASS: native support_seen, grip сохранён, обычный release; height gain0, peak up0 до/после. case3 PNG/JSON. Исправление typed Array в QA preparation до физического действия; runtime tuning не менялся. |
| 4 | Два последовательных свободных удара в NPC у конца узкого прохода/угла под низким потолком. | Геометрия удерживает капсулу; нет прохода через угол/потолок, увеличивающейся реакции или выстрела после освобождения. | PASS: два actual contacts, HP100→50; NPC остался в проходе, max top1.701m, peak up0, после удаления стен speed0. case4 PNG/JSON. |
| 5 | Один удар по идущему NPC, затем дать ему продолжить свой маршрут. | Собственная скорость/поворот головы восстанавливаются; Walk/Idle и шаги соответствуют фактическому движению, маршрут не подтверждает выдачу сам по себе. Оценить отсутствие рывка анимации. | INCONCLUSIVE: QA reset_brain без обязательного bind_engine вызвал cadence assertion до удара. Штатный lifecycle делает оба вызова; игровой дефект не подтверждён. Логи case5 сохранены. |
| 6 | Один свободный удар по наблюдаемому Ангелу, затем отвести взгляд. | Во время наблюдения тело/анимация неподвижны, после — обычное движение без накопленного старта. Авторская невосприимчивость к IMPACT сохраняется: отсутствие потери HP у Ангела не означает потерю контакта. | PASS: actual contact, frozen body/animation delta0, HP100; после отвода взгляда обычное движение2.99m, old external0; повторный взгляд снова freeze. case6 PNG/JSON. |

Каждый начатый rendered случай расходует бюджет, в том числе FAIL/INCONCLUSIVE.
Фиксировать tested SHA/build, фактические действия и ограниченное evidence; не повторять случай
автоматически ради PASS. Новый непредусмотренный visual/playtest запуск требует остатка
соответствующего разрешения. Native GUT/smoke не расходуют этот rendered бюджет.

## Фактическое evidence

Current reviewed runtime: `45cb14b55fddea92bf6d1bbc694c856b24fb2b64`.
Артефакты: `.artifacts/qa_npc_body_45cb14b5/` — case2 PNG(0/60/120/300),
case3/case4/case6 PNG+JSON; case5 MCP editor/game logs. PNG действительно просмотрены.
Brute/Angel — native authored isolated rooms, save path пуст, обычные файлы не трогались.
Постановка перед действием не считалась движением. Для case3 использован native test holder
со штатным R_HeldBy/spring/release; профиль NPC, масса18kg и throw tuning не менялись.
Case4/6 используют два/один свободный raw native box80kg, исходная скорость≈20m/s;
native contacts и допустимый урон подтверждены. Это не новый authored предмет.
Case3 preparation потребовала typed Array[Component] до actual support trial;
case1 и case5 испорчены QA orchestration, не подтверждают игровой дефект.
Case2 предел game_eval8s оборвал длинный coroutine: нового 10s испытания не запускали.
Case3/4/6 завершены короткими этапами без game errors в соответствующих действиях.
Непроверенные короткий свободный толчок/длительный press и ходьба/feel остаются открытыми.

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
| Читаемый короткий толчок и held-wall feel | 3 PASS / 3 INCONCLUSIVE,6/6 выданных случаев израсходованы; субъективная приёмка остаётся открытой. |
