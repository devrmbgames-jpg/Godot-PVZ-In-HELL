# R31 — Корневая папка ресурсов

Status: **DONE**

## Task state

### Goal

Перенести content/resources в res://resources и обновить ссылки, сохранив бинарные AtlasTexture и исходные медиа.

### Milestones

M0: безопасное перемещение существующих ресурсов. M1: проверка ссылок и идемпотентности генератора.

### Decisions

Путь ресурсов — resources/input_prompts; addons и пользовательские изменения не трогать.

### Current

1417 файлов перемещены в resources/input_prompts, catalog и R30 актуализированы. Следующий шаг — R32. Старые задачи не отменены, R25 остаётся последней. Работа только в dev.

### Validation

SHA256 всех 1417 файлов совпали до/после перемещения. Headless atlas generator: PASS1416 resources,0 written (.export/r31-resources.log). Ненужные GUT/gameplay не запускались.

### Owner QA / blockers

Визуальное качество, звук и физические устройства проверяет владелец; полный игровой срез агент не запускает.


Последующее изменение R30 M4 (2026-10-03): по явному запросу владельца мигрированная папка resources/input_prompts удалена вместе с атласами. Актуальные иконки — отдельные PNG в resources/kenney/kenney_input_prompts; состояние и QA в roadmap_30_settings_input_prompts.md. Историческая проверка переноса R31 остаётся выполненной.
