# PVZ-NPC01 — восприятие, знание и единый граф отношений

Status: **PLANNED**
Technical: **NOT_STARTED**
Execution order: **80**
Reference baseline: `d6ea70fe8a00071ee9a5b57aa4a7e647e108ea27`
Source: [полное исходное ТЗ и доказательства](references/task-refactor-2026-10-17/npc_perception_relationship_graph_and_social_planning.md.txt).

Эта карточка владеет текущим исполнением. Полный объём требований сохранён в Source;
правила чтения и автономного продолжения — в [README](README.md).


## Goal / acceptance

Кандидат сенсора ≠ увиденный субъект ≠ распознанная личность ≠ отношение ≠ решение.
Ближние кандидаты 20 м, зрение персонажей до 100 м, полный угол 90°; никаких скрытых
координат или неявного зрения затылком. Охват всех живых production NPC, бюджет и
справедливость sensing, направленные связи, память и социальные потребители — весь Source.

## Current

Это функциональная архитектурная задача, не только performance fix. Реализации нет.
Выявлены пересечения с society/03 и отложенным ConfigFile. Ни один из этих планов
не считать уже работающей системой; исходный baseline в Source — исторический.

## Shared contract / precedence

Один typed-граф под NpcRecord/C_District и один writer. Эта задача владеет storage,
knowledge/sensing API и миграцией потребителей; [society/03](npc_living_society/03_relationships_and_social_actions.md)
владеет социальными эффектами/встречами и использует тот же граф.
Её симпатия, доверие, страх и уважение не должны потеряться из-за предложенного в Source
трёхосевого минимума. Hostility/обвинение остаются независимыми от страха и симпатии;
до записи схемы определить их единственный источник и чтение боевым поведением.
Не создавать две конкурирующие модели и не объявлять dislike автоматически нападением.
ConfigFile B01 явно DEFERRED: использовать фактически поддерживаемый storage/codec,
а не ждать миграцию и не внедрять отдельный файл социальных данных.

## Work packages

| Пакет | Проверяемый результат |
| --- | --- |
| V1 | Согласованный identity/knowledge/relation контракт и один native sensing provider на пилоте с настоящими бюджетными измерениями. |
| V2 | Зрение/узнавание/память и единый граф с однократными событиями, безопасным save-load и ограниченной историей. |
| V3 | Все указанные в Source потребители/сцены переведены; old all-pairs обходы и скрытые позиции не обходят новый API/бюджет. |
| V4 | Итоговая плотная группа/район, fairness/starvation и lifecycle/regression матрица полного Source. |

Каждый пакет содержит свой минимальный тестовый результат. V4 не откладывает
базовую проверку корректности V1–V3 и не является обязательным полным прогоном после каждого edit.

## Entry points / dependency gates

S_NpcIntent, S_NpcPerception, NpcPerceptionService, NpcSocialService,
NpcCommunityService, NpcRecord, C_NpcAwareness, DEF_NpcProfile.
[CharacterBody P3](npc_characterbody_and_bounded_impact.md) даёт production spatial/eye bindings;
[жители R1](district_authored_residents_and_resurrection.md) — stable ID, не весь авторский состав.
Интерфейс свидетельств согласовать с [агрессией](npc_aggression_evidence_and_incident_investigation.md)
в V1; не ждать её полной реализации. Society/03 — спецификация/потребитель, не обратная runtime-зависимость.

## Next

Выполнить V1 на актуальных owners: закрыть единую модель данных и выбрать один provider
по реальному пилоту. До массового переноса сцен не принимать оптимизацию по одному Big-O рассуждению.

## Validation / review

Новые runtime/performance/review NOT_RUN; производительность NOT_MEASURED.
Полная матрица Source обязательна: асимметричное зрение, FOV/LOS/дальности, исчезновение
тела, незнакомство без создания записи, дедупликация событий, отсутствие скрытых координат,
бюджет/справедливость, сцены клиентов/гостей и fresh restore. Изменённые consumers проверяются при миграции.

## Owner QA / blockers

Авторские исключения зрения явные. Численные социальные веса — tuning, не новый баланс.
Rendered QA отдельно. Открытый B01 не блокирует эту задачу и не разрешает менять формат save.
