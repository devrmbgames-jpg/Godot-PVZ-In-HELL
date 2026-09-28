# Документация проекта

PVZ In Hell Simulator — Godot 4.7 project with project-owned GECS gameplay.

| Документ | Назначение |
| --- | --- |
| [Правила агентов](../AGENTS.md) | Небольшие always-on invariants и routing |
| [Develop skill](../.agents/skills/develop/SKILL.md) | Fix/Task/Feature workflow: investigate → implement → review → verify |
| [Контекст проекта](../CONTEXT.md) | Стабильные архитектурные факты; читать только по необходимости |
| [Индекс проекта](../PROJECT_INDEX.md) | Найти owner/path, если задача сама их не указала |
| [Контекст gameplay](../content/CONTEXT.md) | Cross-system runtime contracts |
| [Task status index](../agent_tasks/CONTEXT.md) | Каноническая очередь текущих implementation tasks |
| [Current Work](../CURRENT_WORK.md) | Только один resume checkpoint текущего execution focus |
| [История задач](../task_history.md) | Краткая история завершённых задач |
| [Lean workflow](codex_token_economy.md) | Контекстная экономика и новая task architecture |
| [Шпаргалка запросов](ai_prompt_cheatsheet.md) | Как формулировать задачи без лишнего контекста |
| [Roadmap canonical IDs](roadmap/README.md) | Связь design-ТЗ с implementation tasks |

Design specifications в `docs/roadmap/` описывают продуктовый контракт и не владеют текущим статусом реализации. Статус/current/next action принадлежат соответствующему task/router в `agent_tasks/`.

Развёрнутые механические и архитектурные контракты хранятся рядом с подсистемами и читаются только когда изменение реально зависит от них.

- [Wallet and daily results](economy.md)
- [Customers and delivery](customers.md)
- [Damage and impact](damage_impact.md)
- [Hazards](hazards.md)
- [Physical grab](physical_grab.md)
- [Cart transport](cart_transport.md)
