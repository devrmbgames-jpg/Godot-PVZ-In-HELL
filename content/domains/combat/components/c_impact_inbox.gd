extends Component
## Очередь снимков тела: физический capture пишет, S_Impact забирает контакты.
class_name C_ImpactInbox

## Снимки физического capture до drain S_Impact; rigid capture заменяет, CharacterBody добавляет.
var contacts: Array[PhysicsContact] = []
## Разделения кинематических тел, сообщаемые мостом вместо отсутствующего body_exited.
var separations: Array[PhysicsContact] = []
