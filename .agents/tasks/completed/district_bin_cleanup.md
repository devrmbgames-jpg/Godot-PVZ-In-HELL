# Инструменты — освободить .bin от собственных скриптов

Status: **DONE**

Родительский этап: [Утренняя машина](district_morning_truck.md). Порядок выполнения: [общая задача](district_service_update.md).

Зависимости: [Сохранение — согласованный снимок и повтор ночной записи](district_save_schema_3.md).

## Task state

### Goal

Вынести из .bin установленные собственные проектные скрипты и smoke в соответствующие
каталоги; сохранить движок, шаблоны экспорта и используемые сторонние инструменты.

### Current

Завершено 2026-10-11. В `.bin` не было отдельных действующих собственных scripts/smoke:
они уже расположены в `utils/` и `tests/smoke/`. Найдены четыре project-owned каталога
с изолированными историческими snapshots; они целиком перемещены в
`.artifacts/godot_agent/.tmp/isolated_snapshots/` с прежними именами и содержимым:

- `direct_traits_baseline` — исходная копия для Direct Traits parity/performance.
- `retention_baseline_snapshot`, `retention_current_snapshot` — matched comparison.
- `retention_first_checkpoint` — отдельная более ранняя диагностическая копия.

Ничего не удалено. `.gdignore` исключает каталог из Godot imports; pinned Dialogue Manager
сканирует каталоги отдельно и игнорирует именно `.tmp`, поэтому одного `.gdignore`
недостаточно. Raw evidence и исторические reproduction commands сохранены. Текущие пути
записаны в [отложенной задаче](../cold_snapshot_resource_retention.md); новая retention
диагностика не запускалась.

Native `ProjectSettings` содержал 12 translation references в эти snapshots. Стандартный
MCP settings_set меняет PackedStringArray на JSON Array, поэтому добавлен узкий
проектный `pvz_translation_sources` через поддерживаемый registry. Native apply удаляет
только отсутствующие диалоги четырёх известных copies и их DMCache entries; сохраняет
авторские/custom источники, существующие файлы и тип настройки. Сторонние addons не менялись.

RV-001 закрыт: snapshots перенесены под `.tmp`, настоящий scanner и сохранённая настройка
проверены в новом headless процессе. Fix checkpoint и targeted re-review завершены.
Следующий этап — [итоговая интеграция](district_release_validation.md).

### Validation

PASS: ограниченный inventory до/после, абсолютные source/target пути внутри workspace,
отсутствие source reparse points и активных Godot процессов в этих snapshots.
Проверены сохранность четырёх каталогов, отсутствие их старых путей и наличие documented
probe/parser/save-data recipes в обеих сравнительных копиях.

SHA256 `project.godot` совпадает до/после: retention copies
`b56250e97531e1f18866a46ea5b725c8d43654e7e4a6f69c4f2e5ca78f30ec64`, Direct Traits
`1045058116a90b4752878f06307422c88ea84eb66fca14b4af3305860be8865a`.
PASS: `utils/godot_agent.ps1 -Action Version` → 4.7.1.stable.official.a13da4feb;
`.bin/gdscript-formatter.exe --version` → 0.26.2.

В `.bin` остались только два Godot binaries, formatter, `export_templates/`, `.gdignore`,
`.gitkeep` и служебный `.godot-editor.pid`. Действующие scripts и `res://`-ссылки не менялись;
для самого перемещения новый parser/GUT не требуется. Companion/scanner GUT PASS5/5,
34 asserts (`gut-20261010-143352784`); parser companion3/3
(`parsefiles-20261010-141447294`) и окончательного scanner test1/1
(`parsefiles-20261010-143355997`) PASS. Incremental formatter/lint, staged agent-change
gate, strict architecture и project structure PASS.
Live MCP preview/apply сохранил три исходных диалога и PackedStringArray; повторный apply
no-op. Open/unsaved scene report проверен, checksum main_menu не изменился.
ProjectSettings записан редактором; в source commit stage только translation hunk,
пользовательские editor_plugins/folder_colors сохранены вне commit.
Scanner regression проверяет обычный dialogue и копию под `.tmp`, фактический project scan
и persisted PackedStringArray без diagnostic refs. Четыре settings SHA256 повторно совпали
после окончательного перемещения. Проверки выполнены в текущем worktree с сохранёнными
user edits; immutable reviewer проверял source, тесты не запускал.
GUI editor restart NOT_RUN; native scanner/readback принят как автоматическое доказательство.
Проверки выполнены по [validation-workflow](../../skills/validation-workflow/SKILL.md).

