extends Component
## Связывает живое задание с настоящей посылкой независимо от видимого номера.
## target — parcel Entity; resolve удаляет binding, restore пересобирает по record.package_id.
## Отсутствующий parcel не создаётся из Relationship; постоянный исход принадлежит record.
class_name R_TargetsPackage
