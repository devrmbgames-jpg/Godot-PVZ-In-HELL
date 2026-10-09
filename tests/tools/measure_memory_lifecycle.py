"""Compare quiescent Godot lifecycle trends using identical real GUT scenarios on Windows."""
from __future__ import annotations

import argparse
import ctypes
from ctypes import wintypes
import hashlib
import json
import os
from pathlib import Path
import re
import statistics
import subprocess
import threading
import time

ROOT = Path(__file__).resolve().parents[2]
BASE_SHA = "857ec02d7703eab840dbf496730be48d29294d99"
FIXTURES = (
    "test_s_grab.gd", "test_district_population.gd", "test_district_snapshot.gd",
    "test_customer_handoff.gd", "test_npc_remains.gd", "test_customer_inspection.gd",
)
SHUTDOWN_DIAGNOSTICS = (
    "RID allocations of type", "ObjectDB instances were leaked at exit",
    "resources still in use at exit", "Pages in use exist at exit",
)


class ProcessMemoryCounters(ctypes.Structure):
    _fields_ = [("cb", wintypes.DWORD), ("PageFaultCount", wintypes.DWORD)] + [
        (field, ctypes.c_size_t) for field in (
            "PeakWorkingSetSize", "WorkingSetSize", "QuotaPeakPagedPoolUsage",
            "QuotaPagedPoolUsage", "QuotaPeakNonPagedPoolUsage", "QuotaNonPagedPoolUsage",
            "PagefileUsage", "PeakPagefileUsage", "PrivateUsage",
        )
    ]


def process_memory(pid: int) -> dict[str, int]:
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    psapi = ctypes.WinDLL("psapi", use_last_error=True)
    kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
    kernel.OpenProcess.restype = wintypes.HANDLE
    kernel.CloseHandle.argtypes = [wintypes.HANDLE]
    psapi.GetProcessMemoryInfo.argtypes = [wintypes.HANDLE, ctypes.c_void_p, wintypes.DWORD]
    handle = kernel.OpenProcess(0x0400 | 0x0010, False, pid)
    if not handle:
        raise ctypes.WinError(ctypes.get_last_error())
    try:
        counters = ProcessMemoryCounters()
        counters.cb = ctypes.sizeof(counters)
        if not psapi.GetProcessMemoryInfo(handle, ctypes.byref(counters), counters.cb):
            raise ctypes.WinError(ctypes.get_last_error())
        return {"rss": counters.WorkingSetSize, "private_bytes": counters.PrivateUsage}
    finally:
        kernel.CloseHandle(handle)


def scenario_source(name: str) -> bytes:
    source = subprocess.check_output(
        ["git", "show", f"{BASE_SHA}:tests/gut/{name}"], cwd=ROOT
    ).decode("utf-8")
    # These two setup boundaries migrated in 41. Both snapshots get the SAME adapter:
    # baseline registers natively, target invokes its required compiled fixture boundary.
    # Scenario inputs/assertions and all remaining test bodies are baseline bytes.
    if name in ("test_customer_handoff.gd", "test_customer_inspection.gd"):
        source = source.replace("_world.add_entity(_customer)", "_lifecycle_register(_customer, _visit)")
        source = source.replace("_world.add_entity(_parcel)", "_lifecycle_register(_parcel)")
        source += """
func _lifecycle_register(actor: Entity, visit: CustomerVisit = null) -> void:
    var bridge_path: String = "res://tests/helpers/entity_composition_fixture.gd"
    if FileAccess.file_exists(bridge_path):
        var bridge: Script = load(bridge_path) as Script
        if visit != null:
            bridge.call("register_visit", _world, actor, visit)
        else:
            bridge.call("register", _world, actor)
    else:
        _world.add_entity(actor)
""".replace("    ", "\t")
    if name == "test_npc_remains.gd":
        source = source.replace(
            "[C_DayCycle.new(), C_Wallet.new(), C_Commerce.new(), C_CustomerFlow.new()]",
            "[C_DayCycle.new(), C_LootDrops.new(), C_Wallet.new(), C_Commerce.new(), C_CustomerFlow.new()]",
        )
        source = source.replace("_world.add_entity(npc, null, false)", "_lifecycle_register(npc)")
        source += """
func _lifecycle_register(actor: Entity) -> void:
    var bridge_path: String = "res://tests/helpers/entity_composition_fixture.gd"
    if FileAccess.file_exists(bridge_path):
        var bridge: Script = load(bridge_path) as Script
        bridge.call("register", _world, actor, false)
    else:
        _world.add_entity(actor, null, false)
""".replace("    ", "\t")
    return source.encode("utf-8")


def prepare(project: Path) -> dict[str, str]:
    if project.resolve() == ROOT.resolve():
        raise ValueError("Use an isolated snapshot, never the live worktree")
    assert (project / "project.godot").is_file()
    assert (project / ".godot/global_script_class_cache.cfg").is_file()
    probe = ROOT / "tests/fixtures/memory_lifecycle_probe.gd"
    target = project / "tests/fixtures/memory_lifecycle_probe.gd"
    target.write_bytes(probe.read_bytes())
    directory = project / "tests/fixtures/memory_lifecycle_scenarios"
    directory.mkdir(exist_ok=True)
    digests = {"probe": hashlib.sha256(probe.read_bytes()).hexdigest()}
    for name in FIXTURES:
        payload = scenario_source(name)
        (directory / name).write_bytes(payload)
        digests[name] = hashlib.sha256(payload).hexdigest()
    return digests


