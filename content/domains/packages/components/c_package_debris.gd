extends Component
## Идентичность обломков, сохраняемая после удаления исходной сущности коробки.
class_name C_PackageDebris

## Постоянный ID уничтоженной посылки.
var package_id: String = ""
## Авторские данные исходной посылки для обработки обломков.
var definition: DEF_Package = null
