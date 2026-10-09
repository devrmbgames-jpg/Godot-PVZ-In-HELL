extends RefCounted
## Минимальная fixture composition реального World-to-native dialogue adapter.
class_name DialogueUiFixture

#region Реальный UI adapter
## Устанавливает один production consumer в изолированном World без дублирования логики UI.
static func install() -> void:
	for observer_type: Script in [O_DialoguePanelRequest, O_GameplayPanelRequest]:
		var installed: bool = false
		for observer: Observer in ECS.world.observers:
			if observer.get_script() == observer_type:
				installed = true
				break
		if not installed:
			ECS.world.add_observer(observer_type.new() as Observer)
#endregion
