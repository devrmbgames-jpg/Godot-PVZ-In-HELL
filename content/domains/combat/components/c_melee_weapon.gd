extends Component
## Авторское оружие: описание удара и визуальная анимация.
class_name C_MeleeWeapon

## Авторское определение удара оружием игрока.
@export var attack: DEF_MeleeAttack = null
## Путь от оружия к AnimationPlayer только визуальных узлов.
@export var animation_player_path: NodePath = NodePath("AttackAnimation")
## Имя визуального замаха; отсутствие клипа не запрещает боевое действие.
@export var strike_animation: StringName = &"strike"
