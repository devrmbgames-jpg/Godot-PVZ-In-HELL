# Машина — возвраты, дешёвая продажа и утилизация

Status: **DONE** — принято владельцем 2026-10-15.

Родительский этап: [Утренняя машина](district_morning_truck.md). Порядок выполнения: [общая задача](district_service_update.md).

Зависимости: [Машина — разгрузка и условия начала смены](district_truck_shift_gate.md).

## Task state

### Goal

При начале смены однократно обработать фактически загруженные возвраты и свободное имущество, оставляя возможность забрать их до отъезда.

### Current

**Завершено: владелец принял результат 2026-10-15.** Новые замечания и запланированные доработки сохраняют собственный незавершённый статус.

Техническая контрольная точка до ручной приёмки; прежние пометки ожидания OWNER_QA ниже закрыты решением владельца:

Подключена явная `TruckCargoService.commit` до отправления и смены MORNING. Общий
`PackageReturnService.return_package` сохраняет расчёт отказа; `return_held` остаётся
адаптером. `C_Receiving` хранит состав/историю `TruckCargoReceipt`; деньги проверяются
на копии кошелька до удаления и рассчитываются после него. Повтор/restore завершает
неоплаченную удалённую запись без повторного удаления. Цена стека использует авторский
`DEF_Delivery.truck_resale_percent`, доход имеет собственный Reason и подпись терминала.
Схема теперь 12, codec/manifest/golden fixture обновлены без миграции старых файлов.

Размещённый `PackageReturnPoint` удалён через редактор из main_level и primitive_test_level;
API и compatibility prefabs сохраняются для existing callers/tests. Native save нормализовал
сериализацию и добавил ранее отсутствующие engine unique IDs; существующие authored IDs сохранены.

Свободные raw/scriptless RigidBody3D входят в тот же журнал с отдельным `raw_actor_id`.
Grab-proxy удаляется штатным GECS lifecycle; детали Entity-механизмов, frozen/no_carry и
удерживаемые тела исключены. Native placements main/primitive получили стабильные группы
`raw_actor/placed/<UUID>` через редактор. Снимок сохраняет наличие/позу по ID; авторская
PackedScene даёт рецепт восстановления. Более ранняя загрузка возвращает предмет,
поздняя удаляет его в новой сцене. NodePath/instance ID и proxy не сериализуются.
Для ad-hoc runtime тела без авторского рецепта есть только ID транзакции: unfinished
утилизация такого тела отклоняется preflight, завершённая запись сохраняется.

Реализация и review/triage завершены. **Следующее:** обязательная ручная приёмка владельца
по QA-чеклисту; DONE/архивирование до неё не выполнять. Общая реализация продолжается
в задаче [итоговой интеграции](district_release_validation.md); gates
[инструментов](district_bin_cleanup.md) и snapshot review/triage закрыты.

### Validation

- PASS: cargo GUT 22/22, 149 asserts (`gut-20261010-125752299`); package_return 5/5,
  42 asserts (`gut-20261010-121058797`); truck_shift_gate 26/26, 177 asserts (`gut-20261010-120659710`).
- PASS: headless truck_shift_gate smoke (`tests/artifacts/truck_shift_gate-20261010-224806984.log`)
  с food_pickup, native barrel/proxy и scheduled START_SHIFT: удаление, +7, повтор без выплаты.
- Persistence GUT: 5/5, 336 asserts, exit 0 (`gut-20261010-124810620`), но runner FAIL
  из-за shutdown-only Resource/RID retention. `KNOWN_ENGINE_LIMITATION / DEFERRED` по политике;
  полный лог сохранён, не выдавать wrapper FAIL за PASS.
- PASS: production/cargo/smoke parser 9/9 (`parsefiles-20261010-124809081`),
  scoped repair parser 2/2 (`parsefiles-20261010-125839319`).
  Baseline test реально загружен GUT; cargo проверяет disk round-trip, fresh native instance,
  восстановление более раннего снимка и preflight rejection до изменения мира.
- PASS: formatter/lint, incremental architecture, strict architecture, project structure,
  strict domain dependencies; gates scoped repair также прошли.
- Live MCP diagnostics: unnamed test/smoke scripts clean; для существующих global class scripts
  scratch reload сообщает fallback error 43 без file diagnostics. Headless parser/GUT —
  самостоятельное доказательство; live reload не помечать PASS. Не менять third-party handler.
- PASS: source review/triage и targeted re-review RV-001/002/003 ниже.
  Reviewer не запускал проверки; worktree results не доказывают immutable test equivalence.
- NOT_RUN: обязательная gameplay/visual QA владельца; rendered playtest не запускался.

