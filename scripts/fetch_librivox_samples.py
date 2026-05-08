#!/usr/bin/env python3
"""Fetch and trim 3 LibriVox excerpts for bundling as sample audio.

Each excerpt is trimmed to ~45 seconds. Metadata (author, narrator, source URL,
license) is written to SampleAudio.json alongside the MP3s.

Requires: ffmpeg on PATH. Run from repo root.
"""

import json
import subprocess
import urllib.request
from pathlib import Path

OUT_DIR = Path(__file__).resolve().parent.parent / "ShadowingApp" / "Resources" / "SampleAudio"
META_PATH = OUT_DIR.parent / "SampleAudio.json"

EXCERPTS = [
    {
        "filename": "english-pride-and-prejudice.mp3",
        "title": "Pride and Prejudice — Opening",
        "language": "English",
        "author": "Jane Austen",
        "narrator": "Karen Savage",
        "source_url": "https://archive.org/download/prideandprejudice_1005_librivox/prideandprejudice_01_austen_64kb.mp3",
        "duration_seconds": 45,
    },
    {
        "filename": "spanish-don-quijote.mp3",
        "title": "Don Quijote — Capítulo 1",
        "language": "Spanish",
        "author": "Miguel de Cervantes",
        "narrator": "LibriVox volunteers",
        "source_url": "https://archive.org/download/don_quijote_vol1_0706_librivox/quijote_vol1_01_cervantes_64kb.mp3",
        "duration_seconds": 45,
    },
    {
        "filename": "french-trois-mousquetaires.mp3",
        "title": "Les Trois Mousquetaires — Chapitre 1",
        "language": "French",
        "author": "Alexandre Dumas",
        "narrator": "LibriVox volunteers",
        "source_url": "https://archive.org/download/trois_mousquetaires_0810_librivox/troismousquetaires_01_dumas_64kb.mp3",
        "duration_seconds": 45,
    },
]


def fetch(url, dest):
    print(f"Downloading {url}")
    urllib.request.urlretrieve(url, dest)


def trim(src, dest, seconds):
    print(f"Trimming {src.name} -> {seconds}s")
    subprocess.run(
        ["ffmpeg", "-y", "-i", str(src), "-t", str(seconds),
         "-acodec", "libmp3lame", "-ab", "96k", str(dest)],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    tmp = OUT_DIR / "_raw"
    tmp.mkdir(exist_ok=True)

    metadata = []
    for excerpt in EXCERPTS:
        raw = tmp / ("raw-" + excerpt["filename"])
        trimmed = OUT_DIR / excerpt["filename"]
        if not raw.exists():
            fetch(excerpt["source_url"], raw)
        trim(raw, trimmed, excerpt["duration_seconds"])
        metadata.append({k: v for k, v in excerpt.items() if k != "source_url"} | {
            "source_url": excerpt["source_url"],
            "license": "Public Domain (LibriVox)",
        })

    META_PATH.write_text(json.dumps({"samples": metadata}, indent=2) + "\n")
    print(f"Wrote {META_PATH}")
    for f in tmp.iterdir():
        f.unlink()
    tmp.rmdir()


if __name__ == "__main__":
    main()
