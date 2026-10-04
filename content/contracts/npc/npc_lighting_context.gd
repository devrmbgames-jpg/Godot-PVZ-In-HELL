extends RefCounted
## Зоны света текущего уровня; выключатель и геометрия читаются актуальными.
class_name NpcLightingContext

## Зоны текущего уровня; объёмы других загруженных сцен исключаются.
var zones: Array[NpcLightZone] = []
