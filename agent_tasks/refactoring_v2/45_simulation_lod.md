# Refactoring v2.45 — NPC Simulation LOD

Status: **PLANNED**

Зависимости: AI stack и authoritative identity/time.

## Goal

Разделить физическое представление NPC и macro simulation, чтобы население могло жить без постоянных Node3D/physics/BT.

## Levels

- LOD0: full physical Entity + LimboAI;
- LOD1: active district, reduced cadence;
- LOD2: record/ECS macro simulation without physical body;
- LOD3: event/time mathematical simulation.

## Work

- materialize/dematerialize contract;
- stable identity;
- travel/arrival macro state;
- reservation/goal behavior при LOD transition;
- save/restore;
- deterministic transition tests.

## Acceptance

Representative NPC может уйти из physical representation, продолжить macro lifecycle и восстановиться без duplicate identity/state.

## Validation

LOD transition tests + save/restore smoke + performance sanity check.
