# Документация проекта

Документация хранит долговременные архитектурные и игровые контракты. Она не является журналом выполнения агента.

| Документ | Назначение |
| --- | --- |
| [Правила агентов](../AGENTS.md) | Короткие always-on invariants и execution policy |
| [Индекс проекта](../PROJECT_INDEX.md) | Найти owner/path, если задача сама их не указала |
| [Gameplay architecture](../content/ARCHITECTURE.md) | Cross-system authority/lifecycle contracts |
| [Шпаргалка запросов](ai_prompt_cheatsheet.md) | Короткие примеры Prompt → Plan → Goal |
| [Roadmap](roadmap/README.md) | Design-ТЗ и их связь с implementation IDs |

Для исполнения работы:
- Plan/Goal живут в текущей Codex/VS Code session;
- `agent_tasks/` используется только для durable cross-session implementation state;
- `qa_tasks/` хранит ручные сценарии приёмки;
- завершённая implementation history берётся из Git, а не дублируется отдельным журналом.

Основные механические контракты:
- [Wallet and daily results](economy.md)
- [Customers and delivery](customers.md)
- [Damage and impact](damage_impact.md)
- [Hazards](hazards.md)
- [Physical grab](physical_grab.md)
- [Cart transport](cart_transport.md)
- [Persistence](persistence.md)

Не читать все документы перед обычной задачей: начинать с названного кода и открывать документацию только когда конкретный контракт действительно нужен.
