extends Observer
## Сообщает Time о настроенной Night preparation; фактический workflow принадлежит S_NightSave.
class_name O_NightPreparationRequirement

#region Configured Night owner
## Отвечает только для сессии с authoritative autosave workflow.
func query() -> QueryBuilder:
	return q.with_all([C_Autosave]).on_event(NightPreparationRequirement.EVENT)


## Синхронно удерживает ночь до результата существующего persistence owner.
func each(_event: Variant, _session: Entity, payload: Variant = null) -> void:
	var request: NightPreparationRequirement = payload as NightPreparationRequirement
	assert(request != null)
	request.require_preparation()
#endregion
