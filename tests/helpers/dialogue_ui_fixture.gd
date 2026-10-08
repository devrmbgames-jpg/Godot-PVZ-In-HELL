extends RefCounted
## Минимальная fixture composition реального World-to-native dialogue adapter.
class_name DialogueUiFixture

#region Реальный UI adapter
## Устанавливает один production consumer в изолированном World без дублирования логики UI.
static func install() -> void:
	for observer: Observer in ECS.world.observers:
		if observer is O_DialoguePanelRequest:
			return
	ECS.world.add_observer(O_DialoguePanelRequest.new())
#endregion
