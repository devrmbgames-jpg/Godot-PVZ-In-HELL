extends Component
## Маркер стойки выдачи; физические коробки и авторские точки доступны через E_DeliveryCounter.
class_name C_DeliveryCounter

## Maximum linear speed in m/s for a parcel deliberately resting on the counter or a stable stack.
@export_range(0.0, 1.0, 0.01) var settled_linear_speed_mps: float = 0.15
## Maximum angular speed in radians/s for a resting offered parcel or its supporting parcels.
@export_range(0.0, 2.0, 0.01) var settled_angular_speed_rps: float = 0.25
## Native contact tolerance in metres when tracing support under a parcel's physical bounds.
@export_range(0.001, 0.03, 0.001) var support_tolerance_m: float = 0.01
