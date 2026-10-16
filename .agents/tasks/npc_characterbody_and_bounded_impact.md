# НПЦ — CharacterBody3D и ограниченное отбрасывание

Status: **PLANNED**
Technical: **NOT_STARTED**
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

Есть план и чтение owners, но новая реализация/физическое воспроизведение не выполнены.
Подозрение о накоплении pending_rebound_velocity не считать доказанной причиной RigidBody-симптома.
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

Инвентаризировать только живые NPC-сцены и callers указанных owners, зафиксировать
исходные contact/impact гарантии и выполнить P1. До scene-edit проверить editor/MCP capability;
при необходимости применять разрешённый offline путь, не разворачивать инструментальный проект.

## Validation / review

Новые parser/GUT/runtime/review: NOT_RUN. Проверять total clamp, повторные контакты,
held/free переход, неподвижного/замороженного NPC, стены/опоры, player regression и fresh restore.
Один согласованный набор evidence на пакет; общий migration check на P3, не после каждого cast.

## Owner QA / blockers

Числа ограничений/затухания — обратимые Inspector-настройки прототипа, не утверждённый баланс.
Rendered QA требует отдельного разрешения. Технически готовый пакет может разблокировать
потребителя до субъективной приёмки, но незавершённая миграция не становится DONE.
