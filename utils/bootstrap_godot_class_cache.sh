#!/usr/bin/env bash
set -euo pipefail

# Godot writes global_script_class_cache.cfg during the first editor filesystem pass,
# before EditorFileSystem::_update_scan_actions() starts reimporting normal assets.
# GUT needs the class cache, not a complete import of thousands of SVG/PNG files.
# Stop the editor as soon as the cache is durable instead of using --import.

GODOT_BIN="${GODOT_BIN:-godot}"
PROJECT_DIR="${1:-.}"
TIMEOUT_SECONDS="${GODOT_CLASS_CACHE_TIMEOUT_SECONDS:-90}"
POLL_SECONDS="${GODOT_CLASS_CACHE_POLL_SECONDS:-0.05}"
CACHE_PATH="${PROJECT_DIR%/}/.godot/global_script_class_cache.cfg"
LOG_PATH="${GODOT_CLASS_CACHE_LOG:-${PROJECT_DIR%/}/godot-class-cache.log}"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
	echo "Godot executable not found: $GODOT_BIN" >&2
	exit 1
fi

rm -f "$CACHE_PATH"
mkdir -p "$(dirname "$CACHE_PATH")"

"$GODOT_BIN" --headless --editor --path "$PROJECT_DIR" >"$LOG_PATH" 2>&1 &
godot_pid=$!

stop_godot() {
	if kill -0 "$godot_pid" 2>/dev/null; then
		kill -TERM "$godot_pid" 2>/dev/null || true
		for _attempt in {1..20}; do
			if ! kill -0 "$godot_pid" 2>/dev/null; then
				break
			fi
			sleep 0.05
		done
	fi
	if kill -0 "$godot_pid" 2>/dev/null; then
		kill -KILL "$godot_pid" 2>/dev/null || true
	fi
	wait "$godot_pid" 2>/dev/null || true
}

trap stop_godot EXIT

deadline=$((SECONDS + TIMEOUT_SECONDS))
while (( SECONDS < deadline )); do
	if [[ -s "$CACHE_PATH" ]]; then
		stop_godot
		trap - EXIT
		echo "Godot class cache ready: $CACHE_PATH"
		echo "Stopped before full asset reimport; SVG/PNG scan actions are not required."
		exit 0
	fi

	if ! kill -0 "$godot_pid" 2>/dev/null; then
		wait "$godot_pid" || true
		echo "Godot exited before writing the class cache." >&2
		cat "$LOG_PATH" >&2
		trap - EXIT
		exit 1
	fi

	sleep "$POLL_SECONDS"
done

echo "Timed out after ${TIMEOUT_SECONDS}s waiting for Godot class cache." >&2
cat "$LOG_PATH" >&2
exit 1
