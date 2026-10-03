# Иконки управления Kenney

1416 отдельных binary AtlasTexture: пять семейств, default/double. PNG остаются общими листами; картинки не нарезаются.

Генерация: `.bin/Godot_v4.7.1-stable_win64_console.exe --headless --path . -s utils/generate_input_prompt_atlases.gd`.

Генератор проверяет границы/дубликаты и чтение каждого .res; неизменённые ресурсы не перезаписывает. Источники — XML и PNG, предоставленные в resources/kenney/kenney_input_prompts/. Для работы генератора нужны импортированные PNG.

PromptAtlasCatalog.texture использует готовый .res. Только если его нет, таблица соответствующего XML читается один раз и кешируется. Указание области берётся из XML, не из имён отдельных изображений.
