# R22 — HUD и читаемость систем

Status: **OWNER_QA**

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
- [x] M2: context prompt/scanner/challenge audit and distinct damage/hazard feedback.
- [x] Complete the remaining implementation work checklist.
- [x] Independently review material changes and resolve all R-findings.
- [x] Run final task validation according to the documented GUT/headless budget.
- [x] Record remaining owner gameplay/visual QA.

### Decisions
Read-only feedback consumes gameplay state/results; debug toggles never affect gameplay. Keep existing debug timers/conditions/tasks available. Player-facing Health/Hunger/Money remain visible with debug disabled. Native text markings attach to four mesh faces and inherit physical motion; condition billboard is preserved. No visual/rendered validation claim. Existing prompt/progress, scanner beep/number, challenge rules/countdown/gaze and Terminal facts are already owning-system presentation; inspect before adding duplicates.

### Current
Implementation complete. M1 `9d4abdec`: bottom-left ordinary status panel and four native box-face markings. M2: read-only committed DamageResult snapshots, distinct player/toxic/explosion warnings/tones and bounded world hit labels surviving target removal. Feedback observer precedes destructive lifecycle observers. Locked-door prompts explain missing access items, scanner rejection shows the actual reason and stops success beep, unavailable context-wheel hints removed. Existing dialogue/tool/throw/combat/prolonged prompt routing, Terminal facts and challenge/gaze presentation reused. Contract: `docs/player_feedback.md`. Next agent task: R22.5 M1; owner full-scenario presentation QA remains here.

### Validation
Final GUT `r22_final_gut.log`: 109/109 PASS, 548 assertions, no orphans/ObjectDB/resource leaks. Includes damage feedback, grab, openable access, prolonged session/progress and player melee. New feedback tests prove committed-only delivery, cleanup/depletion safety, disabled UI preserves damage, bounded labels and signal disconnection. Initial combined run exposed existing test fixture leaks: temporary PlayerIntent systems now freed; openable/prolonged Worlds purged before free. Narrow diagnostic runs and final rerun verified cleanup. Separate read-only review: no material findings. Strict `player_feedback-20261002-140308131.log` PASS with debug disabled: status/face markings, damage types, UI-off damage, native door ray/real item pickup and scanner confirmation/rejection. Fixture setup is synthetic; no full gameplay playthrough or visual/audio-perceptual claim. Strict `challenge_gaze-20261002-140626943.log` PASS; main headless 120-frame shutdown has external Windows certificate error only, no project errors/leaks. Structure/diff PASS. Owner visual/gamepad/layout/readability QA remains.

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
- [x] Проверить доступность и актуальность prompt во всех контекстах, включая prolonged interaction/access denial из R11.1, dialogue/tool/throw/combat (code/regression audit; rendered full scenario remains owner QA).
- [x] Показать Fragile/Heavy/Liquid и Damaged/Opened на самих коробках, а не только в HUD.
- [x] Проверить scan beep/подтверждение/Terminal, требования Challenge, gaze warning и countdown (native state/contract audit and smoke; perceptual sufficiency remains owner QA).
- [x] Различить feedback повреждения игрока, коробки, ToxicLeak и Explosion; убрать debug-зависимости.

## Критерии готовности

- Без debug UI понятны доступные действия, параметры игрока, свойства Package и последствия опасностей.
- UI/звук/визуальные эффекты подписаны на состояние/результаты; их отключение не меняет gameplay.

## Проверки

GUT: привязки и cleanup UI там, где логика существенна; ручная проверка читаемости полного сценария. Общие команды и правила завершения — в [README](README.md).

## Границы

Не переносить весь feedback на этот этап: минимальный результат должен быть читаем уже в каждой owning-задаче. Сохранять Godot physics authority, GECS data/behavior boundaries и read-only addons. Выполненные основания переиспользовать, а не создавать заново.

## Первый шаг

Проверить завершение зависимостей по task_history.md и существующим контрактам, затем прочитать указанные исходники и актуализировать WORK.md/CURRENT_WORK.md. При реализации не считать непроверенные пункты выполненными.
