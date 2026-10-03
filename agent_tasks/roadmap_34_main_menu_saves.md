# R34 — Главное меню и сохранение/загрузка/новая игра

Status: **OWNER_QA**

## Task state

### Goal

Создать главное меню; добавить сохранение, загрузку и новую игру в игровое меню. Старые задачи сохраняются, R25 остаётся LAST. Работа только в dev.

### Design plan

Опыт: запуск/возврат в прохождение понятен, сохранённый прогресс не теряется молча. Опоры: ясные действия, предсказуемое сохранение, управление мышью/геймпадом. Цикл: главное меню → новая игра/загрузка → игра → пауза/сохранение → возврат или выход. Переход, теряющий несохранённый прогресс, подтверждается обычным игровым диалогом.

### Milestones

1. Общий сервис игровых слотов/переходов, поверх существующего checksummed Morning snapshot.
2. Главное меню, настройки без игрового actor, игровое меню со save/load/new/main/exit.
3. Отрицательные сценарии и menu→game→save→load lifecycle; QA checklist, Windows main/test exports.

### Decisions

Существующий snapshot — контрольная точка утра: live customers/challenges/grips не сериализуются. В этом frontend-этапе сохранение доступно утром в безопасном состоянии, с явной причиной недоступности; произвольные mid-visit saves требуют отдельной миграции gameplay contracts. Загрузка из любой фазы происходит в свежую сцену после полной проверки, новая игра не читает старое сохранение. Новая игра не удаляет сохранения; перезапись слота только явным save либо существующим night autosave. Main/test используют разные пути и общий стартовый экран. Повреждённая/несовместимая загрузка не закрывает текущую игру. Настройки сохраняются отдельно. Default run/main_scene должен стать главное меню; exports/startup checker должны учитывать этот переход.

### Current

M0–M2 реализованы: типизированный GameSessionService и GameSaveResult, detached preflight без изменения ECS.world, главное меню и общий bootstrap main/test, standalone settings, игровой save/load/new/main/exit с подтверждениями. Настройки сохраняются также при успешном переходе/выходе. Экспорт проверяет главный экран и выбранный игровой уровень отдельно. Gameplay milestone97a0ef71, dev. Windows main/test готовы; следующий шаг — owner QA.

### Review

- R1 FALSE_POSITIVE: обзор неверно прочёл вложенность _input; обычные GUI события уже не поглощались в HEAD. Изменение не понадобилось, реальные pointer clicks покрыты smoke.
- R2 FIXED: успешные new/load/main/exit сохраняют параметры и InputMap через _save_preferences с авторским settings_path. Повреждённая загрузка оставляет прежний paused world/menu. Независимый read-only reviewer подтвердил закрытие.

### Validation

- Project structure и git diff --check PASS.
- Related GUT:30/30,203 assertions (.export/r34-related-gut.log).
- Один полный milestone GUT:491/491,4029 assertions,56 scripts (.export/r34-milestone-full-gut.log). Нет script errors/leaks; native Windows certificate-store diagnostic присутствует, как прежде.
- Scene lifecycle + реальные Viewport GUI pointer clicks new/save/load, preferences ConfigFile и checksum/preflight отказ: menu_session smoke PASS (tests/artifacts/menu_session-20261003-192144176.log).
- Raw menu safety key/binding capture/resume regression: settings_input smoke PASS (tests/artifacts/settings_input-20261003-192408372.log).
- Windows97a0ef71: main `.export/windows/20261003-092610Z-97a0ef71-menu-saves-main/PVZInHell.exe`; test `.export/windows/20261003-092744Z-97a0ef71-menu-saves-test/PVZInHell.exe`. Оба главных экрана и обе фактические игровые карты: headless startup120frames PASS; LATEST.cmd/TEST_LEVEL.cmd обновлены.
- Rendered/device/full slice не запускались.
- Удалены2 промежуточных failed GUI smoke logs (1795bytes) и временный файл selective project index; успешные evidence/build logs сохранены (.export/r34_log_cleanup_manifest.json).

### Owner QA / blockers

[Главное меню и сохранения](../qa_tasks/main_menu_and_saves.md): мышь/клавиатурный фокус/геймпад, разрешение/читаемость, подтверждения, перезапуск и восстановление. Полный основной игровой срез проверяет владелец по его запросу. Автоматический запуск только headless. R25 остаётся LAST после предыдущих задач и QA fixes; прежние задачи не отменены.
