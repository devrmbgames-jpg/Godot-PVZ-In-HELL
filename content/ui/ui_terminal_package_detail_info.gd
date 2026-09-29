# Детальная информация об посылки
# TODO Необходимо доделать
extends PanelContainer
class_name UI_TerminalPackageDetailInfo

## Иконка привью посылки
@onready var _icon_preview: TextureRect = %TextureIconPreview
## ID посылки который присвоил игрок сканером
@onready var _label_package_id: Label = %LabelID
## UID посылки присвоиный системой при создании, для истори и отладки
@onready var _label_package_uid: Label = %LabelUID
## Название посылки (например "Посуда")
@onready var _label_package_name: Label = %LabelName
## Контейнер для картинок. Например тут могут быть дополнительные картинки об содержании посылки. Что бы заинтересовать игрока вскрыть ее
@onready var _contaner_images: Control = %HBoxContainerImages
## Детальное описание посылки с подробностями, если надо.
@onready var _rich_label_description: RichTextLabel = %RichTextLabelDescription
