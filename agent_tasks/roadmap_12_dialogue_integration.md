# R12 — Диалоги, условия и загадка

Status: **PLANNED**

## Task state

### Goal
Подключить диалоговый слой к gameplay без переноса authority в текст/UI.

### Constraints / acceptance
- This is a Feature-level tracked task.
- Зависимости: R02, R11, R11.1
- Reuse existing authoritative contracts from completed dependencies; do not duplicate them.
- The existing `## Работы`, `## Критерии готовности`, `## Проверки`, and `## Границы` sections remain the detailed implementation specification.
- Follow Godot 4.7, GECS ownership, physics authority, and validation rules from `AGENTS.md`.
- Dialogue response intent tags remain short internal metadata; visible test/debug prefixes are presentation only and must not change gameplay routing.

### Milestones
- [x] Reconfirm dependency completion and current production owners/contracts.
- [x] Implement the existing work checklist in small coherent milestones.
- [x] Review material changes and resolve all recorded R-findings.
- [x] Run final task validation according to the documented GUT/headless budget.
- [x] Record owner gameplay/visual QA.
- [ ] Add visible intent prefixes to tagged dialogue answers for testing/debugging.
- [ ] Validate that displayed prefixes do not alter response tags or gameplay intent.

### Decisions
Do not create a parallel planning document. This file remains the authoritative state/router for the feature; source design docs are references, not task state.

DialogueManager response tags remain compact authoring metadata. For testing, the project-owned dialogue presentation must prepend a human-readable intent marker to every tagged answer while preserving the original tag unchanged.

Required mapping:
- `hon` → `[честно]`
- `lie` → `[обман]`
- `prs` → `[убедить]`
- `thr` → `[угроза]`
- `flr` → `[флирт]`
- `jok` → `[шутка]`

Example: an authored answer with tag `lie` and text `Посылки ещё не было` is displayed as `[обман] Посылки ещё не было`. The visible prefix is not part of the gameplay tag and must not be parsed back as authority.

### Current
Base R12 implementation was completed on 2026-09-29. The task is reopened only for the dialogue-answer testability extension: tagged responses must visibly show their intent prefix. Existing dialogue/gameplay behavior remains authoritative and should not be rewritten for this change.

### Validation
- R1 (cyclic `CustomerDialogueService <-> CustomerDialoguePanel` class dependency) = **FIXED** by removing the panel-to-service reference.
- R2 (false `TAKEN` dialogue branch unreachable because R11 transitioned directly to Aggressive) = **FIXED**: R11 remains authority for the `visit.aggressive` decision, while R12 owns the reaction dialogue and invokes the bounded Aggressive receiver after complaint creation.
- Focused R12 GUT + `tests/smoke/customer_dialogue_smoke.tscn` = **PASS** in GitHub Actions on the original final R12 code.
- Owner gameplay QA in `main_level` = **PASS** on 2026-09-29.
- New visible intent-prefix extension: not yet implemented/validated.
- An unrelated editor resave removed existing GECS system `group` metadata from `main_level.tscn`; merge resolution intentionally keeps the current `master` scene instead of that accidental diff.

### Owner QA / blockers
After the intent-prefix extension:
- every tagged answer visibly shows the expected prefix;
- selecting the answer still forwards the original short tag (`hon/lie/prs/thr/flr/jok`);
- the prefix is not duplicated after reopening/rebuilding the dialogue UI;
- untagged answers remain unchanged.

---

Зависимости: R02, R11, R11.1
Ветка/base: `feature/r12-dialogue-integration` / `master@bd1e5a4d928084aa94b346e05a4ebe888dd5c9d1`.
Источники: [ТЗ 07](../docs/roadmap/07_customer_flow_and_delivery.md), [ТЗ 08](../docs/roadmap/08_customer_challenge_framework.md), [ТЗ 08.1](../docs/roadmap/08_1_arrangement_extended_interactions.md), [ТЗ 09](../docs/roadmap/09_dialogue_system.md).

## Цель

Подключить диалоговый слой к gameplay без переноса authority в текст/UI.

## Начать здесь

- [project.godot](../project.godot)
- [content/scenes/main_level.tscn](../content/scenes/main_level.tscn)

Затем прочитать контракты, созданные задачами-зависимостями. Имена новых типов из roadmap — проектируемые контракты, а не утверждение о существующих файлах.

## Работы

- [x] Оценить уже установленный DialogueManager 4.1.0 через локальный API; использовать его без изменения addons и без второго параллельного движка.
- [x] Добавить типизированный адаптер conditions/actions: фаза, Satisfaction, RequestedPackage, Package actual outcome, Terminal declaration, Complaint/dispute state, Opened/Damaged flags, результаты Challenge и будущий Hunger tier.
- [x] Собрать прямой диалог с номером и загадку с выбором/повтором/альтернативной веткой.
- [x] Действия диалога вызывают существующие gameplay-контракты; поддержать voluntary Customer refusal, delayed Complaint и обнаружение false `TAKEN` с переходом в Aggressive. Challenge/Aggressive подключаются через получателей, а не через циклическую зависимость реализации.
- [x] Разделить действительную реплику/переход и воспринимаемый текст для последующей Hunger distortion.
- [ ] Для каждого варианта ответа с intent-тегом показывать перед текстом тестовый префикс: `[честно]`, `[обман]`, `[убедить]`, `[угроза]`, `[флирт]`, `[шутка]` согласно тегам `hon/lie/prs/thr/flr/jok`. Префикс добавляется только на уровне presentation; сами теги и gameplay routing не менять.

## Критерии готовности

- Номер доступен через разговор, но поиск коробки остаётся задачей игрока.
- Неверный ответ влияет на Satisfaction и ветку; повтор/закрытие разговора не дублирует выдачу или событие.
- Тестировщик по тексту каждого tagged-ответа сразу видит тип намерения: например `[обман]` или `[убедить]`.
- Отображаемый префикс не меняет и не заменяет исходный DialogueManager tag.
- При повторном открытии/обновлении вариантов ответа префикс не дублируется.

## Проверки

GUT: conditions/actions и идемпотентность; mapping `hon/lie/prs/thr/flr/jok` → видимый префикс; сохранение исходного response tag после форматирования текста; отсутствие повторного префикса; integration прямого диалога и загадки; smoke закрытия при уходе/смерти NPC. Общие команды и правила завершения — в [README](README.md).

## Границы

Полная Hunger distortion — 18; не изменять плагин DialogueManager. Тестовые intent-префиксы реализовать в project-owned presentation/adapter слое, не правкой addon и не изменением authored gameplay tags. Сохранять Godot physics authority, GECS data/behavior boundaries и read-only addons. Выполненные основания переиспользовать, а не создавать заново.

## Первый шаг

Найти project-owned место, где response text превращается в UI-кнопку/вариант ответа, и добавить туда idempotent formatting по существующему response tag. Не менять DialogueManager addon и не переносить tag parsing в UI authority.
