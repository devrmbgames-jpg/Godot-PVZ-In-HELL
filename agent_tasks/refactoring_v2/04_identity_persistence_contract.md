# Refactoring v2.04 — identity, persistence и migration baseline

Status: **PLANNED**

Зависимости: [03_architecture_validation.md](03_architecture_validation.md).

## Goal

До runtime migration закрепить identity/save contract и воспроизводимую baseline. Это Phase 1 contract task; Phase 0 только определяет её scope. По явному указанию владельца 2026-10-07 старые save-файлы не нуждаются в миграции: проект ранний, backward compatibility вне scope.

## Work

- Зафиксировать сохранённые `package/<package_id>`, `npc/<sequence>`, order/operation/history IDs, `Entity.id`, authored scene keys и supported schema.
- Описать target authored stable ID вместо `scene/<relative path>`; без legacy ID mapping или guessed identity. Duplicate/unresolved ID диагностировать до изменения мира.
- Подготовить isolated current-format fixture с NPC, absent body, owned/stored/cargo links, Definitions и record script paths; user autosave не использовать и не перезаписывать.
- Зафиксировать Night-only snapshot semantics и порядок restore: decode/migrate/validate → entities → links → caches/presentation → simulation.
- Указать path-prefix guards в codec/snapshot и полный перечень save-visible paths для migration map задачи 28.
- Определить change gate: ownership-only шаги сохраняют schema; шаг, меняющий persisted identity/path/shape, поднимает schema version и проверяет отказ несовместимого файла без live mutation. Load migrations и previous-version roundtrip не требуются.
- Старые schema, включая schema 2 после несовместимого изменения, могут быть неподдерживаемыми. Несовместимый пользовательский файл автоматически не удалять и не перезаписывать; current-format fixtures создаются в isolated test slot.
- Для каждой baseline violation указать owning task и removal gate: execution → 26/27, paths/layout → 32/33, core composition/LOD → 49.

## Acceptance

- Identity/current-format contract однозначен до 10–25.
- Baseline fixtures покрывают реально сериализуемые пути, а не только текстовые `res://` references в repository.
- У каждого изменения persisted contract есть schema/version owner и отказ до live mutation при invalid/incompatible/newer data.
- Runtime refactor ещё не начат; fixture/contract preparation не меняет игровой баланс или пользовательский save.

## Validation

Documentation/static baseline inspection. При создании fixtures — профильная проверка codec roundtrip на isolated данных. Ни gameplay migration, ни широкая suite в этой задаче не требуются.
