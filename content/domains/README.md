# Gameplay domains

Target layout for project-owned gameplay code:

```text
content/domains/<domain>/<role>/
```

A domain owns a gameplay concept such as `npc`, `customers`, `combat`, `interaction`, `packages`, `commerce`, `quests`, `time`, or `persistence`.

Canonical role directories are defined by `utils/validate_domain_structure.py`. A domain uses only the roles it needs; do not create empty role folders ceremonially.

Examples:

```text
content/domains/combat/components/
content/domains/combat/systems/
content/domains/combat/observers/
content/domains/combat/rules/

content/domains/npc/ai/
content/domains/npc/definitions/
content/domains/npc/entities/
content/domains/npc/services/
```

Do not invent spelling variants such as `component/`, `camponent/`, `system/`, or `servicees/`.

During Refactoring v2 the legacy horizontal roots remain temporarily. Final architecture acceptance requires:

```bash
python utils/validate_domain_structure.py --strict
```

Cross-domain code uses typed commands/events, stable public domain APIs, or explicit shared contracts. See `docs/project_core_architecture_proposal.md`.
