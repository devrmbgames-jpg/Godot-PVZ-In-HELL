extends RefCounted
## One synchronous panel-owner response; reader identity is retained only weakly.
class_name TerminalPanelStateQuery

var _open: bool = false
var _requested_reader: WeakRef = null
var _reader_matches: bool = false


#region Visibility response
func _init(reader: Entity = null) -> void:
	if reader != null:
		_requested_reader = weakref(reader)


## Records native visibility and the actual reader without retaining either live owner.
func record_open(visible: bool, reader: Entity = null) -> void:
	_open = visible
	_reader_matches = (
		visible and reader != null and _requested_reader != null
		and _requested_reader.get_ref() == reader
	)


## Returns the visibility reported by the native panel.
func is_open() -> bool:
	return _open


## Returns whether the native panel is open for this request's exact reader.
func is_open_for_reader() -> bool:
	return _reader_matches
#endregion
