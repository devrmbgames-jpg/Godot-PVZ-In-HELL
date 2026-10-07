# Refactoring v2.32 — shared core и удаление horizontal gameplay roots

Status: **PLANNED**

Зависимости: domain migrations 29–31 завершены.

## Goal

Оставить в `content/shared/` только настоящий cross-domain infrastructure и убрать legacy horizontal gameplay layout.

## Work

- классифицировать всё оставшееся в старых `components/services/systems/... `;
- перенести genuine shared contracts/rules/authoring infrastructure в `content/shared/<role>/`;
- вернуть domain-specific leftovers владельцу;
- удалить пустые legacy gameplay roots;
- не переносить UI Control glue в ECS/shared без необходимости.

## Acceptance

`python utils/validate_domain_structure.py --strict` PASS.
Legacy horizontal gameplay roots отсутствуют.
Новый разработчик определяет owner файла по пути без глобального поиска по role root.

## Validation

Strict domain validator + project structure + parser all moved scripts.
