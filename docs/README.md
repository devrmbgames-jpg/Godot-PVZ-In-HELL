# Документация проекта

PVZ In Hell Simulator — Godot 4.7 project with project-owned GECS gameplay.

| Документ | Назначение |
| --- | --- |
| [Правила работы агентов](../AGENTS.md) | Короткие project-specific ограничения; загружаются Codex автоматически |
| [Контекст проекта](../CONTEXT.md) | Стабильные факты об архитектуре и зависимостях; читать только при необходимости |
| [Индекс проекта](../PROJECT_INDEX.md) | Канонические маршруты к подсистемам; использовать только когда owner/path неясен |
| [Контекст gameplay](../content/CONTEXT.md) | Runtime-контракты gameplay-подсистем |
| [Точка восстановления](../CURRENT_WORK.md) | Только checkpoint незавершённой/долгой задачи |
| [История задач](../task_history.md) | Краткая история завершённых больших задач |
| [Codex lean workflow](codex_token_economy.md) | Почему проект избегает preloading, лишних skills и автоматических subagents |
| [Шпаргалка по запросам к ИИ](ai_prompt_cheatsheet.md) | Как формулировать задачи |
| [Roadmap: canonical IDs](roadmap/README.md) | Связь design-ТЗ с implementation tasks |

Основная project-owned сцена прототипа — `content/scenes/main_level.tscn`.

Развёрнутые описания механик и архитектуры хранятся рядом с соответствующей подсистемой. Корневые документы не должны дублировать детали друг друга.
