extends Component
## Single-shot resolution guard independent of the source object's lifecycle.
class_name C_Explosion

## Committed before querying targets or publishing damage, preventing recursive re-entry.
var resolved: bool = false
