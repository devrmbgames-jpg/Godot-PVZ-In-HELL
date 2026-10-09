@tool
extends E_GrabbableBody
## Физический ручной сканер; действие выполняет регистрацию и сообщает результат через сигнал.
class_name E_Scanner

## Результат действия сканирования для представления обратной связи.
signal scan_feedback(result: PackageScanResult)
