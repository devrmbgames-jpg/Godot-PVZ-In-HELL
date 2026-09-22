extends RefCounted
## One independent capture token with a weak owner and its input priority.
class_name InteractionControlCapture

var owner: WeakRef = null
var priority: int = 0
