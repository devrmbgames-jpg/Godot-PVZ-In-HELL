extends System
class_name S_WalletDay


func deps() -> Dictionary[int, Array]:
	return { Runs.After: [S_DayPhase] }


func query() -> QueryBuilder:
	return q.with_all([C_Wallet, C_DayCycle]).iterate([C_Wallet, C_DayCycle])


func process(_entities: Array[Entity], components: Array, _delta: float) -> void:
	var wallets: Array = components[0]
	var cycles: Array = components[1]
	for index: int in wallets.size():
		WalletService.sync_day(wallets[index] as C_Wallet, cycles[index] as C_DayCycle)
