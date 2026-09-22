# Current Work

- State: active R07; marker stage complete, shelves next. Base master/32f09a1.
- Contract: docs/package_marking.md; hand mapping, DRAWING capture, E/Esc exit, first-hit rays, bounded local strokes, destruction cleanup. No OCR/shelf tracking.
- Paths: S_Marker/C_Marker/C_PackageMarks, marker.tscn, package_marks_view.gd, existing input/resolver/Grab lifecycle, marker_shelves_smoke.tscn; routes in PROJECT_INDEX.md.
- Validation: 68/68 GUT tests (324 asserts), four smoke checks PASS; structure/formatter/diff PASS. Godot root-certificate warning is environmental. Preserve dirty addons/gecs.
- Next: create numbered physical shelf scene, place in main_level.tscn, extend marker_shelves_smoke with physical storage/render preview.
