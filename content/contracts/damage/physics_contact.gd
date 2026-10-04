extends RefCounted
## Снимок контакта физических тел; скорость и импульс вдоль нормали заданы в СИ.
class_name PhysicsContact

## Первое физическое тело; окружение может не быть Entity.
var body_a: PhysicsBody3D = null
## Второе физическое тело контакта; не обязательно Entity.
var body_b: PhysicsBody3D = null
## Физический такт снимка, отдельно от кадров рендера.
var tick: int = 0
## Неотрицательная скорость сближения вдоль нормали в м/с.
var normal_speed: float = 0.0
## Нормальная величина импульса контакта в Н·с.
var normal_impulse: float = 0.0
## Мировая нормаль к body_a для отложенного кинематического отскока.
var normal_on_a: Vector3 = Vector3.ZERO
