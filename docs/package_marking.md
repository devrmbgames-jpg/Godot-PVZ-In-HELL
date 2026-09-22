# Package marking (R07)

`marker.tscn` is a physical hand item with Inspector-authored `C_Marker`, `C_Grabbable` and `C_InteractionActionSet`. `DEF_MarkAction` starts through `InteractionActionResolver`; the resolver maps PRIMARY tool use to the occupied physical hand and honors `swap_hand_controls`. Carry and Push retain their existing higher priority over idle hands.

## Drawing controls

Aim at a package and press the marker hand's use button (normally right hand LMB, left hand RMB). Drawing acquires a distinct DRAWING token, above Push and below MODAL, without changing item ownership or mouse mode. The camera direction and movement intent remain fixed while mouse motion moves an amber viewport pointer. Hold the same mapped button to write; release it to lift the tip and reposition. E or Esc exits; normal look resumes on the next input tick. Other hand actions and generic rotation cannot consume drawing input. A higher modal capture cancels drawing and keeps its own token.

`S_Marker` runs after `S_Grab` in Interaction. Each sample uses the camera's projected pointer ray and `C_Interactor.collision_mask`, excludes only the actor and marker body, and accepts only the first hit within the marker's range. Walls and other physical objects occlude ink. Starting also revalidates the existing targeting ray. Lost/disabled ownership, holder defeat and marker removal end the session; Grab lifecycle cleanup releases the drawing token synchronously.

## Ink ownership and rendering

Each Package scene authors a separate `C_PackageMarks`. `PackageMarkStroke` stores ordered local points, local face normal, width and color. S_Marker transforms first-hit world coordinates into Package space. The current box-shaped package model slightly exceeds its collider on some faces: `E_Package.marking_surface` supplies the own-child visual mesh, and S_Marker projects onto the corresponding visible mesh-bounds plane before applying a small outward offset. Physics still validates the first hit before projection. Future non-box package models need a matching surface projection contract. Button release, misses, occluders, package changes, face-normal changes and large sample gaps split strokes. Sample spacing and a per-package point budget bound geometry/memory. At the budget limit the package accepts no more ink; existing marks remain.

`PackageMarksView`, a child MeshInstance3D, builds ink geometry only when the data revision changes. Moving/rotating a package moves the child mesh without changing sample data. Target highlighting skips ink geometry, preserving the authored ink color. Presentation never updates domain state. `S_Damage` clears ink when package integrity reaches DESTROYED; freeing a package frees its child mesh and component data. Marks never register a package, assign a shelf, alter warehouse numbers or supply Terminal information.

## Physical storage

`content/entities/props/numbered_shelves.tscn` is an authored StaticBody3D with six numbered compartments, solid boards, sides, dividers and a back. The main level places it against the warehouse wall at (6, 0, -7.2), clear of the doorway. Lower compartments are 01–03, upper compartments 04–06. Number plates are world-space Label3D presentation. Packages settle on shelves through Godot collision/gravity; shelves have no gameplay component, package assignment or connection to the Terminal ledger. Placement and mnemonic marks are the player's own organization system.

## R21 persistence boundary

Ink is currently runtime-only and survives day changes while the Package remains alive. R21 should serialize marks under `C_Package.package_id`, independently of reusable warehouse registration numbers: ordered strokes containing local points, face normal, width and color, plus a format version. Reconstruct point count and revision on load; validate finite values and enforce the point budget. Exclude temporary marker actor/capture/pointer/continuity state and generated mesh data. Destroyed packages restore no marks. No OCR, automatic shelf association or save implementation is included in R07.

## Validation

Existing `test_s_grab.gd` covers local transforms, split faces, point budgets, destroyed-package rejection, capture cancellation and look restoration. `tests/smoke/marker_shelves_smoke.tscn` exercises the actual level and raycasts: scanner registration, both hand mappings/swap, continuous ink, front/side faces, occlusion, release/E/Esc, generated geometry, physical settling in compartment 05, unchanged Terminal data and authoritative damage cleanup. Require its PASS marker; `--quit-after 360` is a safety limit rather than a success condition.

Run with rendering and `-- --preview` to save ignored `tests/artifacts/r07_shelves_preview.png` and `r07_marks_preview.png`. Automated rendering verifies visible scene output; subjective mouse feel remains a human playtest concern.
