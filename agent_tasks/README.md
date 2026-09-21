# Agent Task Notes

Create a file here only for work too large to recover from `CURRENT_WORK.md`.

Template:

```md
# <task>

Status: active | blocked
Branch: <branch>
Base: <base>

## Goal
One paragraph with acceptance criteria.

## Constraints
Only non-obvious project/version/architecture constraints.

## Steps
- [ ] Small verifiable step
- [ ] Next step

## Decisions
- Decision -> reason

## Validation
- command -> result

## Resume
Next exact file/symbol/command.
```

Rules:
- Update after meaningful milestones.
- Link exact paths/symbols instead of pasting source code.
- Keep facts a fresh agent needs; omit narration and discarded exploration.
- Keep only unfinished tasks here. After completion and validation, move lasting facts into the relevant context/docs, append one short dated line to root `task_history.md`, delete the task file and update its references.
- Preserve active/blocked tasks and this README. Do not archive completed task files here.
