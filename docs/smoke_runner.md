# Запуск smoke-проверок

`utils/run_smoke.ps1` запускает smoke-сцены Godot в headless-режиме. Скрипт ищет сцены `*_smoke.tscn` в `tests/smoke`, требует строку `PASS` в журнале и считает ошибкой ненулевой код завершения, `SCRIPT ERROR`, `Parse Error`, `Assertion failed` или релевантную строку `ERROR`.

В PowerShell из любой рабочей директории:

```powershell
& "D:\DEV\pvz-in-hell-simulator\utils\run_smoke.ps1" -List
& "D:\DEV\pvz-in-hell-simulator\utils\run_smoke.ps1" -Name hazards
& "D:\DEV\pvz-in-hell-simulator\utils\run_smoke.ps1" -All
```

Имя после `-Name` — имя файла без суффикса `_smoke.tscn`: например, `cart_transport` для `cart_transport_smoke.tscn`. По умолчанию используется `hazards`.

Чтобы явно указать исполняемый файл Godot или изменить лимит кадров:

```powershell
& ".\utils\run_smoke.ps1" -Name hazards -GodotPath "C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe"
& ".\utils\run_smoke.ps1" -Name cart_transport -Frames 3000
```

Приоритет поиска Godot: `-GodotPath`, переменная окружения `GODOT_BIN`, `PATH`, затем `godotTools.editorPath.godot4` из `.vscode/settings.json`. В Windows скрипт предпочитает соседний файл `*_console.exe`, если он существует.

Лимит по умолчанию — 360 кадров; для `cart_transport` — 2400. Параметр `-Frames` всегда имеет приоритет. Журналы сохраняются в игнорируемой Git папке `tests/artifacts/`. Скрипт печатает краткий результат `PASS` или `FAIL` с путём к журналу и возвращает ненулевой код, если хотя бы одна проверка не прошла.