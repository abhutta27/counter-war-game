from __future__ import annotations

import binascii
from pathlib import Path
import struct
import urllib.request
import zlib


URL = "https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz"
ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "export_templates" / "4.7.2.stable"
TARGET_SUFFIXES = ("/windows_release_x86_64.exe", "/version.txt")


def request_range(start: int, end: int | None = None) -> bytes:
    value = f"bytes={start}-" if end is None else f"bytes={start}-{end}"
    request = urllib.request.Request(URL, headers={"Range": value, "User-Agent": "Counter-War-release-builder"})
    with urllib.request.urlopen(request, timeout=120) as response:
        data = response.read()
        if response.status != 206:
            raise RuntimeError(f"Server did not honor range {value}: HTTP {response.status}")
        return data


def remote_size() -> int:
    request = urllib.request.Request(URL, method="HEAD", headers={"User-Agent": "Counter-War-release-builder"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return int(response.headers["Content-Length"])


def central_entries() -> list[dict]:
    size = remote_size()
    tail_start = max(0, size - 131072)
    tail = request_range(tail_start, size - 1)
    eocd_at = tail.rfind(b"PK\x05\x06")
    if eocd_at < 0:
        raise RuntimeError("ZIP end-of-central-directory record not found")
    eocd = tail[eocd_at : eocd_at + 22]
    _, _, _, _, count, central_size, central_offset, _ = struct.unpack("<IHHHHIIH", eocd)
    central = request_range(central_offset, central_offset + central_size - 1)
    entries: list[dict] = []
    offset = 0
    while offset < len(central):
        if central[offset : offset + 4] != b"PK\x01\x02":
            raise RuntimeError(f"Invalid central-directory signature at {offset}")
        fields = struct.unpack("<IHHHHHHIIIHHHHHII", central[offset : offset + 46])
        method = fields[4]
        crc = fields[7]
        compressed_size = fields[8]
        uncompressed_size = fields[9]
        name_len, extra_len, comment_len = fields[10:13]
        local_offset = fields[16]
        name_start = offset + 46
        name = central[name_start : name_start + name_len].decode("utf-8")
        entries.append({
            "name": name,
            "method": method,
            "crc": crc,
            "compressed_size": compressed_size,
            "uncompressed_size": uncompressed_size,
            "local_offset": local_offset,
        })
        offset = name_start + name_len + extra_len + comment_len
    if len(entries) != count:
        raise RuntimeError(f"Central-directory count mismatch: {len(entries)} != {count}")
    return entries


def extract(entry: dict) -> Path:
    local_offset = entry["local_offset"]
    local = request_range(local_offset, local_offset + 29)
    fields = struct.unpack("<IHHHHHIIIHH", local)
    if fields[0] != 0x04034B50:
        raise RuntimeError(f"Invalid local header for {entry['name']}")
    name_len, extra_len = fields[9:11]
    data_start = local_offset + 30 + name_len + extra_len
    compressed = request_range(data_start, data_start + entry["compressed_size"] - 1)
    if entry["method"] == 0:
        payload = compressed
    elif entry["method"] == 8:
        payload = zlib.decompress(compressed, -15)
    else:
        raise RuntimeError(f"Unsupported ZIP method {entry['method']} for {entry['name']}")
    if len(payload) != entry["uncompressed_size"]:
        raise RuntimeError(f"Size mismatch for {entry['name']}")
    crc = binascii.crc32(payload) & 0xFFFFFFFF
    if crc != entry["crc"]:
        raise RuntimeError(f"CRC mismatch for {entry['name']}: {crc:08x} != {entry['crc']:08x}")
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    destination = OUTPUT_DIR / Path(entry["name"]).name
    destination.write_bytes(payload)
    print(f"[TemplateFetch] {entry['name']} -> {destination} ({len(payload)} bytes, CRC {crc:08x})")
    return destination


def main() -> None:
    entries = central_entries()
    selected = [entry for entry in entries if entry["name"].endswith(TARGET_SUFFIXES)]
    release_entries = [entry for entry in selected if entry["name"].endswith("/windows_release_x86_64.exe")]
    if len(release_entries) != 1:
        matches = [entry["name"] for entry in entries if "windows_release" in entry["name"]]
        raise RuntimeError(f"Expected one x86_64 Windows release template; found {matches}")
    for entry in selected:
        extract(entry)
    print("[TemplateFetch] PASS: exact Godot 4.7.2 Windows x86_64 release template extracted")


if __name__ == "__main__":
    main()
