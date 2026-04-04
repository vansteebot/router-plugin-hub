from __future__ import annotations

import argparse
import shutil
import tarfile
from pathlib import Path


def parse_skip_line(data: bytes) -> tuple[int, str]:
    header = data[:200_000].decode("utf-8", "replace")
    for line in header.splitlines():
        if line.startswith("skip="):
            return int(line.split("=", 1)[1].strip().strip('"')), "makeself"
    lines = header.splitlines()
    for idx, line in enumerate(lines, 1):
        if line.strip() == "__ARCHIVE_BELOW__":
            return idx + 1, "marker"
    raise ValueError("Could not find skip marker in self-extracting header")


def find_payload_offset(data: bytes, skip_lines: int, mode: str) -> int:
    offset = 0
    line_count = 0
    if mode == "marker":
        target_header_lines = max(skip_lines - 1, 0)
    else:
        target_header_lines = skip_lines
    while line_count < target_header_lines:
        newline = data.find(b"\n", offset)
        if newline == -1:
            raise ValueError("Could not locate payload start")
        offset = newline + 1
        line_count += 1
    return offset


def main() -> None:
    parser = argparse.ArgumentParser(description="Extract a makeself .run archive")
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()

    source = args.source.resolve()
    destination = args.destination.resolve()

    if destination.exists():
        shutil.rmtree(destination)
    destination.mkdir(parents=True, exist_ok=True)

    data = source.read_bytes()
    skip_lines, mode = parse_skip_line(data)
    payload_offset = find_payload_offset(data, skip_lines, mode)

    payload_path = destination / "payload.tar.gz"
    payload_path.write_bytes(data[payload_offset:])

    extract_dir = destination / "payload"
    extract_dir.mkdir(parents=True, exist_ok=True)
    with tarfile.open(payload_path, "r:gz") as tf:
        tf.extractall(extract_dir)

    print(f"source={source}")
    print(f"skip_lines={skip_lines}")
    print(f"mode={mode}")
    print(f"payload_offset={payload_offset}")
    print(f"payload_bytes={payload_path.stat().st_size}")
    print(f"extract_dir={extract_dir}")


if __name__ == "__main__":
    main()
