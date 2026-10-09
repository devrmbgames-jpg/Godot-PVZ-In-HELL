@tool
extends E_GrabbableBody
## Физический placeholder содержимого; общие impact/hazard владельцы обрабатывают эффекты.
class_name E_PackageContent

#region Авторские параметры содержимого
## Профиль общего расчёта удара для физического содержимого.
@export var impact_profile: DEF_ImpactProfile = preload("res://content/domains/combat/definitions/def_impact_default.tres")
## Необязательная сцена самостоятельной опасности содержимого.
@export var hazard_scene: PackedScene = null

#endregion
