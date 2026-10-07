# Refactoring v2.00.01 — architecture coherence audit

Status: **DONE**

Зависимости: нет.

Рекомендуемый reasoning: **xhigh**.

## Goal

Проверить весь `agent_tasks/refactoring_v2/*` как одну архитектурную программу до начала Phase 1/runtime refactor.

Цель — не переписать roadmap ради переписывания, а найти противоречия, пропуски, неверный порядок зависимостей и архитектурные решения, которые заставят позже переделывать уже выполненную migration.

Текущая target architecture в `docs/project_core_architecture_proposal.md` — **кандидат**, а не неприкосновенная спецификация. Если более простая или более удобная для Godot/GECS модель решает задачу лучше, roadmap и target design разрешено изменить.

## Read

Обязательно:
- `agent_tasks/refactoring_v2/README.md`;
- все `agent_tasks/refactoring_v2/*.md`;
- `docs/project_core_architecture_proposal.md`;
- `content/ARCHITECTURE.md`;
- `AGENTS.md`;
- `.agents/skills/refactoring/SKILL.md`;
- `.agents/skills/gecs-v8/SKILL.md`;
- `.agents/skills/gdscript-style/SKILL.md`.

Runtime/subsystem code читать выборочно только там, где надо доказать или опровергнуть реалистичность конкретного architectural assumption.

## Work

Построить dependency graph всего Refactoring v2 и проверить:

- ECS остаётся единственным authoritative gameplay state;
- Components / Relationships / Systems / Observers / Services имеют однозначный ownership;
- UI остаётся обычным Godot `Control`/glue и не втягивается в ECS;
- Templates/Traits не становятся вторым runtime model;
- placed и runtime-spawned Entity сходятся к одному runtime contract;
- vertical domains не конфликтуют с Godot scene/resource workflow;
- Commands/Events не создают скрытый global event bus;
- Schedule / Utility / GOAP / LimboAI не дублируют authority;
- Simulation LOD не требует второго NPC runtime;
- persistence, stable IDs и resource paths учтены до migrations, которые могут их сломать.

Для каждого task проверить:
- действительно ли все его prerequisites появляются раньше;
- не оставляет ли task permanent half-migration;
- можно ли завершить task как coherent milestone;
- достаточно ли Acceptance/Validation, чтобы доказать DONE.

## Allowed changes

Разрешено:
- менять roadmap;
- менять порядок;
- добавлять/удалять/дробить/объединять planning tasks;
- усиливать dependencies и acceptance gates;
- синхронизировать architecture docs/agent rules;
- добавлять architecture validators и их tests.

Запрещено:
- начинать runtime/gameplay refactor;
- переносить gameplay файлы;
- менять Systems/Components/Relationships/Services/Entities ради будущей migration.

## Output

Обновить roadmap так, чтобы dependency graph стал непротиворечивым.

Сохранить краткий список найденных архитектурных рисков внутри Task state/Current либо отдельного planning note, если findings слишком велики.

## Acceptance

- все Phase 0–3 tasks образуют понятный dependency graph;
- нет известной задачи, которая требует ещё не созданный foundation;
- нет очевидных permanent dual-architecture states;
- target design и roadmap не противоречат друг другу;
- найденные проблемы либо исправлены в плане, либо явно переданы следующей Phase 0 задаче.

## Validation

Documentation/validator-only. Runtime/gameplay tests не запускать.

## Current — повторный pass 2026-10-07

Повторно сопоставлены весь 50-task roadmap, target candidate, runtime architecture, AGENTS и обязательные skills. Предыдущая readiness переоткрыта; 00_02–00_05 проходят новый review последовательно. Phase 1 не исполнялась. Сохранены полезные изменения первого прохода: identity baseline 04, transition dependency gate 33 до moves, time/seed 47 до новых AI/LOD и full style coverage по новым roots.

Проверены assumptions по pinned GECS `entity.gd`, `world.gd`, `ecs.gd`, `observer.gd`, текущим main_level, snapshot/codec, C_District/NpcRecord и E_DistrictNpc. Addons читались без изменений. Подтверждены immediate System.setup при ECS.world assignment и synchronous construction callbacks; отсутствие early side effects теперь explicit gate.

### Dependency graph и аудит всех milestones

README задаёт один последовательный topological order. Дополнительные direct prerequisites указаны в owning tasks; transitive prerequisites не нужно дублировать. IDs 40/47/33 сохранены ради ссылок и не означают numerical execution order.

