# PVZ-A03 — Актуальный контракт сохранений вместо смешанной истории

Status: **PLANNED**
Priority: **P2**
Baseline: `dev` / `6aac58da7f03943aa62614ee3dbb1ad317747748`
Dependencies: [PVZ-B01](pvz_b01_configfile_save_storage.md), [PVZ-CAL01](pvz_customers_calendar_fact_ownership.md), [PVZ-A02](pvz_a02_wallet_day_events.md)

## Task state

### Goal

Сделать документацию Persistence достоверным описанием текущей реализации после ConfigFile/календарных исправлений. Разработчик должен понимать поддерживаемый формат, владельцев, точки commit/flush и поведение при отказе, не восстанавливая порядок десятков исторических миграций.

## Evidence / scope

- В [docs/persistence.md](../../docs/persistence.md) соседствуют описания текущих schema 9/10 и этапов миграции. На audit baseline [AutosaveStore.SCHEMA_VERSION](../../content/domains/persistence/services/autosave_store.gd) равен 19.
- Это не поручение заменить все старые числа на 19/20. После PVZ-B01 актуален фактический versioned ConfigFile contract, а полные исторические SHA/версии остаются историей.
- Scope: docs/persistence.md, связанные действующие разделы [content/ARCHITECTURE.md](../../content/ARCHITECTURE.md), навигация docs и ссылки на актуальные owners/tests. Исправить непосредственно связанные ошибочные doc comments; изменение runtime поведения не входит в эту задачу.
- Completed task records и provenance `sources` в domain_contracts.json не являются текущей спецификацией и не должны массово переписываться.

## Required approach

1. Прочитать [save systems](../skills/save-systems/SKILL.md), [task lifecycle](../skills/task-lifecycle/SKILL.md), [validation](../skills/validation-workflow/SKILL.md). Перед финальным редактированием снять полные SHA реализованных зависимостей и актуальных source owners.
2. Сверить документ с AutosaveStore, SaveDataCodec, WorldSnapshotService, NightSaveService/S_NightSave, C_Autosave, реальной startup composition, DayPhase и новым wallet/planning contract. Отличать код/запущенные проверки от описания намерений и старых PASS.
3. Переписать основной документ как текущую спецификацию: purpose и boundary; контейнер ConfigFile; schema/limits/integrity; сохранённые данные и stable IDs; Night capture/retry; preflight/restore; ошибки и rejected slot; тестирование и короткие примеры.
4. Версия схемы имеет один программный источник — AutosaveStore.SCHEMA_VERSION. В повествовательном тексте ссылаться на него, а не поддерживать несколько независимых «now/current schema N». Для необходимого числового примера указать проверенный SHA/контекст и добавить точечную проверку соответствия.
5. Описать ConfigFile.save/load, полный UTF-8 size limit, checksum, временный файл и replace ровно в реализованном виде. Не называть файл бинарным PVZH1, не обещать flush/fsync, полную power-loss защиту, rollback и old-save conversion, которых API/код не гарантируют.
6. Чётко разделить: write accepted/completed/error; file parsed против schema/semantic validation; rejected existing slot против missing slot; passive construction против live publication. Указать, когда выставляются night_ready/last_saved_morning и какие outcomes видны до capture.
7. Дать компактную таблицу authority: persistent identity/records, body-owned state, durable Relationship endpoints, rebuild-only caches. Показать actual clock/group/flush order; не оставлять прежнюю цепочку, где S_WalletDay ещё существует или Customers публикует календарный переход ради bootstrap.
8. Добавить два небольших проверяемых примера: безопасный ConfigFile roundtrip на изолированном `user://` слоте через действующий store API; несовместимый/повреждённый слот отклоняется и не перезаписывается следующим Night. Примеры не обходят whitelist/preflight и не используют default user autosave.
9. Удалить из текущего повествования закрытые migration TODO/Phase baseline и устаревшие paths. Ссылаться на Git/существующие archived задачи для истории; не переносить весь старый журнал в новый отчёт. Исторически полезный фрагмент допустим лишь с явной маркировкой history и pinned source.
10. Устранить дублирующие описания между ARCHITECTURE и persistence.md: общий документ владеет общей ролью/порядком, профильный — деталями save. Отдельно подтвердить необходимые live links и native resource/subresource identities по текущим fixtures.

## Acceptance

- [ ] В актуальных разделах нет противоречащих друг другу текущих схем, действующих legacy paths и закрытых TODO, выдаваемых за обязательную новую работу.
- [ ] Версия, формат, полный предел размера и storage/error contract соответствуют коду после PVZ-B01; нет обещания legacy converter или удаления старого файла.
- [ ] Startup, passive restore, customer reconciliation, wallet settlement и Night capture описаны в фактическом порядке с понятными owner/flush boundaries.
- [ ] Ясно, что сохраняется, что восстанавливается по stable IDs, а что пересобирается и не является второй mutable authority.
- [ ] Новый разработчик по документу находит supported schema, условия safe save, причины rejection, защиту следующего Night и конкретные тесты без чтения истории миграции.
- [ ] Примеры соответствуют реальному API, используют изолированные слоты и не требуют несуществующих методов/flags.
- [ ] Все новые/изменённые ссылки проверены; архивы и provenance не переписаны как действующий код.

### Validation

Для docs-only изменений: link/path/symbol checks, поиск противоречащих current-version утверждений и ручная сверка с pinned source. Проверить GDScript snippets native parser/целевым тестом, когда пример содержит исполняемый код. Полный gameplay/GUT прогон из-за редакторской правки не требуется.

Точечный schema/document consistency check допустим в существующем tooling; не создавать универсальный генератор документации, второй metadata registry или механическую массовую замену чисел/путей. Статический PASS не доказывает истинность всего текста: каждый описанный контракт сверяется с владельцем реализации.

Документацию обновлять связной milestone-итерацией после изменившегося контракта; не запускать этот полный аудит после каждой мелкой code change.


### Current
ТЗ подготовлено. Финальная версия ConfigFile ещё не реализована в рамках этих задач; documentation fix/review: **NOT_RUN**.

### Next
После implementation dependencies зафиксировать их полные SHA, составить краткий список противоречий и переписать текущий контракт по исходникам.

### Dependencies / exclusions
PVZ-B01 обновляет минимальную документацию своего изменения сразу; эта задача делает итоговую очистку/согласование, не откладывая обязательную документацию кода. [Качество документирования](pvz_code_documentation_quality.md) использует получившийся контракт и не ведёт вторую копию. UI/NPC performance, архитектурный rewrite и смена правил compatibility вне scope.

### Owner QA / blockers

### Completion
Следовать [AGENTS.md](../../AGENTS.md) и task-lifecycle; GitHub Actions/gh не запускать. Зафиксировать full base/target/review SHA, проверенные source owners, реальные PASS/FAIL/NOT_RUN и unresolved discrepancies в этом файле. Не более одного child agent одновременно. DONE только при согласованном текущем документе; затем перенести этот же файл в `completed/` и исправить ссылки без дубликата/журнала.
