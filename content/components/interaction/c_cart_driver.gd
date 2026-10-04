extends Component
## Временный обратный индекс актора, управляющего транспортной тележкой.
class_name C_CartDriver

## Восстанавливаемый кеш; единственная авторитетная связь — R_CartDrivenBy на тележке.
var cart: Entity = null