### Review / triage

Raw review: base `90589beac152090feb19d9e3bac6ceeda2f6065a`, target
`0aa2b59dcb3a7daa0df009e8317251044a0eba6a`; один read-only reviewer выявил P2:

- RV-003 (R1) — capture сохранял временное can_sleep=false применённого Carry.
  FIXED: `7a7e6384124188889c1f3540a0b9b5c4bd2def25`; capture использует исходное
  `R_HeldBy.previous_can_sleep` при lifecycle_applied. GUT применяет настоящий grip lifecycle,
  проверяет release/slot cleanup и возвращение true; отдельно сохраняет исходную false-policy.
  Targeted re-review base `0aa2b59dcb3a7daa0df009e8317251044a0eba6a`, target
  `7a7e6384124188889c1f3540a0b9b5c4bd2def25`: ARCHITECTURE/STYLE PASS,
  новых material findings нет; VALIDATION NOT_RUN у reviewer. Один repair cycle.

Checkpoint: `c391076a2b2fd7f468954d0b1c56c75e76586ec5`, base
`757bcf60e08fffe3e0b74f12f1fb1667a1ed2112`. Reviewer выявил два P1:

- RV-001 (R1) — primitive level потерял точку возврата без truck_parking replacement.
  FIXED: `fdd1b17a646e605f6f49b436b402e28924e2c99a`; native Marker3D/binding,
  GUT реальной сцены исполняет START_SHIFT и проверяет выручку.
- RV-002 (R2) — snapshot из синхронного удаления мог сохранить актор вместе с removed receipt.
  FIXED: `fdd1b17a646e605f6f49b436b402e28924e2c99a`; capture/can_restore отклоняют
  активную транзакцию. Callback capture и иначе валидный restore проверены GUT.

Targeted re-review: base `c391076a2b2fd7f468954d0b1c56c75e76586ec5`, target
`fdd1b17a646e605f6f49b436b402e28924e2c99a` — ARCHITECTURE/STYLE PASS,
новых material findings нет; VALIDATION NOT_RUN у reviewer. Один repair cycle.

### Owner QA / blockers

Принято владельцем 2026-10-15 по сообщению «Закрой все задачи где OWNER_QA». Ранее реализованный объём закрыт общей приёмкой; новые замечания остаются отдельными задачами. Поштучный прогон всех сценариев и новая визуальная QA агентом не заявляются.

Связанные чеклисты: [обратную загрузку, извлечение и выручку](../../../.qa/tasks/district_truck_returns_resale.md)

## Границы и владельцы

- `content/domains/packages/services/package_return_service.gd`, `receiving_shift_service.gd`,
  обработчик груза/партии и существующие операции денег/удаления предметов.
- Контракт стоимости и количества имущества, сцена/ссылки старого `PackageReturnPoint`, журнал однократных операций.

Применять по области: [save-systems](../../skills/save-systems/SKILL.md), [gecs-v8](../../skills/gecs-v8/SKILL.md).

Components владеют журналом операции/данными партии, Relationships — живыми привязками;
обратный груз обрабатывается явной идемпотентной транзакцией на существующей границе.
Разделить возврат конкретной коробки и адаптер `return_held`, сохранив текущих callers.
Финансовый COMMITTED следует за видимым изменением; принятие запроса не означает выплату.

## Работы

- [x] Удалить старый PackageReturnPoint и его привязки после подключения возвратов через машину.
- [x] До начала смены вход/выход из кузова не продаёт и не возвращает предмет; зафиксировать фактически свободный груз при начале смены, пока действуют MORNING-правила.
- [x] Допустимые возвраты проводить общей операцией без обязательного удержания коробки; сохранить прежние жалобы и финансовые результаты.
- [x] Переносимое имущество продавать за floor(рыночная стоимость × количество × 10%); коэффициент редактируемый. Непрайсованный мусор — 0$. Трупы допускаются, живые персонажи, предметы в руках и геометрия — нет.
- [x] Чужие посылки не дают продажного дохода; недопустимый возврат не создаёт LOST за игрока. Стабильные ID партии/операции исключают повторную оплату и удаление.

## Критерии завершения

- Предмет можно вынуть до отъезда; продажа/возврат/утилизация происходят один раз при начале смены.
- Цена и фильтрация соответствуют правилам; повторный запрос и восстановление не повторяют операцию.

Выполнять только этот ограниченный результат, объединяя связанные чтения, правки и проверки. Не расширять задачу соседними функциями. Закрыть её собственные Status/Current/Validation, сохранить связный результат коммитом и обновить следующее действие в общей задаче. Завершение этой задачи само по себе не закрывает родительский этап.

