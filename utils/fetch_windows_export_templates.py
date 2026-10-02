"""Fetch only Windows x86_64 templates from the official Godot release ZIP."""

from __future__ import annotations

import io
import json
from pathlib import Path
import re
import struct
import subprocess
import urllib.request
import zipfile
import zlib


class RemoteZip(io.RawIOBase):
    def __init__(self, url: str, size: int) -> None:
        self.url = url
        self.size = size
        self.position = 0

    def seekable(self) -> bool:
        return True

    def tell(self) -> int:
        return self.position

    def seek(self, offset: int, whence: int = io.SEEK_SET) -> int:
        bases = {io.SEEK_SET: 0, io.SEEK_CUR: self.position, io.SEEK_END: self.size}
        self.position = bases[whence] + offset
        return self.position

    def read(self, size: int = -1) -> bytes:
        size = min(self.size - self.position, size if size >= 0 else self.size)
        if size <= 0:
            return b""
        start = self.position
        request = urllib.request.Request(
            self.url,
            headers={"Range": f"bytes={start}-{start + size - 1}", "User-Agent": "PVZ-Windows-QA"},
        )
        with urllib.request.urlopen(request, timeout=90) as response:
            if response.status != 206 or not response.headers.get("Content-Range", "").startswith(f"bytes {start}-"):
                raise RuntimeError("Official download server did not honor the byte range")
            data = response.read(size)
        if len(data) != size:
            raise RuntimeError("Incomplete template download")
        self.position += size
        return data


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    branch = subprocess.check_output(["git", "branch", "--show-current"], cwd=root, text=True).strip()
    if branch != "dev":
        raise RuntimeError("Template preparation is allowed only on dev")
    editor = root / ".bin/Godot_v4.7.1-stable_win64_console.exe"
    version = subprocess.check_output([str(editor), "--version"], cwd=root, text=True).strip()
    match = re.match(r"(\d+\.\d+(?:\.\d+)?)\.stable\.", version)
    if match is None:
        raise RuntimeError(f"Unsupported Godot version: {version}")
    tag = f"{match.group(1)}-stable"
    cache = root / ".bin/export_templates" / tag
    names = ["windows_debug_x86_64.exe", "windows_release_x86_64.exe"]
    if all((cache / name).is_file() for name in names):
        print(f"Windows templates already cached: {cache}", flush=True)
        return
    api = f"https://api.github.com/repos/godotengine/godot-builds/releases/tags/{tag}"
    with urllib.request.urlopen(api, timeout=30) as response:
        release = json.load(response)
    asset = next(a for a in release["assets"] if a["name"] == f"Godot_v{tag}_export_templates.tpz")
    remote = RemoteZip(asset["browser_download_url"], asset["size"])
    cache.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(remote) as archive:
        for name in names:
            destination = cache / name
            if destination.is_file():
                continue
            info = archive.getinfo(f"templates/{name}")
            remote.seek(info.header_offset)
            header = remote.read(30)
            if header[:4] != b"PK\x03\x04":
                raise RuntimeError("Invalid ZIP local header")
            name_length, extra_length = struct.unpack_from("<HH", header, 26)
            remote.seek(info.header_offset + 30 + name_length + extra_length)
            print(f"Downloading {name}: {info.compress_size // 1024 // 1024} MiB", flush=True)
            packed = remote.read(info.compress_size)
            if info.compress_type == zipfile.ZIP_DEFLATED:
                data = zlib.decompress(packed, -zlib.MAX_WBITS)
            elif info.compress_type == zipfile.ZIP_STORED:
                data = packed
            else:
                raise RuntimeError("Unsupported official archive compression")
            if len(data) != info.file_size or zlib.crc32(data) != info.CRC:
                raise RuntimeError("Template size/CRC validation failed")
            temporary = destination.with_suffix(".download")
            temporary.write_bytes(data)
            temporary.replace(destination)
            print(f"Validated {destination.name}: {len(data)} bytes", flush=True)


if __name__ == "__main__":
    main()
