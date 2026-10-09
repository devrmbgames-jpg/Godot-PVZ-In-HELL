extends System
## После смены фазы однократно отмечает завершённую смену в кошельке.
class_name S_WalletDay


## Выполняется после системы фаз, чтобы прочитать новое состояние дня.
func deps() -> Dictionary[int, Array]:
	return { Runs.After: [S_DayPhase] }


## Выбирает сессионные кошельки с игровым циклом.
func query() -> QueryBuilder:
	return q.with_all([C_Wallet, C_DayCycle]).iterate([C_Wallet, C_DayCycle])


## Синхронизирует итог дня через WalletService без прямой арифметики.
func process(_entities: Array[Entity], components: Array, _delta: float) -> void:
	var wallets: Array = components[0]
	var cycles: Array = components[1]
	for index: int in wallets.size():
		WalletService.sync_day(wallets[index] as C_Wallet, cycles[index] as C_DayCycle)
