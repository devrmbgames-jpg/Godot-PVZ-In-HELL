# Refactoring v2.43 — Smart Objects / Affordances / Reservations

Status: **PLANNED**

Зависимости: [42_visual_entity_authoring.md](42_visual_entity_authoring.md), [40_typed_commands_events.md](40_typed_commands_events.md).

## Goal

Сделать единый capability-based язык взаимодействия Entity с миром.

## Scope

- authored Smart Object definition;
- affordances;
- slots/markers;
- reservation Relationships;
- eligibility/preconditions;
- execute/cancel lifecycle;
- common contract для player, LimboAI, quests и Dialogue; future optional GOAP использует тот же API без mandatory implementation здесь.

## Constraints

Smart Object не должен становиться новым gameplay authority. Runtime state хранится в ECS/Relationships; scene markers — authoring/presentation.

Slot = authored marker + stable slot ID; отдельная slot Entity не нужна. Reservation Relationship направлен actor→object и содержит slot/token. Eligibility/executor schema валидируется и доступна в Inspector через тот же provider, что headless. Новая вариация существующего executor не требует script или правки global registry.

## Acceptance

Минимум один существующий service/interaction object (counter/return/delivery point) мигрирован через общий contract без проверки concrete scene class; второй placed/spawned variant использует те же данные/executor. Chair/Sit и Bed/Sleep — optional examples, не обязательные новые gameplay mechanics.

Reservation token/slot exclusivity проверяются при execute и cancel; target loss/death/world removal освобождают связь идемпотентно. Eligibility failure не публикует success; stale token не отменяет новый reservation. Providers ловят missing executor/slot/marker до запуска.

Acquire выполняется одной serialized owning operation без yield между eligibility/exclusivity check и relationship mutation. Occupancy reverse index — derived cache из Relationships, не второй slot authority. Race/conflict fixture доказывает единственного победителя и отсутствие leaked reservation при failed execute.

## Validation

Reservation/content validation + representative interaction tests.
