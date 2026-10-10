@tool
extends E_TraitedEntity
## Авторские узлы головы, коллайдеров и взаимодействия для обоих физических типов персонажа.
class_name E_PhysicalCharacter

@export_subgroup("Interaction")
## Авторский луч выбора цели взаимодействия от головы.
@export var interaction_ray_cast: RayCast3D = null
## Мировое крепление физического удержания перед персонажем.
@export var hold_anchor: Node3D = null
## Крепление предмета в поднятой правой руке.
@export var right_hand_slot: Node3D = null
## Крепление предмета в поднятой левой руке.
@export var left_hand_slot: Node3D = null
## Крепление предмета в опущенной правой руке.
@export var lowered_right_hand_slot: Node3D = null
## Крепление предмета в опущенной левой руке.
@export var lowered_left_hand_slot: Node3D = null

@export_subgroup("Crouch")
## Коллайдер стоящего персонажа, переключаемый S_Crouch.
@export var shape_standing: CollisionShape3D
## Коллайдер присевшего персонажа, переключаемый S_Crouch.
@export var shape_crouching: CollisionShape3D
## Общий корень камеры, луча и креплений удержания; приседание смещает его целиком.
@export var camera_root: Node3D
## Луч проверки свободного места для возвращения в стойку.
@export var ray_standing: RayCast3D
## Крепления на теле: следуют высоте приседания, не вращению камеры.
@export var crouch_mounts: Array[Node3D] = []

@export_subgroup("Look")
## Узел горизонтального поворота головы относительно корпуса.
@export var head_axis_y: Node3D
## Узел вертикального поворота головы относительно горизонтальной оси.
@export var head_axis_x: Node3D
