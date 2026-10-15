extends Component
## Идентичность обломков, сохраняемая после удаления исходной сущности коробки.
## Это live metadata из configure_source; поля C_PackageDebris в closed save codec не входят.
class_name C_PackageDebris

## Постоянный ID уничтоженной посылки.
var package_id: String = ""
## Авторские данные исходной посылки для обработки обломков.
var definition: DEF_Package = null
