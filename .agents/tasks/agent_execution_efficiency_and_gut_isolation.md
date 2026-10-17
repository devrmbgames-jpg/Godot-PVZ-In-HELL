# AGENT-PERF01 — ускорение автономной разработки и изоляция GUT-тестов

Status: **PLANNED**
Technical: **NOT_STARTED**
Execution order: **15**
Reference baseline: `4c8a846f288fc2d0aa2296089bcb3bc517206630` (dev, 2026-10-17).

## Goal / acceptance

Устранить повторные GUT-прогоны и снизить число переделок в автономной разработке,
**не** сокращая игровые гарантии, обязательное ревью и релевантные проверки.

- Самостоятельные `test_*.gd` запускают собственные тесты, не наследуют
  тестовые методы других suites; общие setup/teardown вынесены в helpers.
- Перед крупной механикой агент кратко фиксирует результат, state owner,
  неизменяемые гарантии, реальные зависимости/потребителей, исключения и
  focused acceptance. Мелкие fixes — без нового формального gate.
- При разрастании затрагиваемых подсистем — scope triage: существующий контракт,
  минимальное расширение provider для реального consumer или отдельный
  подтверждённый дефект, без спекулятивного переписывания соседей.
- На 2–3 checkpoint измерены реальные затраты, лишние тестовые вызовы и
  repair cycles. Недоступные данные — NOT_MEASURED, не выдуманное ускорение.

## Current / baseline

**Implementation NOT_STARTED.** Подсчёт исходников, не actual native PASS:

- `test_pvz_tool_orders.gd`: **5** собственных тестов, но цепочка через
  `test_hag_direct_shop.gd` (9) → `test_buyback_lifecycle.gd` (15) →
  `test_npc_life_cycle.gd` (9) → `test_npc_authored_population.gd` (7)
  даёт до **45** методов при выборе PVZ-suite.
- `test_crafting_lifecycle.gd`: **15** собственных и ещё 15+9+7
  унаследованных — до **46** методов. Числа/длительность подтвердить GUT.
- В [торговой задаче](district_resident_barter_and_buyback.md) ревью
  исправляло frozen crafting plan, постоянную личность NPC и сохранение
  старого ассортимента. Потраченные часы по ним **не измерены**.
- [Runner Q1/Q2](completed/godot_validation_result_classification.md)
  уже завершён: batch API без доказанной изоляции ECS/save/physics
  не вводить. Нынешние правила modularity/validation/review сохраняются.

## Work packages

| Пакет | Исполнение и критерии |
| --- | --- |
| E1 — audit | Проверить цепочки `extends`, setup/teardown и аналогичные проблемы в `tests/gut/`. Снять baseline native counts/elapsed либо явно NOT_RUN/NOT_MEASURED. |
| E2 — isolation | Изолировать commerce/NPC suites: общая подготовка — composable `tests/helpers/` или fixture без `test_*`; отдельные suites наследуют `GutTest`. PVZ tools исполняет 5 собственных тестов, crafting — 15; NPC, buyback, Hag доступны отдельно; исходные тесты не потеряны. |
| E3 — preflight | Применить до существенного кода действующий [modular-gameplay-design](../skills/modular-gameplay-design/SKILL.md); при необходимости минимально уточнить checklist в этом skill. В [gut-testing](../skills/gut-testing/SKILL.md) запретить наследование конкретных test suites. Новых обязательных документов нет. |
| E4 — scope | На следующем крупном пакете проверить один реальный случай выхода за ownership/contract; сохранить мотивированное решение об узкой интеграции/зависимости. Если случая нет — NOT_OBSERVED, не создавать искусственный refactor. |
| E5 — measurement | Снять данные на E2 и ещё 1–2 следующих доступных существенных checkpoint (всего 2–3), сравнить сопоставимые GUT runs до/после и расходы на review/repair/tools. Краткий вывод или обоснованное NO_CHANGE. |

## Implementation constraints

