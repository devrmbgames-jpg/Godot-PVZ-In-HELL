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

## Current — повторный authoring review 2026-10-07

Шесть walkthroughs повторно выполнены после отдельного commit 00_01. Сверены actual DEF_NpcProfile/DEF_TraderProfile/C_Trader, DEF_RefusalQuest/hardcoded service Definition, CustomerDialogueContext/NpcDialogueService и физические E_Customer/E_DistrictNpc. «Место» = вручную настраиваемый asset/instance, не каждое поле Inspector. Counts — design estimate, не usability measurement. Runtime code = 0 для variant готового capability/executor после owning migration; новое поведение не выдаётся за content variant.

| Сценарий | Новые assets/resources/scenes | Ручные места | Runtime code | Ошибки и gate |
| --- | --- | --- | --- | --- |
| Обычный NPC | 1 Profile; existing visible scene + Template; optional visual variant | Profile + instance = 2; с mesh variant = 3 | 0 | Profile ranges, requirements, duplicate ID, home/work binding: 41/42 |
| Trader NPC | NPC Profile + existing DEF_TraderProfile/catalog; reuse scene/Template; optional Dialogue | NPC + shop Profile + instance = 3; Dialogue = 4 | 0: existing C_Trader/Commerce capability; one-time recipe wiring 41 | Stock IDs/phase/fees, dialogue, pickup binding: 24/41/46; legacy catalog fallback удаляется в 24 |
| Chair / интерактивный объект | 1 inherited visible scene с marker, inline affordance/template; reuse Sit executor | Scene + instance = 2; shared affordance optional | 0 при готовом Sit; иначе Sit — отдельная механика | Slot/marker/animation/executor: 43; baseline — existing interaction, Sit не mandatory |
| Quest/dialogue interaction | Existing refusal Quest Definition + Dialogue variant; giver configuration | Definition + Dialogue + issuer = 3 | 0 для existing objective/read/action kinds; hardcoded preload заменяется authoring binding в 19 | Unknown cue/ctx method/tag, missing issuer/target, replay/late result/double payment: 19/40/46 |
| Combat NPC variant | 1 NPC Profile; optional Combat Profile или visual scene variant | Profile + instance = 2–3 | 0 для existing attack type | Health recipe, animation, attack ranges: 41/42/46 |
| Район existing mechanics | 1 level scene + 1 district definition/schedule; reuse scenes/templates; new Profiles только для новых personalities | 2 root assets + N NPC bindings + M placements | 0 | IDs, schedule locations, Dialogue/slots, capabilities: 42–46 |

Trader уже имеет existing executor/Profile. Sit остаётся новой возможной механикой; её не добавлять ради Chair demo. Для baseline walkthrough использовать existing counter/return point. Quest walkthrough ограничен existing lifecycle, не обещает произвольный quest без кода. Implementation baseline мигрирует существующий контент; optional examples не расширяют gameplay scope.

### Изменения workflow

- Один visible scene-first object; Template не заменяет mesh/collision placeholder-узлом.
- Factory принимает existing scene reference/context и читает Template instance; удалён default_scene из Template. Нет cyclic Resource graph и второго scene selector.
- Flat Template; per-item Trait scripts и обязательные отдельные `.tres` не являются default workflow.
- Precedence scene/template/profile/instance/save явна; implicit Trait-order overrides запрещены.
- Slot marker не требует дополнительной Entity или scene wrapper.
- Inspector/factory/Doctor используют один provider; 42 не дублирует runtime rules 41.
- Ready barrier и placed/spawned parity входят в 41, Inspector refinement — 42.
- Debug reason/source providers создаются в 40–45; 48 только UI aggregation.
- Stable bindings редактируются Node/resource pickers; persistent ID не равен NodePath.
- Existing quest Definition становится author-selectable в 19; Trader Profile становится sole stock source в 24 с удалением legacy catalog fallback.
- Dialogue сохраняет explicit typed ctx и panel: observational conditions, declared action methods/tags/cues, committed result before success, session generation/late-await cleanup, operation IDs для replay. Global registry/Quest DSL не нужны.
- Acceptance 49 требует variant cookbook/headless fixtures для NPC, Trader, combat, object, quest/dialogue и reused level; низкая ceremony проверяется задачей, а не только обещанием preflight.

### Границы, стоимость и открытое решение

Scene owns physical structure and its Template; Template owns gameplay recipes; NPC/Trader/Quest Profile owns tuning; instance owns IDs/bindings/explicit overrides; save overlay wins only for persisted runtime fields. Inspector показывает provenance и единственный editable provider. Local Node picker converts bindings to stable IDs for runtime fixup. ID repair explicit; shared resource preview read-only. Resource cycles, duplicate providers, invalid cues/methods/stock/targets fail before gameplay.

Remove capability workflow: удалить Trait/reference из scene/Template, затем Doctor найдёт зависимые bindings/actions; domain/public manifest удаляются только после всех consumers. Не нужен parallel feature registry. Programmer/agent начинает с owner, contract, diagnostic provider и relevant fixture. Read/query import не означает permission писать state.

Body separation не улучшает ни один из шести authoring walkthroughs и добавляет actor/body casts, BT bindings и scene/save migration после 41/42. C_District.people — уже ECS-owned aggregate; metadata там не дублирует C_Health/Inventory. 00_03 должна либо оправдать detach measured requirement, либо заменить baseline сохранением existing physical-root + inactive processing. До этого representation choice не объявлена approved.

Final disposition: 00_03 сохранила physical roots/aggregate и выбрала ACTIVE/DORMANT; body detach deferred. Final 00_05 подтверждает scene-first authoring и устраняет coarse-DAG wrapper tax. Этот UX audit не оставляет unresolved representation decision.

### Four UX views

| View | Оценка target plan | Обоснование / ограничение |
| --- | --- | --- |
| Programmer UX | 8/10 | Path owner, early typed contracts, scoped read/write, local fixtures; representation cost передана 00_03 |
| Designer UX | 8/10 | 2–4 local edits, scene selects Template, no resource cycle, real Trader/Quest examples; ergonomics — owner QA 42 |
| Debugging UX | 8/10 | Reason/source snapshot, early providers, native LimboAI view; discoverability — QA 48 |
| AI-agent UX | 8/10 | Canonical owners, public manifest, bounded regression, forbidden-dependency gate |

Это review дизайна, не текущего продукта. Все категории имеют concrete implementation acceptance; visual QA не проводилась.

## Validation result

Counts и ownership/precedence сверены с local source, target sections 9–10.5 и tasks 19/24/40–43/46/49. `python utils/validate_refactoring_preflight.py`: PASS. `git diff --check`: PASS. Editor/gameplay/parser/GUT не запускались: planning-only, runtime не менялся.

## Next

[00_03_simplification_reference_audit.md](00_03_simplification_reference_audit.md): пересмотреть forced actor/body split, aggregate authority и framework cost; повторно проверить reference-inspired layers.
