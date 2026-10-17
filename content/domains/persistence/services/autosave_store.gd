extends RefCounted
## Сериализуемые данные с SHA-256; временный файл заменяет локальный слот после записи.
class_name AutosaveStore

const DEFAULT_PATH: String = "user://autosave.pvzh"
const MAGIC: String = "PVZH1"
## Версия закрытой схемы; прежний формат отклоняется без миграции и удаления.
const SCHEMA_VERSION: int = 33
## Writer limits payload bytes; read limits the whole file, including header overhead.
## The 64 MiB edge mismatch is documented in docs/persistence.md; this is not a unified file limit.
const MAX_BYTES: int = 64 * 1024 * 1024


## Записывает payload и SHA-256 во временный файл, затем заменяет слот; возвращает Error.
## Synchronous storage only: caller owns schema/semantic preflight. OK includes rename completion.
## Uses path + .tmp, flush/close; no readback, backup or guaranteed power-loss recovery.
static func write(snapshot: Dictionary, path: String = DEFAULT_PATH) -> Error:
	if path.is_empty():
		return ERR_INVALID_PARAMETER
	var payload: PackedByteArray = var_to_bytes(snapshot)
	if payload.is_empty() or payload.size() > MAX_BYTES:
		return ERR_INVALID_DATA

	var temporary: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()

	file.store_line(MAGIC)
	file.store_line(_digest(payload))
	file.store_buffer(payload)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK:
		return error
	return (
		DirAccess.rename_absolute(
			ProjectSettings.globalize_path(temporary),
			ProjectSettings.globalize_path(path),
		)
	)


## Проверяет заголовок, размер и хеш; пустой словарь означает отсутствие/повреждение файла.
## Decodes without enabling Objects; a Dictionary root still needs version/semantic can_restore.
## Caller checks file_exists to distinguish a missing slot from a rejected existing one.
static func read(path: String = DEFAULT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return { }

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return { }
	if file.get_line() != MAGIC:
		return { }

	var digest: String = file.get_line()
	var payload: PackedByteArray = file.get_buffer(file.get_length() - file.get_position())
	file.close()
	if _digest(payload) != digest:
		return { }

	var decoded: Variant = bytes_to_var(payload)
	return decoded as Dictionary if decoded is Dictionary else { }


static func _digest(payload: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(payload)
	return context.finish().hex_encode()