- Только `tests/gut/`, `tests/helpers/`, маленький guard при необходимости
  и относящиеся skills. **Не менять** production GECS/NPC/commerce/save/сцены,
  `AGENTS.md`, версию Godot/GUT, сторонние addons, GitHub Actions или backlog.
  Независимые gameplay дефекты оформлять у их owner с воспроизведением.
- Сохранить все исходные `test_*` и их смысл, `before_each/after_each`,
  native World/Entity lifecycle, `ECS.world`, async ожидания, реальные
  save/restore, `user://` cleanup и resource/physics isolation.
  Mock-only PASS не заменяет интеграцию; helpers не создают shared mutable state.
- Локальный fix → нарушенная гарантия; законченная механика → связанные
  consumers. Не запускать полный suite после каждой правки и не создавать
  универсальный test framework ради этого пакета.
- Scope triage не вводит лимит строк или файлов. Триггеры: чужой state owner,
  второе mutable authority, непредусмотренная миграция/широкая зависимость.
  Атомарную механику (оплата + выдача + cleanup/restore) не делить на
  неработающие части ради формально мелких коммитов.

## Verification / evidence

1. До/после E2 реально проверить 6 suites:
   `test_pvz_tool_orders.gd`, `test_crafting_lifecycle.gd`,
   `test_hag_direct_shop.gd`, `test_buyback_lifecycle.gd`,
   `test_npc_life_cycle.gd`, `test_npc_authored_population.gd`.
   Снять test cases + wall elapsed. Каждый собственный `test_*` остаётся
   доступен; в исправленной цепочке больше нет наследования test suites.
2. Focused native Godot GUT через `utils/godot_agent.ps1` и соразмерные
   formatter/agent/architecture/structure gates по
   [validation-workflow](../skills/validation-workflow/SKILL.md).
   Если Godot недоступен — NOT_RUN, а не static PASS.
3. Для E2/E3: coherent commit → read-only review точных SHA → triage →
   не более двух targeted repair/re-review циклов. Не выдавать pending review
   за PASS. Не делать rendered QA.
4. Для 2–3 checkpoint фиксировать `BASE_SHA..TARGET_SHA`, количество
   собственных/фактически выполненных tests, GUT elapsed и число запусков,
   accepted findings и repair cycles. Implementation/review/tool durations
   учитывать **только по реальным timestamps**, обозначать overlap,
   NOT_MEASURED и несопоставимость выборок; токены без telemetry не выдумывать.
5. **Одна компактная сводка здесь** + ссылки на обычные logs/result.json.
   Не создавать activity log, новый менеджер, daemon, watcher, CI или
   обязательные повторы тестов ради статистики.

## Entry points / dependencies

`tests/gut/test_npc_authored_population.gd`,
`test_npc_life_cycle.gd`, `test_buyback_lifecycle.gd`,
`test_hag_direct_shop.gd`, `test_pvz_tool_orders.gd`,
`test_crafting_lifecycle.gd`, `tests/helpers/`, `utils/godot_agent.ps1`;
[gut-testing](../skills/gut-testing/SKILL.md),
[modular-gameplay-design](../skills/modular-gameplay-design/SKILL.md),
[task-lifecycle](../skills/task-lifecycle/SKILL.md) и [task README](README.md).

Это самостоятельная оптимизация, **не** blocker остального backlog.
Уже начатый coherent checkpoint не прерывать; E4/E5 выполнять на следующих
доступных пакетах без остановки независимых игровых задач.

## Next

E1: инвентаризация inheritance/hooks, затем native baseline.
Далее E2 → E3; E4/E5 собирать на следующих разрешённых checkpoint.

## Validation / review

Создание ТЗ — docs-only; implementation/Godot/GUT/review **NOT_RUN**.
Сведения E1–E5 не считать реализованными до их фактической проверки.

## Owner QA / blockers

Rendered/visual QA не нужна. Нет Godot/таймингов/новых checkpoint — указать
точный NOT_RUN/NOT_MEASURED, продолжить независимую работу.
DONE только после обязательных пакетов, проверок и review/triage.
