extends Component
## Receiver-side impact protection; R19 may change the tier when applying Bubble Wrap.
class_name C_ImpactProtection

## Fully blocks physical severity up to this tier; stronger impacts pass without reduction.
@export var tier: ImpactResult.Severity = ImpactResult.Severity.None
