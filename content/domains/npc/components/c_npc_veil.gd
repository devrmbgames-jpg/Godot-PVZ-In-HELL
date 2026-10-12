extends Component
## Transient native leaf-owned escape form; never part of the save inventory.
class_name C_NpcVeil

enum Form {
	VISIBLE,
	CLOUD,
	INVISIBLE,
}

## Explicit NpcVeilService transitions own this appearance state.
var form: Form = Form.VISIBLE
## Native task incarnation; an interrupted old leaf cannot reveal its replacement.
var task_id: int = 0
