# R22 — HUD и читаемость систем

Status: **IN_PROGRESS**

## Task state

### Goal
Завершить пользовательскую обратную связь поверх уже работающих систем, не перенося gameplay в меню.

### Constraints / acceptance
- This is a Feature-level tracked task.
- Зависимости: R06, R07, R08, R09, R10, R11, R11.1, R12, R13, R14, R15, R16, R17, R18, R19, R20
- Reuse existing authoritative contracts from completed dependencies; do not duplicate them.
- The existing `## Работы`, `## Критерии готовности`, `## Проверки`, and `## Границы` sections remain the detailed implementation specification.
- Follow Godot 4.7, GECS ownership, physics authority, and validation rules from `AGENTS.md`.

### Milestones
- [x] Reconfirm dependency completion and current production owners/contracts.
- [x] M1: ordinary Health/Hunger/Money HUD plus native package face markings.
- [ ] M2: context prompt/scanner/challenge audit and distinct damage/hazard feedback.
- [ ] Complete the remaining work checklist.
- [ ] Independently review material changes and resolve all R-findings.
- [ ] Run final task validation according to the documented GUT/headless budget.
- [ ] Record remaining owner gameplay/visual QA.

### Decisions
Read-only feedback consumes gameplay state/results; debug toggles never affect gameplay. Keep existing debug timers/conditions/tasks available. Player-facing Health/Hunger/Money remain visible with debug disabled. Native text markings attach to four mesh faces and inherit physical motion; condition billboard is preserved. No visual/rendered validation claim. Existing prompt/progress, scanner beep/number, challenge rules/countdown/gaze and Terminal facts are already owning-system presentation; inspect before adding duplicates.

### Current
M1 implemented: bottom-left ordinary status panel independent from debug panels, including debt/penalties and Hunger tier; four native box-face markings for Fragile/Heavy/Liquid plus condition labels. Existing node names/signals preserved. Dependencies confirmed by task_history and direct production owners; R21 `a5e72672` OWNER_QA. Next: audit context prompt availability and typed DamageResult consumers; add distinct player/box/toxic/explosion feedback without moving authority into UI.

### Validation
M1 strict `player_feedback-20261002-133929439.log` PASS: real main level with debug panels disabled, live Health/Hunger/debt/penalties, inherited four-face package tags/condition, disabling ordinary HUD leaves gameplay state unchanged. Fixture uses direct state setup and headless native-node inspection; no visual/audio/perceptual claim. One initial fixture timing failure (oil not yet received) corrected by waiting for the complete supply. Structure/diff checks PASS. GUT and final combined runtime checks reserved for completed R22; owner visual/gamepad/layout/readability QA remains.

### Owner QA / blockers
Owner rendered full-scenario readability, UI layout, gamepad and audio perception QA remain. No implementation blocker.

---

Зависимости: R06, R07, R08, R09, R10, R11, R11.1, R12, R13, R14, R15, R16, R17, R18, R19, R20
Ветка/base: master / `a5e72672`.
Источники: [ТЗ 05](../docs/roadmap/05_scanner_terminal_marker.md), [ТЗ 06](../docs/roadmap/06_package_damage_and_hazards.md), [ТЗ 08](../docs/roadmap/08_customer_challenge_framework.md), [ТЗ 08.1](../docs/roadmap/08_1_arrangement_extended_interactions.md), [ТЗ 11](../docs/roadmap/11_hunger_system.md), [ТЗ 12](../docs/roadmap/12_inventory_and_consumables.md), [ТЗ 16](../docs/roadmap/16_ui_and_feedback.md).

## Цель

Завершить пользовательскую обратную связь поверх уже работающих систем, не перенося gameplay в меню.

## Начать здесь

- [content/scenes/main_level.tscn](../content/scenes/main_level.tscn)
- [docs/physical_grab.md](../docs/physical_grab.md)

Затем прочитать контракты, созданные задачами-зависимостями. Имена новых типов из roadmap — проектируемые контракты, а не утверждение о существующих файлах.

## Работы

- [x] Расширить ранний HUD из 02 показателями Health/Hunger и Money там, где это полезно.
- [ ] Проверить доступность и актуальность prompt во всех контекстах, включая prolonged interaction/access denial из R11.1, dialogue/tool/throw/combat.
- [x] Показать Fragile/Heavy/Liquid и Damaged/Opened на самих коробках, а не только в HUD.
- [ ] Проверить scan beep/подтверждение/Terminal, требования Challenge, gaze warning и достаточный countdown.
- [ ] Различить feedback повреждения игрока, коробки, ToxicLeak и Explosion; убрать debug-зависимости.

## Критерии готовности

- Без debug UI понятны доступные действия, параметры игрока, свойства Package и последствия опасностей.
- UI/звук/визуальные эффекты подписаны на состояние/результаты; их отключение не меняет gameplay.

## Проверки

GUT: привязки и cleanup UI там, где логика существенна; ручная проверка читаемости полного сценария. Общие команды и правила завершения — в [README](README.md).

## Границы

Не переносить весь feedback на этот этап: минимальный результат должен быть читаем уже в каждой owning-задаче. Сохранять Godot physics authority, GECS data/behavior boundaries и read-only addons. Выполненные основания переиспользовать, а не создавать заново.

## Первый шаг

Проверить завершение зависимостей по task_history.md и существующим контрактам, затем прочитать указанные исходники и актуализировать WORK.md/CURRENT_WORK.md. При реализации не считать непроверенные пункты выполненными.
