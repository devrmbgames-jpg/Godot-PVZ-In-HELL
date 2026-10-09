# Эксперимент PVZ: Continuous Review + Fix Triage

**Область:** только Godot-PVZ-In-HELL, ветка эксперимента от `dev`.
Для Kidduca подход пока не включать. GitHub — транзит для исходников,
а не CI/менеджер задач. **Main Agent** единственный редактор файлов;
**Reviewer** проверяет фиксированный Git commit в read-only режиме.
Отдельный Manager Agent и постоянно работающий демон не требуются.

## Выбор режима

| Режим | Review |
| --- | --- |
| Light: небольшой безопасный Fix | Короткий self-review и существующие локальные проверки |
| Normal: Feature / существенный Task | Параллельный Reviewer после логического commit |
| Deep: GECS/physics/save/refactoring | Review ключевых checkpoint и финальная архитектурная приёмка |
| Нет независимой работы/поддержки субагентов | Последовательный review; статус SERIAL, не притворяться параллельным |

Вне зависимости от размера, изменения authority, save, ownership и физического
lifecycle требуют независимой проверки, если Reviewer доступен.

## Протокол snapshot

1. Main завершает целостный шаг и коммитит только относящиеся к нему файлы.
2. Получает **полные SHA** `BASE_SHA` и `TARGET_SHA` (законченный commit).
3. Запускает один read-only Reviewer на `git diff BASE_SHA TARGET_SHA`.
   Reviewer берёт файлы как `git show TARGET_SHA:relative/path`; никакого
   анализа меняющейся рабочей директории. Нельзя checkout, Git restore,
   открывать Godot, вызывать MCP Editor, писать файлы и запускать GUT.
4. Main **не ждёт немедленно**, пока есть действительно независимая работа:
   тесты другой области, следующий не зависящий от checkpoint компонент,
   подготовка документов/фикстур. Нельзя продвигать зависимый дизайн
   без review предыдущего checkpoint.
5. Main получает review перед интеграцией и всегда перед статусом DONE;
   если HEAD уже изменился, проверяет актуальность каждого замечания на
   новой версии. Reviewer никогда не добавляет задачи в репозиторий.

`max_concurrent_threads_per_session = 2` сейчас задаёт максимальную вместимость,
а не разрешение на двух параллельных reviewer. Main не входит в лимит детей.
Для пилота одновременно работает **один read-only Reviewer** и Main;
Validator, другие субагенты и операции с общим состоянием Godot выполняются
последовательно. Значение `2` не обязывает создавать второго агента.
Если неблокирующий reviewer недоступен, используйте serial fallback,
а не обходные shell-запуски модели.

## Main Agent = Review Manager

Reviewer возвращает **R1, R2...** (временные номера), приоритет,
`TARGET_SHA:path:line`/symbol, доказательство, нарушенный контракт GECS/
Godot, наименьшее исправление и targeted проверку. Main проверяет факт,
выясняет, не было ли уже исправления, объединяет дубликаты по
`path + symbol + invariant`, назначает канонический `RV-001` и принимает
решение о дальнейших действиях.

| Уровень | Пример | Решение |
| --- | --- | --- |
| P0 | Потеря save, доверенная authority, security | Немедленно остановить зависимую работу |
| P1 | Неправильный GECS scheduler, критическая регрессия | Исправить до зависимого этапа |
| P2 | Новая God Class, неправильная ownership или Code Style | Исправить до DONE milestone |
| P3 | Безопасный cleanup | Объединить с соседней работой или DEFERRED |

Состояния: `REVIEW_PENDING`, `ACCEPTED`, `FIXED`, `REJECTED`,
`OBSOLETE`, `DEFERRED`, `BLOCKED`.
Обязательная точка приёмки: нет ожидаемого ревью и нет открытых **принятых**
P0/P1/P2. У P3 и любого отказа должна быть конкретная причина.
Форматтер и GUT не могут «отменить» архитектурный blocker.

Никакой глобальной очереди. Если задача уже находится в `agent_tasks/`,
сохранить findings в **её же** разделе `## Review findings`. Новую задачу
можно завести только для действительно независимого out-of-scope дефекта,
который имеет собственные критерии приёмки. Для обычного одноразового Fix
отдельный task-файл не создавать.

### Пример секции в текущем durable task

```md
## Review findings
Checkpoint: BASE_SHA=<40 hex>, TARGET_SHA=<40 hex>
Review state: TRIAGED

- RV-001 | P1 | ACCEPTED
  Evidence: TARGET_SHA:content/domains/npc/systems/s_example.gd:85
  Contract: scheduled code must be owned by System, not Service.tick()
  Owner: Main Agent
  Fix commit: <sha after repair>
  Verification: focused GUT + validate_architecture --strict → PASS/FAIL/NOT_RUN
- RV-002 | P3 | DEFERRED
  Evidence: TARGET_SHA:content/ui/example.gd:42
  Reason: cosmetic cleanup outside the accepted milestone
  Follow-up: <task or responsible owner>
```

Reviewer пишет только временные R1/R2 в свой ответ; этот раздел обновляет
исключительно Main Agent. Повторные замечания связываются с тем же RV-ID.

## Bounded repair loop

Main исправляет принятые ошибки отдельным осмысленным commit, проверяет
конкретный контракт локальными validators, Godot parser и focused GUT (где
нужно). Отдельный Validator запускается последовательно после Reviewer.
Точечный повторный review рассматривает только исправление + исходную ошибку.
После **двух** неуспешных целевых циклов не запускать третий автоматически:
поставить `BLOCKED`, записать причину и возможные варианты решения.

## Как оценить эксперимент

Для 2–3 достаточно похожих по масштабу checkpoint измерять end-to-end
время, сколько времени проверки перекрылось независимой работой, доступные
token/usage, принятые/ложные/устаревшие замечания и количество repair loops.
`NOT_MEASURED` — честный результат при отсутствии телеметрии. Не считать,
что параллельность всегда уменьшает токены или время.

**Промпты:** [docs/ai_prompt_cheatsheet.md](ai_prompt_cheatsheet.md#параллельный-review-пилот-pvz).
