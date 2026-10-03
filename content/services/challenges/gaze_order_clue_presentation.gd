extends RefCounted
## Read-only wall presentation. Visit, challenge binding and registry remain authoritative.
class_name GazeOrderCluePresentation

const CLUE_GROUP: StringName = &"gaze_order_clues"


static func text_for(clue: Node) -> String:
	if not clue.is_inside_tree() or not is_instance_valid(ECS.world):
		return ""
	var locations: Array[Node] = clue.get_tree().get_nodes_in_group(CLUE_GROUP)
	locations.sort_custom(func(a: Node, b: Node) -> bool: return String(a.get_path()) < String(b.get_path()))
	if locations.is_empty():
		return ""
	for subject: Entity in ECS.world.query.with_all([C_Challenge, C_CustomerAgent]).execute():
		var state: C_Challenge = subject.get_component(C_Challenge) as C_Challenge
		var agent: C_CustomerAgent = subject.get_component(C_CustomerAgent) as C_CustomerAgent
		var visit: CustomerVisit = CustomerFlowService.find_visit(agent.visit_id)
		if state.phase != C_Challenge.Phase.ACTIVE or not ChallengeService.session_valid(subject) or visit == null or not CustomerPresentation.uses_wall_order(visit.definition):
			continue
		var selected: int = int(String(visit.visit_id).hash() % locations.size())
		if locations[selected] == clue:
			var number: int = CustomerPresentation.registered_number(visit)
			return "ЗАКАЗ\n№%03d" % number if number >= 0 else ""
	return ""
