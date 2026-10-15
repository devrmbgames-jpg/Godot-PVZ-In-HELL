# QA-CMP01 — Честный исход resolve_now в debug-жалобе

Status: **DONE**
Priority: **P2**
Baseline: `dev` / `4a671935c936cd472da5d73c0c7235dd6435ba2a`

## Task state

### Goal

DebugCustomerService.complaint(resolve_now=true) не должен писать «complaint resolved», если CustomerOutcomeService оставил outcome=PENDING. Сохранить смысл success как принятого создания жалобы и штатный расчёт; уточнить message по фактическому outcome. Дефект выделен при [DOC01](pvz_code_documentation_quality.md), отдельно от comment-only batch.

### Current

Baseline reproduction подтверждён: реальный visit без C_Wallet остаётся PENDING, но message равен «complaint resolved». GUT 10/11, 104/105 asserts, падает только pending-message; последующий расчёт при доступном wallet и повтор без двойного списания проходят. Logs `gut-20261015-190230828.stdout.log` / `.stderr.log` в `.artifacts/godot_agent/`.

Message теперь выбирается по фактическому outcome после обычного resolve. Success создания, приём повторной жалобы и денежный pipeline не меняются. Base `4a671935c936cd472da5d73c0c7235dd6435ba2a` → target `1da0229fcc69cc1805ee1afa96f5293dd092f5a7`; read-only review **PASS**, material findings нет, triage завершён. Reviewer тесты не запускал; validation ниже выполнена main.

### Acceptance

- [x] Focused regression подтверждает неверный message при PENDING.
- [x] Message различает созданную pending-жалобу и terminal outcome; success создания не меняется.
- [x] Реальный resolve по обычному pipeline и повторный вызов сохраняют историю/денежную идемпотентность.
- [x] Relevant GUT/parser/MCP/style/static checks и immutable commit/review/triage PASS.

### Validation

- **PASS** focused console GUT, 11/11 tests, 105 asserts, process exit0, stderr пустой; logs `gut-20261015-190351181.stdout.log` / `.stderr.log`.
- **PASS** native ParseChanged2/0, exit0/stderr пустой; log `parsechanged-20261015-190411861`.
- **PASS** live MCP2 checked/empty, no instances; formatter2, agent validator1 applicable production path, strict architecture0 findings, project structure и scoped whitespace.

### Owner QA / blockers

Gameplay/visual NOT_RUN, budget 0/8; для строковой диагностики достаточно headless regression.
