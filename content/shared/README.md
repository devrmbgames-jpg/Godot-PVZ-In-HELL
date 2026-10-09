# Shared gameplay foundations

`content/shared/<canonical role>/` contains a small domain-independent kernel with concrete consumers. Multiple consumers alone do not remove honest domain ownership: health/damage belongs combat, native motion bodies belong motion, and live inventory ownership belongs inventory.

Approved migration candidates are listed explicitly in `utils/domain_migration_map.json`: immutable authored/persistent actor identity and authoring compiler; foundational definition/attribute/object-description contracts; bounded boundary-trace data/writer/read provider; stable link vocabulary; native body availability and placement algorithms; domain-independent Dialogue Manager resource-reference cleanup. None owns a gameplay scheduler or duplicates mutable gameplay authority.

Shared imports no domains or global gameplay implementation. C_ActorIdentityReference projects the existing domain-owned ID fields through read-only methods, with no stored mirror, alias registry or allocation. ActorIdentityRules selects canonical actor/diagnostic keys; BoundaryTrace owns only bounded diagnostic recording and reading. Global UI/scene/debug projection remains Godot glue.

Use canonical role folders only; create no empty roles. The source-owner/public-symbol access manifest (`utils/domain_contracts.json`) still applies: public visibility and a shared folder do not authorize arbitrary field writes. Component aggregates and live Relationships retain their explicit writers.
