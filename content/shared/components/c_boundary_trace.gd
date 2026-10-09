extends Component
## Transient ECS-owned diagnostics; BoundaryTrace is the sole writer, never a gameplay ledger.
class_name C_BoundaryTrace

## Bounded terminal/pending history, intentionally excluded from save snapshots.
var entries: Array[BoundaryTraceEntry] = []
## Next diagnostic sequence; resets with the session rather than persisting gameplay identity.
var next_sequence: int = 1
## Next transient correlation for operations without a domain operation ID.
var next_correlation: int = 1
