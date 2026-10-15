# PVZ-B01 — ConfigFile для save/load и согласованный предел размера

Status: **IN_PROGRESS**
Priority: **P2**
Baseline: `dev` / `6aac58da7f03943aa62614ee3dbb1ad317747748`
Owner decision: запись содержимого сохранения выполняется через **ConfigFile**, не ручной FileAccess.
Implementation BASE_SHA: `01af39e1a126e0d1326e474e164efe10d24bfe1b`

Owner decision 2026-10-16: ConfigFile остаётся обязательным контейнером; данные могут предварительно сериализоваться в Dictionary/Array. Владелец явно принял ограничение native parser: запрет создания Objects самим ConfigFile.load снят, но после load требуется строгий отказ для любых Object в контейнере и запрет их передачи/использования в live World. Этот ответ заменяет прежний запрет parse-time Object construction ниже; безопасность parser до post-load gate не обещается.

## Task state

### Goal

Заменить ручной бинарный файловый контейнер нативным ConfigFile, устранить несовпадение ограничений writer/reader и сохранить безопасное восстановление, контроль повреждения, защиту слота и идемпотентный Night retry. Это полная миграция storage adapter, не обёртка старого бинарного формата.

## Evidence / scope

- [autosave_store.gd](../../content/domains/persistence/services/autosave_store.gd): write ограничивает payload, но read — весь файл с дополнительным заголовком. Базовый SCHEMA_VERSION = 19; MAX_BYTES = 64 MiB.
- [s_night_save.gd](../../content/domains/persistence/systems/s_night_save.gd): immutable prepared_snapshot и повтор записи. [night_save_service.gd](../../content/domains/persistence/services/night_save_service.gd): rejected_path и preflight/restore.
- Scope: AutosaveStore, реальные manual/autosave callers и slot handoff, SaveDataCodec/WorldSnapshotService только по затронутому контракту, C_Autosave, save fixtures/guards/tests и ближайшие docs.
- Базовый [native persistence test](../../tests/gut/test_refactoring_v2_persistence_baseline.gd) — регрессионная поверхность, а не доказательство уже выполненного PASS.

## Native format contract

1. Прочитать [save systems](../skills/save-systems/SKILL.md), [GECS](../skills/gecs-v8/SKILL.md), [style](../skills/gdscript-style/SKILL.md), [validation](../skills/validation-workflow/SKILL.md). Проверить API ConfigFile именно закреплённой сборки Godot; не выдумывать параметры из latest.
2. Формировать данные через `ConfigFile.set_value()`, сохранять через `ConfigFile.save(temp_path)`, читать новым экземпляром `ConfigFile.load(path)` и `get_value()`. Новый экземпляр на каждую попытку исключает примесь старых ключей после load/ошибки.
3. Минимальный целевой контейнер: секция `save`, ключи `format` (идентификатор ConfigFile-контейнера), `snapshot` (native Dictionary закрытого SaveDataCodec), `checksum` (SHA-256). `snapshot.version` остаётся единственным сохранённым значением версии gameplay schema; runtime source of truth — AutosaveStore.SCHEMA_VERSION.
4. Сохранять нативные значения snapshot: dictionaries/arrays, строки и допустимые числовые/геометрические значения. Не сериализовать SceneTree, живые Entity/Object/Resource/RID; сохранить whitelist, stable IDs и Definition paths. Native parser может создать Object до проверки — это явно принятое владельцем ограничение. Строго отклонять любые Object, включая вложенные значения/ключи и metadata типизированных коллекций, после load и до передачи данных в gameplay preflight/live World. Post-load проверку не называть безопасным парсингом.
5. Запрещены runtime `FileAccess.WRITE`, ручные store_line/store_buffer/store_var, сборка INI-текста конкатенацией, свой parser и legacy bytes_to_var reader. Запрещено помещать весь прежний binary/Base64 blob или JSON-строку в один ConfigFile key. Нативный PackedByteArray как легитимное отдельное поле не равен такому обходу.
6. FileAccess допустим только для existence/metadata/размера без чтения/записи содержимого save; raw byte I/O в тестах допустим для порчи fixture и доказательства сохранности файла. Не расширять исключение на production reader/writer. DirAccess используется для filesystem replace/cleanup, а не сериализации.
7. Не менять существующие пути `user://autosave.pvzh` и ручных слотов лишь ради суффикса: формат определяет ConfigFile, не расширение. Не вводить второй путь, молча обходящий защищённый старый слот.

