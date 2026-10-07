# Shared gameplay infrastructure

`content/shared/<role>/` is reserved for infrastructure that is genuinely used across multiple gameplay domains and has no honest single domain owner.

Use the same canonical role directories as `content/domains/<domain>/`.

Do not move code here merely because choosing an owner is inconvenient. Prefer a concrete domain owner unless the contract is truly cross-domain/foundational.

UI `Control` glue is not ECS infrastructure and should not be moved here merely for architectural symmetry.

The canonical role-folder vocabulary is validated by `utils/validate_domain_structure.py`.
