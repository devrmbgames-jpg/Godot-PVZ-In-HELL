# Скромник — взгляд, дискомфорт и настенный номер

Status: **PLANNED**
Technical: **NOT_STARTED**
Execution order: **110**
Reference baseline: `d6ea70fe8a00071ee9a5b57aa4a7e647e108ea27`
Source: [полное исходное ТЗ и доказательства](references/task-refactor-2026-10-17/shy_npc_gaze_discomfort_and_wall_order.md.txt).

Эта карточка владеет текущим исполнением. Полный объём требований сохранён в Source;
правила чтения и автономного продолжения — в [README](README.md).


## Goal / acceptance

Опасный удержанный взгляд предупреждается нарастающим краевым эффектом; быстрый NPC
избегает прямого взгляда, не копируя Ангела/Жуткого. Настенная отметка показывает
настоящий номер заказа, поиск и выдача работают. Просрочка вызывает недовольный уход,
изменение отношения и возможную жалобу, но сама по себе НЕ вызывает атаку.
Полные camera/LOS, UI/reduced-motion, номер/сроки, lifecycle и сохранения Source обязательны.

## Current

Исследованы существующие gaze-aversion, trait exposure, HUD/shader и legacy wall clue.
Наличие shader/старого испытания не доказывает реализацию поведения районного Скромника.
Новые код/сцены/проверки не выполнены; сроки/силы — гипотезы прототипа.

## Work packages

| Пакет | Проверяемый результат |
| --- | --- |
| S1 | Настоящий взгляд → единая exposure/предупреждение → однократная эскалация; манёвр сохраняет очередь/резерв. |
| S2 | HUD read-only отображает дискомфорт, совместимый с текущими эффектами и reduced_motion; допустимые native настройки. |
| S3 | Настенный собственный номер, окно поиска, общий handoff и timeout/жалоба/отношение без атаки за просрочку; cleanup и restore. |

S2 не владеет экспозицией/атакой; S3 не создаёт отдельную выдачу. Каждый пакет включает
свои технические проверки, а не постоянный полный suite всех хоррор-NPC.

## Entry points / dependency gates

DEF_NpcGazeAversion/NpcGazeAversionSolver, S_NpcTraits, InteractionHud,
GazeChallengePresentation/GazeOrderCluePresentation, CustomerPresentation/CustomerOutcomeService.
Использовать [общий handoff](automatic_parcel_handover_and_wrong_recipient_reactions.md),
[агрессию](npc_aggression_evidence_and_incident_investigation.md) и единого relation writer
[PVZ-NPC01](npc_perception_relationship_graph_and_social_planning.md) по готовым контрактам.
Проверка камеры игрока не заменяется зрением NPC; физику из BT не переписывать.

## Next

Выполнить S1 на актуальном trait owner с детерминированными camera/LOS fixtures,
сохранив service/emergency приоритеты. Затем S2/S3 без запроса продолжения каждого шага.

## Validation / review

Новые runtime/review NOT_RUN. Видимость/периферия/стена, накопление и спад exposure,
граница эскалации, повторный callback, смена роли/смерть, очередь/настоящий номер,
timeout без атаки, жалоба без дубля, старое испытание и fresh restore.
Шейдерная компиляция/свойства не доказывают комфорт или читаемость.

## Owner QA / blockers

Полная субъективная приёмка и финальные значения остаются открытыми до разрешённого
плейтеста; не использовать разрешение автовыдачи для проверки дискомфорта Скромника.
