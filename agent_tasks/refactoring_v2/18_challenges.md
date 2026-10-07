# Refactoring v2.18 — Challenge lifecycle

Status: **PLANNED**

Зависимости: service inventory завершён, Customer outcome boundary определён.

## Goal

Перенести общий time-based Challenge lifecycle из `ChallengeService.tick` в `S_ChallengeRuntime` либо несколько явных Systems/Observers.

## Preserve

- arm/activate/cancel explicit API;
- condition Systems;
- Challenge actor/effect Relationships;
- result publication и presentation separation.

## Direction

`ChallengeService` может сохранить one-shot session commands и lookup.
Elapsed/timeout/result display/cleanup progression принадлежит System.
Discrete resolution/cleanup может перейти в Observer, если это упрощает ownership.

## Acceptance

`S_ChallengeRuntime` больше не является wrapper вокруг service tick.
Condition computation, lifecycle и outcome consequences имеют отдельные понятные владельцы.

## Validation

Challenge light/gaze/floor/runtime tests + parser.