## Integrity, size and write transaction

1. Сохранить контроль повреждения: checksum покрывает snapshot, включая schema, но не собственное поле checksum. Канонизацию построить на нативном ConfigFile-представлении допустимых данных, без второго самописного serializer. Проверить устойчивость encode → parse → encode, Unicode, порядок ключей и реальные numeric/native types. Не удалять checksum только ради упрощения миграции и не называть его защитой от умышленной подмены.
2. Определить единый `MAX_FILE_BYTES = 64 * 1024 * 1024` для полного UTF-8 контейнера, включая секции, metadata и checksum. Writer проверяет размер фактического ConfigFile-представления до замены; reader проверяет тот же предел до загрузки чрезмерного файла. Нельзя сравнивать bytes payload с characters/размером полного файла или просто увеличить старую константу.
3. `encode_to_text().to_utf8_buffer().size()` допустим для вычисления размера; запись этого текста вручную запрещена. На используемой сборке подтвердить соответствие этой величины фактическому файлу. Ограничение размера файла не выдавать за полный memory/time budget parser.
4. Сначала построить и проверить detached snapshot/container, затем `ConfigFile.save()` во временный файл в той же директории. При любой ошибке вернуть реальный Error, не выставлять сохранение успешным.
5. До замены перечитать временный файл нативным ConfigFile; проверить envelope/checksum/размер и сохранность допустимых значений. Полный gameplay preflight остаётся у существующего snapshot owner, не переносится в файловый adapter.
6. После успешных проверок выполнить replace через DirAccess с обработкой Error. Не удалять рабочий слот до успешной замены и не обнулять его при отказе. Удалять разрешено только принадлежащий этой попытке временный файл. Проверить поведение замены на целевой ОС; не обещать универсальную power-loss durability только на основании успешного rename.
7. Night повторяет запись того же C_Autosave.prepared_snapshot: без повторного capture, подготовки утра, RNG, replacement IDs, выплат и штрафов. Gameplay ticks могут быть заморожены; operational retry остаётся в Storage.

## Incompatibility and restore

- Это несовместимый файловый формат. Повысить фактический SCHEMA_VERSION ровно для данной миграции; 20 подходит только если перед реализацией текущая версия всё ещё 19. Обновить golden/current-format fixtures и save-visible inventory, не разбрасывать независимые значения версии.
- Старый PVZH1 binary и неподдерживаемые схемы отклоняются без конвертации. Не оставлять fallback reader/writer, aliases и второй активный формат.
- Нераспознаваемый/повреждённый существующий файл отличается от отсутствующего: сохранить его и установить защиту rejected_path. Следующий Night и выбранный manual slot не могут молча его перезаписать. Замена — только через существующее явное решение New Game/replace либо другой выбранный слот.
- Unsupported/newer schema, плохие типы/ID/required keys/checksum/links отклоняются до live mutation. Сохранить passive construction, preflight, восстановление связей после endpoints и ready boundary. Ни один Object из native parser не передаётся в gameplay preflight/live World.
- Existing write/Error и read/snapshot callers мигрировать согласованно. Не вводить универсальную storage framework, шифрование, cloud saves, autosave threads или old-save migration в этой задаче.

## Acceptance / focused regressions

- [ ] Save действительно создаётся ConfigFile.save и читается ConfigFile.load; отсутствуют production ручной writer и спрятанный binary payload.
- [ ] Native roundtrip проходит на реальном current-format snapshot: schema/IDs/Definition subresources, dormant NPC, health/inventory, durable links, время и RNG-состояние сохраняются по их контрактам.
- [ ] Границы L-1/L/L+1 для полного файла проверены с тем же size guard; как минимум допустимая граничная запись реально читается ConfigFile. Допустим параметризованный малый test limit, но одного арифметического теста без native save/load недостаточно.
- [ ] Unicode и escape-heavy строки учитываются в UTF-8 bytes; увеличение metadata/checksum не делает принятую запись нечитаемой.
- [ ] Empty/truncated/malformed config, missing/invalid keys, checksum mismatch, excessive file и unsupported schema безопасно отклоняются без изменения live World.
- [ ] Error записи временного файла, ошибка readback и отказ replace сохраняют прежний рабочий слот; повторная попытка завершается на том же prepared snapshot.
- [ ] Старый binary слот и newer schema сохраняются побайтно после отказа startup и следующего Night; явное разрешение замены работает. Не создавать legacy converter для теста старого формата.
- [ ] Реальный non-visual save → fresh session/load восстанавливает утро; повтор Night не дублирует деньги, district preparation и identities.
- [ ] Применение storage format не меняет gameplay authority, стабильные resource paths и смысл текущих сохранённых полей.