### Owner QA / blockers

Блокеров и обязательной gameplay/visual QA для перемещения материалов нет. Редактор
проекта сохранён; неизвестные/сторонние файлы не удалялись. RV-001 FIXED и re-reviewed.

## Review findings

BASE_SHA: `fac3929b6041770ecddf6ea7eadeec7f10fba02a`.
TARGET_SHA: `e0758d54aca744e28e7969c46713458f817a6c72`.
Review state: COLLECTED / TRIAGED; targeted re-review complete.
Initial reviewer: ARCHITECTURE FAIL (RV-001), STYLE PASS, VALIDATION NOT_RUN.

- RV-001 (R1), P2, FIXED; fix owner: Main. `DMCache._get_dialogue_files_in_filesystem`
  в pinned `addons/dialogue_manager/utilities/dialogue_cache.gd` не читает `.gdignore`
  и исключает только `.godot`/`.tmp`. Исходное место под `.artifacts/godot_agent/`
  позволяет повторно найти 12 диагностических диалогов и вернуть их в POT sources.
  FIX_SHA: `d6ab946cd4704d9a78b8b13faf804878eb19978c`; сохранённые snapshots под `.tmp`,
  тест искусственного дерева, фактического project scan и persisted sources: GUT5/34 PASS.
  Third-party scanner не изменён. Targeted re-review BASE_SHA:
  `e0758d54aca744e28e7969c46713458f817a6c72`, TARGET_SHA:
  `d6ab946cd4704d9a78b8b13faf804878eb19978c`; ARCHITECTURE/STYLE PASS, новых material
  findings нет, reviewer VALIDATION NOT_RUN. Один repair/re-review cycle.

## Границы и владельцы

- Только установленные собственные вспомогательные файлы в `.bin`, действующие инструменты
  в `utils/`/`tests/smoke/` и сохранённые snapshots под `.artifacts/godot_agent/.tmp/`.
- Прямые актуальные вызовы/ссылки перемещаемых инструментов.
- Узкий project-owned companion для native PackedStringArray cleanup, его focused GUT,
  README и только затронутая настройка translation sources в `project.godot`.

## Работы

- [x] Составить ограниченный список собственных инструментов и временных материалов; не считать каждый неизвестный файл мусором.
- [x] Полезные инструменты перенести в utils, сценарии — в tests/smoke; обновить только действующие ссылки.
- [x] Удалять только установленный ненужный task-scoped список после проверки абсолютных
  путей внутри каталога. Evidence/логи deferred engine retention сначала сохранить в
  согласованном месте и обновить действующие ссылки; общий purge `.bin` запрещён.
- [x] Сохранить бинарники движка, экспортные шаблоны и чужие материалы. Не переписывать завершённые задачи ради исторических путей.
- [x] Сохранить pinned `gdscript-formatter` и другие установленные зависимости инструментов:
  `utils/check_gdscript_format.py` использует `.bin/gdscript-formatter.exe`.
  Это сторонний исполняемый инструмент, а не собственный временный скрипт.
- [x] Проверить exclusion через настоящий Dialogue Manager scanner и свежий процесс:
  диагностические copies не возвращаются, авторские источники и PackedStringArray сохранены.
- [x] Закрыть RV-001 с fix SHA, фактическими parser/GUT results и targeted re-review;
  затем DONE/архивирование одним completion batch с обновлением входящих ссылок.

## Критерии завершения

- В .bin нет установленных собственных скриптов/временных материалов; движок и шаблоны сохранены.
- Актуальные команды работают с новыми путями.
- Диагностические диалоги не возвращаются в translation sources при новом сканировании;
  принятые review findings закрыты, результаты проверок записаны.

Выполнять только этот ограниченный результат, объединяя связанные чтения, правки и проверки. Не расширять задачу соседними функциями. Закрыть её собственные Status/Current/Validation, сохранить связный результат коммитом и обновить следующее действие в общей задаче. Завершение этой задачи само по себе не закрывает родительский этап.
