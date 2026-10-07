# Refactoring v2.13 — Customer outcomes, settlement и reactive transitions

Status: **PLANNED**

Зависимости: [12_customer_flow_runtime.md](12_customer_flow_runtime.md).

## Goal

Отделить outcome/settlement/reactive последствия от регулярного Customer tick и убрать polling там, где результат уже является дискретным событием.

## Scope

Аудировать:
- `CustomerOutcomeService`;
- complaint resolution;
- settlement/payment;
- delivered/lost/refused/fraud/missed registration;
- inspection completion;
- customer death/disappearance outcomes;
- challenge/customer outcome bridge.

## Direction

- one-shot финансовая операция может оставаться Service transaction;
- реакция на завершённый outcome должна быть Observer/event там, где это естественно;
- presentation/dialogue не становится authority;
- idempotency IDs и существующая экономика сохраняются.

## Acceptance

- outcome authority и settlement boundary явно разделены;
- нет повторного frame polling уже завершённых состояний без необходимости;
- однократность платежей/штрафов сохранена.

## Validation

Customer outcome + wallet/economy regression tests, parser.
