# TASK-META01 — восстановить canonical metadata существующих задач

Status: **IN_PROGRESS**

BASE_SHA: `9cc33be68ef8fb42ce4ab1965335c6e840722a49`.

## Task state

### Goal

Устранить существовавшие на `954be4d2a7a0087ce08461bc1fbdd8074f815e67` нарушения task metadata, из-за которых полный project structure gate не проходит. Не менять требования, авторские решения, приёмку и текущие пользовательские правки задач.

### Current

Нормализованы 33 существовавших task records: пояснения приёмки вынесены на строку после canonical Status, добавлены/понижены нужные headings. Prose-токены всех исходных требований, планов и исторической приёмки сохранены; добавленная ссылка Owner QA только указывает на прежние критерии. Полный structure gate PASS без изменения validator. Original bytes и staged-candidates: `.artifacts/task_metadata_original/`; пользовательский diff диалогового ТЗ не включается в metadata commit.

### Next

Создать отдельный metadata commit из проверенных staged-candidates, закрепить полные BASE_SHA/TARGET_SHA, выполнить read-only review и triage. До этого задача не DONE. Runtime-исправления RV-001/RV-002 принадлежат PVZ-CAL01 и в metadata commit не входят.

### Validation

- **PASS**: сравнение исходного SHA и worktree — 81 baseline finding, 0 introduced до нормализации PVZ-CAL01.
- **FAIL**: `python utils/validate_project_structure.py` на baseline metadata; scoped strict domain dependencies и architecture PVZ-CAL01 проходят.
- **PASS**: 33 нормализованных records, идентичные prose-токены оригиналов и staged-candidates, полный structure gate и UTF-8. Metadata commit/review: **REVIEW_PENDING**. Godot/GUT/visual проверки для документного scope не требуются.

### Owner QA / blockers

Нужно сохранить незакоммиченные пользовательские изменения в ТЗ жителей, торговли и диалогов. Это отдельный документный scope; findings не являются дефектами gameplay PVZ-CAL01 и не разрешают выдавать полный structure gate за PASS.

### Acceptance

- [ ] У затронутых задач один canonical Task state с Goal, Current, Validation и Owner QA / blockers.
- [ ] Историческая приёмка, требования и пользовательский diff сохранены.
- [ ] Полный structure gate PASS без новых исключений и отключения checks.
- [ ] Отдельный commit, immutable read-only review и triage завершены.
