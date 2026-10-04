extends Component
## Данные связи нефизического опасного эффекта с владельцем следования.
class_name R_HazardFollow

## Локальная поза относительно владельца в Relationship.target; отдельной ссылки владельца нет.
var local_offset: Transform3D = Transform3D.IDENTITY
## Отсоединение либо удаление после недоступности владельца.
var on_loss: DEF_Hazard.OwnerLoss = DEF_Hazard.OwnerLoss.Detach
