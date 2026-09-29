# Кнопка посылки с краткой информацией об ней и ее статусом
# TODO Функционал необходимо доделать

extends PanelContainer
class_name UI_TerminalButtonPackage

signal pressed()
signal button_down()
signal button_up()
signal toggled(toggled_on: bool)


## Основная зона клика
@onready var _button_body: Button = %Button
## Иконка пакета
@onready var _icon_preview_package: TextureRect = %TexturePreviewPackage
## Номер посылки
@onready var _label_number_info: Label = %LabelNumber
## Статус посылки (Выдана/Отказ/Выкуплена/Потеряна)
@onready var _label_status_info: Label = %LabelStatus

# Кнопки "забрали/отказались/утеряна" отвечают за всю логику в терминале.
# игрок может не сообщать об утере посылки, надеясь что это ему сойдет с рук.
# игрок может не относить посылку в зону выгрузки/погрузки, если хочет выкупить посылку, от которой отказались.
# игрок может нажать "забрали", даже если не планирует отдавать посылку клиенту. А клиенту в диалоге отказать в выдачи
## Кнопка (Посылку забрали)
@onready var _button_ok: Button = %ButtonOK
## Кнопка (От посылки отказались/игрок присвоил ее себе)
@onready var _button_cancel: Button = %ButtonCancel
## Кнопка (Посылка утеряна/уничтожена)
@onready var _button_lost: Button = %ButtonLost

## Контейнер с иконками статусов
@onready var _icons_statuses_container: Control = %IconsStatusesType

## Иконки статусов, названия говорят сами за себя
@onready var _icon_status_explotion: Control = %IconExplotion #взрывающийся
@onready var _icon_status_toxic: Control     = %IconToxic #токсичная
@onready var _icon_status_psico: Control     = %IconPsico #психическая
@onready var _icon_status_fire: Control      = %IconFire #огнеопасная
@onready var _icon_status_weight: Control    = %IconWeight #тяжелая
@onready var _icon_status_anomaly: Control   = %IconAnomaly #аномальная
@onready var _icon_status_light: Control     = %IconLight #электризованная
@onready var _icon_status_fragile: Control   = %IconFragile #хрупкая
@onready var _icon_status_fluid: Control     = %IconFluid #протекающая (держать вертикально)

## Ожидаемая ценность посылки
@onready var _label_price: Label = %LabelPrice

## Краткое описание посылки
@onready var _label_description_short: Label = %LabelDescriptionShort


### Клики на основную кнопку

func _on_button_pressed() -> void:
	pressed.emit()


func _on_button_toggled(toggled_on: bool) -> void:
	toggled.emit(toggled_on)


func _on_button_button_down() -> void:
	button_down.emit()


func _on_button_button_up() -> void:
	button_up.emit()
