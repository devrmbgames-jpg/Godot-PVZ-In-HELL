extends Component
## Runtime ink owned by one package; R21 may serialize it under the stable package ID.
class_name C_PackageMarks

## Ordered package-local strokes, independent of registration and shelf placement.
var strokes: Array[PackageMarkStroke] = []
## Total sample count and presentation revision, written only by PackageMarkService.
var point_count: int = 0
var revision: int = 0
