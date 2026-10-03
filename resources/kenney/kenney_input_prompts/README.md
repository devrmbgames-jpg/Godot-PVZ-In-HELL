# Иконки управления

Проект использует отдельные PNG в `<family>/Default/`: keyboard_mouse, xbox_series, playstation_series, steam_controller, steam_deck.

`InputPromptCatalog` предпочитает `<button>_outline.png`; если его нет, загружает `<button>.png`. PNG импортируется как Texture2D целиком, без AtlasTexture и координат XML. Для неподдерживаемых кнопок `InputPromptService` выбирает иконку устройства. HUD/UI/settings используют фактические InputMap bindings и направления осей.

Ранее сгенерированные `.res`, XML/PNG-листы и генератор удалены по замечанию владельца: изображения не соответствовали регионам XML. Предоставленные отдельные спрайты не изменялись. Double/generic варианты остаются доступны автору, текущий UI использует Default при размере подсказки32px.
