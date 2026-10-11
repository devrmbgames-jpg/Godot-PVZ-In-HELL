@tool
extends Component
## Pure blood-zone capability; carries no damage amount, health operation or separate clock.
class_name C_BloodArea

## Closed persistence preserves this marker; TTL belongs to C_HazardLifetime.
const SAVE_FIELDS: Array[String] = []