| Task | Prerequisite / проверенный completion boundary |
| --- | --- |
| 00_01 | Нет; исправленный общий graph, риски переданы 00_02–04 |
| 00_02 | 00_01; шесть authoring walkthroughs, четыре UX вида |
| 00_03 | 00_02; ADOPT/REJECT/DEFER каждого framework layer |
| 00_04 | 00_03; migration/schema/validation/removal matrix |
| 00_05 | 00_01–04; отдельный финальный readiness verdict |
| 01 | READY gate; canonical role/authority vocabulary |
| 02 | 01; scheduled vs synchronous vs callback examples |
| 03 | 02; layout-independent smells guard + finite baseline |
| 04 | 03; identity/schema-2/path baseline до migration |
| 10 | 04; 100% service inventory, ownership/removal task каждого item |
| 40 | 10, 04; typed boundary foundation + direct callers до execution migration; no generic framework |
| 11 | 40, 10; только planning/arrival/day ownership, active visit остаётся scope 12 |
| 12 | 11; active visit scheduler, удалить его service dispatcher |
| 13 | 12; settlement/outcomes idempotency, без повторного outcome polling |
| 14 | 13; district schedule/population owner и ordering |
| 15 | 14; decision/perception cadence в Systems, LimboAI adapter остаётся узким |
| 16 | 15; route/service-role timers и budgets в Systems |
| 17 | 16, 10; attack/projectile progression, existing damage boundary |
| 18 | 17, 13; challenge lifecycle/outcome separation |
| 19 | 18, 13; hunger/deadline progression, financial transaction сохраняется |
| 20 | 19, 10; input edge/focus/action routing owner |
| 21 | 20; grab/push/slots, сохранить relationship и callback authority |
| 22 | 21, 16; motion/navigation/callback boundaries |
| 23 | 22, 17; hazard/receiving/order/loot owners |
| 24 | 23, 13; economy/inventory transaction + day lifecycle |
| 25 | 24; закрыть весь inventory, persistence semantics не менять ради rename |
| 26 | 25; удалить execution wrappers, обнулить smell baseline |
| 27 | 26; execution acceptance до moves |
| 28 | 27, 40, 04; полный ownership/path/save/tooling migration map |
| 33 | 28; transition dependency enforcement до moves |
| 29 | 33; весь NPC/Customer owner, no old-path wrapper |
| 30 | 29; весь Interaction/Combat/Motion owner |
| 31 | 30; остальные world/economy/package owners |
| 32 | 29–31; shared classification, удалить horizontal roots; strict 33 rerun |
| 47 | 32 + strict 33; time/seed foundation до нового AI/LOD |
| 41 | 47; deterministic composition + placed/spawned GECS lifecycle |
| 42 | 41; Inspector/preview, существующий interactable; новые Smart Object fields в 43 |
| 43 | 42, 40; affordance/reservation/executor contract |
| 44 | 43, 47; decision/action ownership и budget |
| 45 | 44, 04, 47; одна identity/state authority при representation transition |
| 46 | 45; aggregate ранее созданных content validators |
| 48 | 46; read-only view ранее созданных diagnostics |
| 49 | 48; strict architecture/core acceptance |
| 60 | 49; один CLI style toolchain без массового format |
| 61 | 60; canonical ECS roles + manifest всей style migration |
| 62 | 61; оставшийся NPC/Customer scope |
| 63 | 62; оставшийся Interaction/Combat/Motion scope |
| 64 | 63; оставшиеся domain/shared helpers |
| 65 | 64; manifest complement всех project-owned scripts |
| 66 | 65; final architecture/style/save gates и owner QA |

### Findings и disposition

| Finding | Решение / следующая Phase 0 задача |
| --- | --- |
| Time/seed после AI/LOD | FIXED: 47 перед 41–46 |
| Typed contracts после execution consumers 11–25 | FIXED: 40 после inventory 10, до 11; bounded existing boundary migration, final execution gate 27 |
| Domain guard только после moves | FIXED: 33 transition до 29, strict после 32 |
| Content Doctor/debugger слишком поздно | FIXED: providers в owning milestones, aggregate/UI позднее |
| Early ECS.world assignment запускает System.setup до preparation | FIXED: explicit World build context, pre-registration checks, pinned registration once; setup passive, startup spawn/restore/fixup до gameplay ready |
| Shallow Component copy / synchronous observers | FIXED invariant: nested mutable state изолировать, ready barrier, явные notifications |
| Persisted paths + `scene/` keys уже существуют | 04 identity/version baseline добавлена; владелец исключил old-save compatibility, schema bump вместо конвертации; detailed policy в 00_04 |
| Forced Entity/body separation в 45A после Templates/Inspector | 00_02/03: проверить стоимость; либо убрать неоправданную миграцию, либо вынести необходимый foundation раньше 41. C_District.people уже ECS-owned: nested Resource не автоматически duplicate authority |
| GOAP/четыре LOD/Traits ceremony | 00_02/03: повторно проверить necessity; прежние DEFER/REJECT — кандидаты, не неприкосновенные решения |
| Cross-domain cycles через persistence и passive construction | 00_02–04: concrete dependency direction, snapshot integration, read/write authority и save-safe barrier |
| Phase 3 сканирует удалённые roots | FIXED: domain/shared scope и coverage manifest |
| Broad tasks 21/29–31/41/44–45 | 00_04: coherent internal slices с removal gates, без premature DONE |

Known typed-contract ordering defect исправлен. Representation foundation risk явно передан 00_02/03 и должен быть закрыт до 00_05; промежуточный graph не объявляется окончательно готовым. Ready/bootstrap invariant уточнён без addon/runtime edits. Remaining broad scopes и acceptance проверяются в 00_04.

## Validation result

Все roadmap tasks сопоставлены с graph. `python utils/validate_refactoring_preflight.py`: PASS. `git diff --check`: PASS. `--require-gate` пока намеренно не разрешён: новый 00_05 ещё не выполнен. Runtime/parser/GUT/gameplay не запускались: runtime source не меняется.

## Next

[00_02_usability_authoring_audit.md](00_02_usability_authoring_audit.md).