def slope(values: list[float]) -> float:
    if len(values) < 2:
        return 0.0
    middle = (len(values) - 1) / 2
    mean = statistics.mean(values)
    denominator = sum((index - middle) ** 2 for index in range(len(values)))
    return sum((index - middle) * (value - mean) for index, value in enumerate(values)) / denominator


def summarize(samples: list[dict]) -> dict:
    groups = {}
    for sample in samples:
        groups.setdefault(sample["scenario"], []).append(sample)
    summary = {}
    for name, rows in groups.items():
        measured = rows[1:]
        width = max(2, len(measured) // 5)
        metrics = {}
        for key in ("rss", "private_bytes", "memory_static", "objects", "resources", "nodes", "orphans"):
            values = [float(row[key]) for row in measured]
            metrics[key] = {
                "first": rows[0][key], "last": rows[-1][key],
                "min": min(values), "max": max(values),
                "first_block_median": statistics.median(values[:width]),
                "last_block_median": statistics.median(values[-width:]),
                "slope_per_cycle": slope(values),
                "tail_slope_per_cycle": slope(values[len(values) // 2:]),
            }
        summary[name] = {"completed_cycles": len(measured), "metrics": metrics}
    return summary


def run(label: str, project: Path, args: argparse.Namespace) -> dict:
    digests = prepare(project)
    ack = args.output / f"{label}_ack.txt"
    environment = os.environ.copy()
    environment.update({"PVZ_MEMORY_ACK": str(ack.resolve()),
                        "PVZ_MEMORY_WARMUP": str(args.warmup),
                        "PVZ_MEMORY_CYCLES": str(args.cycles),
                        "PVZ_MEMORY_SCENARIO": args.scenario})
    command = [str(args.godot.resolve()), "--headless", "--path", str(project.resolve()),
               "--script", "res://addons/gut/gut_cmdln.gd",
               "-gtest=res://tests/fixtures/memory_lifecycle_probe.gd", "-gexit"]
    samples, diagnostics, functional = [], [], None
    started = time.monotonic()
    with (args.output / f"{label}.log").open("w", encoding="utf-8") as log:
        process = subprocess.Popen(command, env=environment, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace")
        watchdog = threading.Timer(args.timeout, process.kill)
        watchdog.start()
        try:
            for line in process.stdout:
                log.write(line)
                log.flush()
                clean = re.sub(r"\x1b\[[0-9;]*m", "", line).strip()
                if clean.startswith("MEMORY_SAMPLE "):
                    sample = json.loads(clean.removeprefix("MEMORY_SAMPLE "))
                    sample.update(process_memory(sample["pid"]))
                    samples.append(sample)
                    ack.write_text(str(sample["token"]), encoding="ascii")
                elif clean.startswith("MEMORY_RESULT "):
                    functional = json.loads(clean.removeprefix("MEMORY_RESULT "))
                elif clean.startswith("MEMORY_SCENARIO_DONE "):
                    print(label, clean, flush=True)
                if any(marker in clean for marker in ("ERROR:", "WARNING:", "SCRIPT ERROR:")):
                    diagnostics.append(clean)
            code = process.wait(timeout=30)
        finally:
            watchdog.cancel()
            if process.poll() is None:
                process.kill()
                process.wait()
    rows = {
        "snapshot": label, "command": command, "exit": code,
        "elapsed_seconds": round(time.monotonic() - started, 2),
        "fixture_sha256": digests, "functional": functional,
        "diagnostics": diagnostics,
        "non_shutdown_diagnostics": [line for line in diagnostics
                                     if not any(marker in line for marker in SHUTDOWN_DIAGNOSTICS)],
        "summary": summarize(samples), "samples": samples,
    }
    (args.output / f"{label}.json").write_text(json.dumps(rows, indent=2) + "\n", encoding="utf-8")
    print(label, "exit", code, "functional", functional, "diagnostics", len(diagnostics), flush=True)
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline-project", type=Path, required=True)
    parser.add_argument("--target-project", type=Path, required=True)
    parser.add_argument("--godot", type=Path, default=ROOT / ".bin/Godot_v4.7.1-stable_win64_console.exe")
    parser.add_argument("--cycles", type=int, default=60)
    parser.add_argument("--warmup", type=int, default=12)
    parser.add_argument("--scenario", default="")
    parser.add_argument("--timeout", type=int, default=1800)
    parser.add_argument("--output", type=Path, default=ROOT / "tests/artifacts/memory_lifecycle")
    args = parser.parse_args()
    if args.cycles < 2 or args.warmup < 1:
        parser.error("Use at least one warmup and two measured cycles")
    if (args.baseline_project / "project.godot").read_bytes() != (args.target_project / "project.godot").read_bytes():
        parser.error("Baseline/target project settings must be byte-identical")
    args.output.mkdir(parents=True, exist_ok=True)
    baseline = run("baseline", args.baseline_project, args)
    target = run("target", args.target_project, args)
    assert baseline["fixture_sha256"] == target["fixture_sha256"]
    for result in (baseline, target):
        if result["exit"] or result["non_shutdown_diagnostics"] or result["functional"] is None:
            return 1
        if result["functional"]["failures"]:
            return 1
        if not result["summary"] or any(row["completed_cycles"] != args.cycles
                                         for row in result["summary"].values()):
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
