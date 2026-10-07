# Refactoring v2.00.02 — usability и content-authoring audit

Status: **DONE**

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

## Current — результат 2026-10-07

Шесть walkthroughs выполнены после DONE 00_01. «Место» = вручную настраиваемый asset/instance, не каждое поле Inspector. Counts — design estimate целевого workflow, не измеренное usability testing. Runtime code = 0 только при существующем capability/executor; новое поведение не выдаётся за content variant.

| Сценарий | Новые assets/resources/scenes | Ручные места | Runtime code | Ошибки и gate |
| --- | --- | --- | --- | --- |
| Обычный NPC | 1 Profile; existing visible scene + Template; optional visual variant | Profile + instance = 2; с mesh variant = 3 | 0 | Profile ranges, requirements, duplicate ID, home/work binding: 41/42 |
| Trader NPC | 1 Profile с existing stock; optional stock resource и Dialogue; reuse Template/scene | Profile + instance + stock/dialogue = 2–4 | 0 при готовом trade executor; иначе новая Commerce capability | Item IDs, dialogue actions, executor: 41–43/46 |
| Chair / интерактивный объект | 1 inherited visible scene с marker, inline affordance/template; reuse Sit executor | Scene + instance = 2; shared affordance optional | 0 при готовом Sit; иначе Sit — отдельная механика | Slot/marker/animation/executor: 43; baseline — existing interaction, Sit не mandatory |
| Quest/dialogue interaction | 1 Quest Definition + 1 Dialogue или ветка existing Dialogue | Quest + Dialogue + giver instance = 3 | 0 для existing condition/action/event kinds | Unknown action/tag/event, target, double payment: 40/43/46 + domain regression |
| Combat NPC variant | 1 NPC Profile; optional Combat Profile или visual scene variant | Profile + instance = 2–3 | 0 для existing attack type | Health recipe, animation, attack ranges: 41/42/46 |
| Район existing mechanics | 1 level scene + 1 district definition/schedule; reuse scenes/templates; new Profiles только для новых personalities | 2 root assets + N NPC bindings + M placements | 0 | IDs, schedule locations, Dialogue/slots, capabilities: 42–46 |

Trader/Sit walkthroughs описывают desired authoring cost после готовой механики, не утверждают, что capabilities уже реализованы. Implementation baseline мигрирует существующий контент; optional examples не расширяют gameplay scope.

### Изменения workflow

- Один visible scene-first object; Template не заменяет mesh/collision placeholder-узлом.
- Flat Template; per-item Trait scripts и обязательные отдельные `.tres` не являются default workflow.
- Precedence scene/template/profile/instance/save явна; implicit Trait-order overrides запрещены.
- Slot marker не требует дополнительной Entity или scene wrapper.
- Inspector/factory/Doctor используют один provider; 42 не дублирует runtime rules 41.
- Ready barrier и placed/spawned parity входят в 41, Inspector refinement — 42.
- Debug reason/source providers создаются в 40–45; 48 только UI aggregation.
- Stable bindings редактируются Node/resource pickers; persistent ID не равен NodePath.

### Four UX views

| View | Оценка target plan | Обоснование / ограничение |
| --- | --- | --- |
| Programmer UX | 8/10 | Path owner, scheduling, trace, local regression; 28/33 индексируют class_name references |
| Designer UX | 8/10 | 2–4 local edits на variant, visible scene, inline resources, Simple/Advanced; ergonomics — owner QA 42 |
| Debugging UX | 8/10 | Reason/source snapshot, early providers, native LimboAI view; discoverability — QA 48 |
| AI-agent UX | 8/10 | Canonical owners, public manifest, bounded regression, forbidden-dependency gate |

Это review дизайна, не текущего продукта. Все категории имеют concrete implementation acceptance; visual QA не проводилась.

## Validation result

Counts и ownership/precedence сверены с target sections 9–10 и tasks 40–43/48. `git diff --check` PASS. Editor/gameplay не запускались: planning-only.

## Next

[00_03_simplification_reference_audit.md](00_03_simplification_reference_audit.md): оспорить mandatory GOAP, четыре LOD и framework complexity.
