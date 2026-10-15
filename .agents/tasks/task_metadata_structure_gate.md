# TASK-META01 — восстановить canonical metadata существующих задач

Status: **PLANNED**

## Task state

### Goal

Устранить существовавшие на `954be4d2a7a0087ce08461bc1fbdd8074f815e67` нарушения task metadata, из-за которых полный project structure gate не проходит. Не менять требования, авторские решения, приёмку и текущие пользовательские правки задач.

### Current

При PVZ-CAL01 независимо воспроизведено 81 нарушение `_check_task_state_contract`: строгий status regex не принимает строку `Status: **DONE** — принято ...`; ряд планов использует верхнеуровневые Goal/Current/Validation либо русские заголовки вместо canonical блока. Исходный SHA и текущая worktree дали одинаковый набор (introduced = 0), доказательство: `.artifacts/calendar_task_metadata_baseline.txt`. Собственный task record PVZ-CAL01 нормализуется в его checkpoint.

### Next

Проверить минимальные заголовки затронутых задач. Перенести пояснение приёмки на отдельную строку, нормализовать владельца Task state и необходимые подразделы, сохранив текст/семантику. Для уже грязных файлов отдельно сохранить существующий diff и включать в коммит только собственную нормализацию. Не ослаблять validator ради PASS.

### Validation

- **PASS**: сравнение исходного SHA и worktree — 81 baseline finding, 0 introduced до нормализации PVZ-CAL01.
- **FAIL**: `python utils/validate_project_structure.py` на baseline metadata; scoped strict domain dependencies и architecture PVZ-CAL01 проходят.
- Исправление metadata и его review: **NOT_RUN**. Godot/GUT/visual проверки для этой документной задачи не требуются.

### Owner QA / blockers

Нужно сохранить незакоммиченные пользовательские изменения в ТЗ жителей, торговли и диалогов. Это отдельный документный scope; findings не являются дефектами gameplay PVZ-CAL01 и не разрешают выдавать полный structure gate за PASS.

### Acceptance

- [ ] У затронутых задач один canonical Task state с Goal, Current, Validation и Owner QA / blockers.
- [ ] Историческая приёмка, требования и пользовательский diff сохранены.
- [ ] Полный structure gate PASS без новых исключений и отключения checks.
- [ ] Отдельный commit, immutable read-only review и triage завершены.
