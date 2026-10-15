# TASK-META01 — восстановить canonical metadata существующих задач

Status: **DONE**

BASE_SHA: `9cc33be68ef8fb42ce4ab1965335c6e840722a49`.
TARGET_SHA: `17ea4674872aa7df893405803232c31ab54c4859`.
Review: **PASS**, read-only immutable diff; новых findings нет, triage закрыт.

## Task state

### Goal

Устранить существовавшие на `954be4d2a7a0087ce08461bc1fbdd8074f815e67` нарушения task metadata, из-за которых полный project structure gate не проходит. Не менять требования, авторские решения, приёмку и текущие пользовательские правки задач.

### Current

Нормализованы 33 существовавших task records: пояснения приёмки вынесены на строку после canonical Status, добавлены/понижены нужные headings. Prose-токены всех исходных требований, планов и исторической приёмки сохранены; добавленная ссылка Owner QA только указывает на прежние критерии. Полный structure gate PASS без изменения validator. Original bytes и staged-candidates: `.artifacts/task_metadata_original/`; пользовательский diff диалогового ТЗ не включается в metadata commit.

### Next

Независимый metadata scope завершён и архивирован. Продолжить implementation задач PVZ; требования и историческая приёмка соседних задач не изменены.

### Validation

- **PASS**: сравнение исходного SHA и worktree — 81 baseline finding, 0 introduced до нормализации PVZ-CAL01.
- **FAIL**: `python utils/validate_project_structure.py` на baseline metadata; scoped strict domain dependencies и architecture PVZ-CAL01 проходят.
- **PASS**: 33 нормализованных records, идентичные prose-токены оригиналов и staged-candidates, полный structure gate и UTF-8. Metadata checkpoint `17ea4674872aa7df893405803232c31ab54c4859`: independent read-only review **PASS**, замечаний нет; committed whitespace gate **PASS**. Godot/GUT/visual проверки для документного scope не требуются.

### Owner QA / blockers

Дополнительная gameplay/visual QA для изменения заголовков не требуется. Исходный пользовательский diff сохранён: ТЗ жителей 18/18 строк diff, торговли 53/33, диалогов 6/2; addons/gecs и новые пользовательские GDD/roster tasks не включались в коммиты. Блокеров и pending review нет.

### Acceptance

- [x] У затронутых задач один canonical Task state с Goal, Current, Validation и Owner QA / blockers.
- [x] Историческая приёмка, требования и пользовательский diff сохранены.
- [x] Полный structure gate PASS без новых исключений и отключения checks.
- [x] Отдельный commit, immutable read-only review и triage завершены.
