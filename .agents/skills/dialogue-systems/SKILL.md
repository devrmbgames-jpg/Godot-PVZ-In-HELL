---
name: dialogue-systems
description: Use for NPC/Customer conversation branching, response tags, dialogue conditions or gameplay-side actions.
---

# Dialogue Systems

Dialogue is a flow/presentation layer over authoritative game state. It may ask questions and request actions; it must not become a parallel gameplay database.

## Project authority

- Persistent Customer truth remains in `CustomerVisit`, components, relationships, and owning gameplay services.
- `CustomerDialogueContext` is a typed read/action adapter, not a new authority.
- Response tags map into typed intent (for example through `CustomerDialogueIntent`) and then into the owning outcome/service layer.
- Dialogue UI must not mutate Customer/package/health/economy state directly.
- Preserve current DialogueManager/resource contracts unless migration is explicit.

## Branch design

A dialogue step should have a clear role:
- line/presentation;
- condition;
- choice;
- command/request;
- jump/end.

Keep game-state conditions explicit and side effects at deliberate transition points. Re-entering/replaying a line must not accidentally apply the same reward, penalty, denial, or flag twice.

For tagged responses:
- tags describe semantic intent such as lie/convince/refuse;
- map tags once into a typed intent;
- testing/debug prefixes such as `[обман][убедить]` are presentation diagnostics, not authoritative state.

## Data and localization

- Prefer stable dialogue/line IDs when localized text is involved.
- Do not use visible localized text as a gameplay key.
- Keep conditions/actions separate from rendered wording so text can change without changing logic.
- Keep writer-authored branching data separate from heavy domain algorithms.

## Lifecycle

A conversation needs explicit:
- eligibility/validity check before and during interaction;
- begin/enter transition;
- close/cancel transition;
- handling for NPC death/removal/visit completion while UI is open;
- modal input capture/release;
- a valid end/jump for every reachable branch.

Do not let closing UI revive or rewind an already finished/leaving/dead Customer.

## Validation

For a changed dialogue surface:
1. validate resources/scripts parse;
2. walk affected branches statically where possible;
3. verify conditions and side effects are idempotent where revisits are possible;
4. check every reachable choice ends or jumps somewhere valid;
5. use focused manual conversation QA only for behavior that cannot be falsified statically.

Source inspiration: adapted selectively from `dialogue-systems` in `gamedev-skills/awesome-gamedev-agent-skills` (Apache-2.0); current Customer/dialogue contracts are authoritative.