### Validation

Focused native GUT на AutosaveStore/ConfigFile и существующий persistence baseline; дополнить только отсутствующие сценарии. Parser/formatter и необходимые schema/inventory/structure/architecture checks выполнить после связного изменения. Один Night failure → retry → fresh-load smoke на milestone; не гонять всю игру/весь suite после каждого edit. Все тесты используют изолированные `user://` слоты, никогда пользовательский default autosave.

Краткий актуальный формат/ошибки описать в docs при завершении этого этапа; полная очистка [PVZ-A03](pvz_a03_persistence_documentation.md) следует за реализацией. Официальные API: [ConfigFile](https://docs.godotengine.org/en/stable/classes/class_configfile.html), [DirAccess](https://docs.godotengine.org/en/stable/classes/class_diraccess.html); первична проверенная сборка проекта.


### Current
Проверен native API Godot 4.7.1-stable (official) из проекта. Изолированный [probe](../../tests/tools/configfile_native_probe.gd) подтверждает создание RefCounted внутри Dictionary при ConfigFile.load; запрета Objects в аргументах load/parse нет. Владелец принял это ограничение и разрешил строгий post-load gate. Исходный blocker снят его явным решением; начинается миграция единственного storage owner.

### Next
Реализовать единственный ConfigFile storage путь, полный UTF-8 size guard, canonical checksum, temp native readback и replace. Повысить schema 19 → 20 и согласовать fixtures. Запустить focused native storage/persistence регрессии и один Night retry/fresh-load smoke, затем immutable commit/review/triage.

### Owner QA / blockers

- **OWNER_ACCEPTED_LIMITATION**: ConfigFile.load создаёт Objects до schema/checksum gate. Probe использует безвредный RefCounted и отдельные user:// файлы, удаляемые после проверки; пользовательские слоты не затрагиваются. Нельзя объявлять безопасность native parser PASS на основании последующего отказа в preflight.
- **PASS (API evidence only)**: native roundtrip Dictionary с Unicode/escapes/native types, целочисленным значением >2^53; encode → load → encode; размер текста и файла 301 bytes; temp replace существующего файла и readback. Это не проверка всего gameplay snapshot или полного acceptance.
- **PASS (execution)**: прямой headless `--script res://tests/tools/configfile_native_probe.gd`, exit 0, stderr пустой; `.artifacts/godot_agent/configfile-probe-20261015-160621587.stdout.log`. `object_created_by_load=true`, `decoded_object_class=RefCounted`, native API load/parse имеют только path/data.
- Первый запуск через OfflineScript включал headless editor; scan был прерван ранним quit, runner **FAIL**, несмотря на exit 0. Логи сохранены: `.artifacts/godot_agent/offlinescript-20261015-160232413.stdout.log` / `.stderr.log`. Повтор без editor не воспроизвёл shutdown errors. Первый запуск не объявляется PASS.
- Research review **PASS**: `/root/review_cal01`, BASE_SHA `ce771d1bc75256742c64f5e7459a67f3f0060f1a`, TARGET_SHA `160ab9c9caa872ccb748ab0fc1d64bdd21c15b7b`; no material findings, architecture/style PASS. Main triage: открытых принятых P0/P1/P2 нет. Implementation review ещё **NOT_RUN**.
- Implementation/GUT/integration **NOT_RUN**; gameplay/visual **NOT_RUN**, 0/8.

### Dependencies / completion
Независима от UI и календарного refactor; после [PVZ-CAL01](completed/pvz_customers_calendar_fact_ownership.md)/[PVZ-A02](completed/pvz_a02_wallet_day_events.md) проверить совместный Night startup/settlement contract. Соблюдать [AGENTS.md](../../AGENTS.md) и [task lifecycle](../skills/task-lifecycle/SKILL.md): без GitHub Actions/gh, неразрешённых visual playtests и сторонних addon edits. Полные base/target/review/fix SHA и реальные PASS/FAIL/NOT_RUN сохранять здесь; не более одного child agent одновременно. Неподтверждённую безопасность native parser/replace отмечать конкретным BLOCKED, не скрывать обходным ручным writer. После обязательных проверок/review — DONE и перенос этого же файла в `completed/` с исправлением ссылок.
