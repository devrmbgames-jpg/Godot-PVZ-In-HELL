# Godot 4.7.1 memory and lifetime diagnostics

Use only for a suspected runtime memory growth, leaked Entity/Node/Resource, invalid destruction or engine shutdown retention report. This is the detailed acceptance procedure, not a mandatory test for every change.

## Owner-approved engine limitation

Per owner decision, warnings involving retained `GDScript`, `GDScriptNativeClass`, `Resource`, `StringName` and RID arising **only during Godot 4.7.1 editor/process shutdown** are `KNOWN_ENGINE_LIMITATION / DEFERRED`. They are diagnostic evidence, not standalone proof of a game memory leak or a milestone blocker. Preserve the logs but do not suppress warnings globally, open a separate investigation, or change GDScript typing/reference management, `WeakRef`, `free()` or GECS architecture solely to remove these shutdown warnings.

Reassess this particular category after moving to stable Godot **4.8+**, checking the relevant upstream fixes then. Godot 4.7.2 adoption is not planned. Shutdown-only warnings in the deferred category do **not** by themselves require a new lifecycle repetition test.

## Actual regressions remain defects

Sustained growth during equivalent gameplay operations; Nodes/Objects surviving an ended owned lifecycle; unbounded references or containers; use-after-free, double-free and ownership violations are real bugs and remain in scope regardless of shutdown diagnostics.

One-time allocations, pooled/reused allocations, bounded caches/services and allocator high-water marks are not leaks by themselves.

## When growth is suspected

1. Use the same scenario, engine, addons, settings and measurement gates for baseline vs changed revision. Separate editor shutdown from live gameplay and reproduce the relevant lifecycle.
2. Warm up, then repeat the lifecycle **50–100 times inside one process**. Settle `queue_free()`, deferred calls and queued events before sampling. Do not schedule this expensive procedure merely because deferred shutdown warnings appear.
3. Sample RSS/Private Bytes and available Godot static-memory, Object, Resource, Node and orphan monitors, where instrumentation exists. Keep the harness's logs/history/buffers bounded so it cannot create growth itself.
4. Compare post-warmup and tail trends and inspect which owned objects actually survive. A stable plateau after warmup with shutdown-only retention is not a proven leak.
5. Repair only evidenced ownership/lifecycle defects and re-run focused comparable evidence.

Nodes/plain Objects may need `free()`/`queue_free()` according to their owner and safe lifecycle; `RefCounted`/`Resource` normally release via reference counting. `WeakRef` does not own the target but containers holding weak references still need bounded cleanup. Do not blindly add or remove frees, null guards or weak refs.

## Completion classification

Record PASS/FAIL/NOT_RUN for the actual measured gates. When only the specified shutdown retention remains, record the baseline and `KNOWN_ENGINE_LIMITATION / DEFERRED`, not a fake PASS or blocking live leak. Preserve genuine parser/reload warnings and runtime diagnostics as actionable.
