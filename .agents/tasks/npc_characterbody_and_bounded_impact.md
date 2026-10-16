# НПЦ — CharacterBody3D и ограниченное отбрасывание

Status: **IN_PROGRESS**
Technical: **IN_PROGRESS**
Execution order: **50**
Reference baseline: `d6ea70fe8a00071ee9a5b57aa4a7e647e108ea27`
Source: [полное исходное ТЗ и доказательства](references/task-refactor-2026-10-17/npc_characterbody_and_bounded_impact.md.txt).

Эта карточка владеет текущим исполнением. Полный объём требований сохранён в Source;
правила чтения и автономного продолжения — в [README](README.md).


## Goal / acceptance

Перевести всех живых NPC в заявленной поверхности на общий CharacterBody-контур.
Ограничить суммарное внешнее отбрасывание, включая удерживаемые предметы и опоры,
не изменяя собственную скорость NPC, урон/авторство, навигацию, gaze-freeze и lifecycle.
Параллельный постоянный RigidBody-путь для части живых архетипов недопустим.
Полные контакты, миграционные гарантии и матрица Source обязательны.

## Current

Начата P1 подготовка: общий player callback/solver и NPC lifecycle/authoring owners прочитаны;
production migration ещё NOT_IMPLEMENTED. Нативный baseline actual HEAD
`97ff746acc84576a3be98dc8102565d31c391230` подтвердил реальную сильную реакцию RigidBody NPC:
куб-прокси80кг/20м/с дал peak10.977м/с и displacement7.716м за120physics frames; NPC mass60кг,
реальный contact_seen=true, HP100→75 через S_Impact/O_Damage. Лёгкий proxy2кг/30м/с:
peak0.660м/с, displacement0.019м, HP100→75. Это baseline, не PASS будущего clamp.
Подозрение о pending_rebound_velocity остаётся отдельным риском кинематического пути,
а не установленной причиной текущего RigidBody-симптома.
Baseline дополнен настоящей blood_barrel scene18кг/20м/с: peak4.254м/с, displacement0.784м,
HP100→75. Реальный R_HeldBy/GrabService и медленный нажим пружиной: contact=true, grip retained,
peak0.277м/с, displacement0.336м, HP100. Нативная опора на удерживаемой бочке:
floor RID подтверждён, grip retained; подъём0.574м, peak upward0.904м/с; после настоящего release
peak upward0.589м/с. Стена сохранила capsule z0.5200001 (contact boundary с FP epsilon0.0001м),
после её удаления peak≈1.9e−9м/с. Это исходные метрики, не доказательство будущих ограничений.
Corner/ceiling и gaze-specific guarantees остаются частью будущей implementation matrix.
Новая focused regression `test_npc_impact_motion.gd` использует настоящую NPC scene/native Jolt;
контакт копируется из inbox до consumption владельцем S_Impact. Она пока фиксирует старый body type,
который должен быть заменён вместе с миграцией; это не постоянный второй runtime-путь.
Историческое «реализация не запрошена» относится к созданию ТЗ; при команде выполнить
backlog действует общий execution-контракт README, а не повторный запрос на каждый этап.

## Work packages

| Пакет | Проверяемый результат |
| --- | --- |
| P1 | Один NPC использует обобщённый существующий CharacterBody solver; player input/physics не скопированы и не сломаны. |
| P2 | Суммарный rebound/impulse ограничен; held-object, стены/потолок и platform velocity не обходят предел; damage attribution сохранена. |
| P3 | Все живые сцены, authoring traits, шаги/анимация, gaze-freeze, placement/death и restore переведены; старый живой путь удалён из scope. |

Каждый пакет включает соответствующие реальные headless проверки; P3 закрывает
общую миграционную матрицу. Не выдавать пилот P1 за завершение всей задачи.

## Entry points / dependency gates

Начать с e_npc_character.gd, e_district_npc.gd, npc_character.tscn,
kinematic_character_solver.gd, C_CharacterBody/C_Motion и KinematicImpactCapture.
Сохранить связи et_npc_identity/brain_state/roles, S_Impact и s_npc_footsteps.
Не ждать новой социальной системы: P1–P3 используют существующие damage/intent контракты.
P3 предоставляет body/eye/velocity bindings восприятию и Гремлину.

## Next

Собрать exact-SHA review расширенного baseline, затем обобщить существующий CharacterBody callback
для E_PhysicalCharacter, сохранив player input и отдельный независимый NPC look/intent.
`E_CharacterBodyPlayer` сейчас владеет общим callback и ground_ray; solver typed к player только
в step/update_support/_push_support. NPC/trader наследуют rigid foundation; legacy rigid player
тоже использует её, поэтому не менять общий native root вслепую. Сохранить scene paths/UID/anchors.
MCP node_manage не поддерживает смену root type. Для согласованной массовой миграции использовать
разрешённый native offline SceneTree/ResourceSaver путь после проверки unsaved scenes и штатного
закрытия редактора; не расширять MCP и не переписывать открытые сцены. P1/P3 lifecycle должен
собираться согласованно, без отдельного скопированного NPC solver или постоянно двух живых путей.

## Validation / review

Baseline initial2/4 review BASE `97ff746acc84576a3be98dc8102565d31c391230`, TARGET
`c407a2d82fc55dd331c5ea240c20328ee78dd918`: PASS/no findings, reviewer execution NOT_RUN.
Final extended native GUT6/6,17 assertions, stderr0 PASS:
`.artifacts/godot_agent/gut-20261016-182942880.{stdout,stderr}.log`, measured JSON lines retained there.
MCP changed script checked/empty; formatter PASS. Extended-baseline review REVIEW_PENDING.
Implementation parser/GUT/runtime/review ещё NOT_RUN.
Проверять total clamp, повторные контакты,
held/free переход, неподвижного/замороженного NPC, стены/опоры, player regression и fresh restore.
Один согласованный набор evidence на пакет; общий migration check на P3, не после каждого cast.

## Owner QA / blockers

Числа ограничений/затухания — обратимые Inspector-настройки прототипа, не утверждённый баланс.
Rendered QA требует отдельного разрешения. Технически готовый пакет может разблокировать
потребителя до субъективной приёмки, но незавершённая миграция не становится DONE.
