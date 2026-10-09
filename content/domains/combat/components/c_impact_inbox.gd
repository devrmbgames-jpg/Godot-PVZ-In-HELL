extends Component
## Очередь снимков тела: физический capture пишет, S_Impact забирает контакты.
class_name C_ImpactInbox

## Контакты последнего физического callback, ограниченные лимитом отчётности тела.
var contacts: Array[PhysicsContact] = []
## Разделения кинематических тел, сообщаемые мостом вместо отсутствующего body_exited.
var separations: Array[PhysicsContact] = []
