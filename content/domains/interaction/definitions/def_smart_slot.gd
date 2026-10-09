@tool
extends Resource
## Authored service position; the marker presents a slot and never owns its occupancy.
class_name DEF_SmartSlot

## Unique key within the Smart Object, independent of node names and instance IDs.
@export var slot_id: StringName = &""
## Local Marker3D path on each visible object instance.
@export var marker: NodePath = NodePath()
