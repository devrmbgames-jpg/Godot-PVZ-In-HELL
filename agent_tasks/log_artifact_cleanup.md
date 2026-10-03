# Очистка устаревших логов

Status: **DONE**

## Task state

### Goal

Удалить ненужные промежуточные/устаревшие log-артефакты после завершённых игровых этапов.

### Constraints / acceptance

- Только dev. Сохранить пользовательские изменения, исходники, ресурсы, сохранения и Windows-билды.
- Не трогать addons/, .godot/, .git/, .bin/ и сторонние ресурсы. Удалять только проверенные файлы в .export/ и tests/artifacts/.
- Сохранить явно упомянутые в документации/контрактах логи, последние успешные smoke по каждому сценарию и логи двух актуальных Windows-билдов из launchers.
- Перед удалением проверить полный список, абсолютные пути внутри workspace и отсутствие изменений файлов после проверки. Не выполнять recursive deletion.

### Current

Очистка завершена: удалено336 файлов (52 промежуточных .export root logs,274 tests/artifacts logs,10 логов старых экспортов),7542725 bytes /7.19MiB. Сохранены75 логов с явными ссылками, последних smoke и двух актуальных Windows-билдов be10abab. Исходники, сохранения и сами билды не менялись.

### Validation

Dev branch check; каждый абсолютный путь проверен внутри .export/ или tests/artifacts/, без reparse points; размер/mtime проверены перед удалением. Remove-Item -LiteralPath применялся только к отдельным файлам. После удаления336 candidates отсутствуют, все75 protected files существуют. Точный локальный manifest: .export/log_cleanup_manifest.json. Тесты/движок не запускались.

### Owner QA / blockers

Нет. Билды и QA-результаты текущей версии сохраняются.


### Дополнение после R33

Удалены6 локальных failed sprint smoke logs (4529 bytes), заменённых успешными проверками. Успешные/ссылаемые логи и новые Windows exports ecd95df9 сохранены. Пути, reparse flags, размер/mtime проверены перед отдельными Remove-Item; удаление/retained evidence проверены. .export/r33_log_cleanup_manifest.json. Временный собственный файл для изолированного Git index удалён; пустая content/resources тоже удалена. Gameplay проверки ради очистки не запускались.


### Повторная очистка tests/artifacts — 2026-10-03

По запросу владельца удалено36 файлов,1255045 bytes /1.20MiB:13 устаревших helper .gd/.py,15 промежуточных .patch,4 старых regenerable preview PNG и4 повторных smoke logs. Authoritative bake utility остаётся в utils/bake_warehouse_navigation.gd; ссылки preview в smoke/doc описывают генерацию выходных файлов, а не обязательные входные ресурсы.

Сохранены35 logs текущих task references/последних сценариев, включая ещё нужный R23 draft, и .gdignore/.gitignore. Уточнение retention для этой очистки: ссылки в старых архивированных отчётах сами по себе не удерживают повторный лог, если финальный результат того же сценария сохранён; даты/утверждения исторических прогонов не переписывались. Удалены gaze051423564/053933394, darkness052905102, ранний menu_session191209394; финальные timing/menu logs сохранены.

Inventory/references и точный план: .export/tests-artifact-cleanup-inventory.json / tests-artifact-cleanup-plan.json. Перед удалением сверены абсолютные пути (только прямые файлы tests/artifacts), reparse flags и SHA256/размер; файлы удалены индивидуальным Remove-Item -LiteralPath. После удаления все36 отсутствуют, все35 retained logs unchanged hashes и оба metadata существуют. Игровые source/resources/builds не затронуты; tests/engine не запускались.
