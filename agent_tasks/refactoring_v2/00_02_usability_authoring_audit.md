# Refactoring v2.00.02 — usability и content-authoring audit

Status: **PLANNED**

Зависимости: [00_01_architecture_coherence_audit.md](00_01_architecture_coherence_audit.md).

Рекомендуемый reasoning: **xhigh**.

## Goal

Проверить target architecture не по формальной "правильности", а по ежедневному удобству использования.

Главный критерий:

> Новая вариация существующей механики должна создаваться преимущественно данными, сценой и настройками. Новый runtime-код нужен в основном для действительно новой механики.

## Four UX views

### Programmer UX

Проверить, насколько легко:
- найти owner механики;
- понять execution order;
- изменить существующую feature;
- добавить новую capability;
- проследить Command/Event;
- понять authoritative state;
- написать тест;
- удалить obsolete feature;
- работать локальным context без загрузки половины проекта.

### Designer / Content Author UX

Проверить, насколько легко:
- поставить реального NPC/объект в Godot scene и сразу видеть его;
- назначить Template/Profile/Dialogue/Schedule;
- добавить capability;
- настроить home/workplace/bindings;
- создать Smart Object и визуально настроить slots/markers;
- скопировать существующий content item и получить рабочую вариацию;
- увидеть configuration error до запуска игры.

Предпочитать хороший Godot Inspector/scene workflow лишним abstract data pipelines.

### Debugging UX

На вопрос "почему Entity сейчас делает это?" архитектура должна позволять быстро получить:
- Components;
- Relationships;
- Goal;
- Plan/action;
- LimboAI state;
- Intent;
- reservations;
- perception summary;
- Simulation LOD;
- recent events.

### AI-agent UX

Проверить:
- owner определяется по пути;
- public contracts очевидны;
- forbidden dependencies ловятся автоматически;
- subsystem context остаётся ограниченным;
- агенту не приходится реконструировать архитектуру из service call graph.

## Representative authoring walkthroughs

Мысленно пройти полный workflow без реализации:

1. Новый обычный NPC.
2. Новый Trader NPC.
3. Новый интерактивный объект типа Chair.
4. Новый quest/dialogue interaction.
5. Новая вариация существующего combat-capable NPC.
6. Новый район с уже существующими mechanics.

Для каждого посчитать:
- какие assets/resources/scenes надо создать;
- сколько мест надо вручную редактировать;
- где нужен runtime-код;
- где возможны silent configuration errors.

Если workflow требует лишней ceremony — изменить target architecture/roadmap.

## Pit of success

Предпочитать дизайн, где очевидный путь является правильным:
- неправильный role folder → validator FAIL;
- missing Trait requirement → Template validator FAIL;
- broken Dialogue/Smart Object/GOAP reference → Content Doctor FAIL;
- forbidden domain dependency → validator FAIL;
- unfinished legacy wrapper → milestone acceptance FAIL.

## Acceptance

После review target architecture должна быть удобной минимум для programmer, designer/content author, debugger и AI-agent workflow.

Для любой категории, которую reviewer оценивает ниже 8/10, roadmap должен содержать конкретное исправление или явное обоснование компромисса.

## Validation

Planning-only. Допустимы editor/tooling design notes и validator tests; gameplay implementation запрещён.
