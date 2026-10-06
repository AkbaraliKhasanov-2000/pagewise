"""Verbatim import of the Scanmuse ASO study (~/Desktop/New-App/fastlane/metadata).

name / subtitle / keywords / promotional text are copied exactly as researched; nothing is edited, the
brand stays "Scanmuse". Descriptions are *not*
copied: Scanmuse's text describes a different feature set. Pagewise descriptions (with the EULA and
Privacy links Apple requires) come from metadata.py; locales it has no translation for get the
English Pagewise description.
"""
from __future__ import annotations

from pathlib import Path

import metadata

SRC = Path.home() / "Desktop/New-App/fastlane/metadata"
OLD, NEW = "Scanmuse", metadata.BRAND


def _read(locale: str, name: str) -> str:
    return (SRC / locale / f"{name}.txt").read_text(encoding="utf-8").strip()


def build() -> dict[str, dict[str, str]]:
    ours = metadata.build()
    english = ours["en-US"]["description"]
    out = {}
    for d in sorted(p for p in SRC.iterdir() if p.is_dir() and (p / "name.txt").exists()):
        loc = d.name
        out[loc] = {
            "name": _read(loc, "name"), "subtitle": _read(loc, "subtitle"),
            "keywords": _read(loc, "keywords"), "promotionalText": _read(loc, "promotional_text"),
            "description": ours[loc]["description"] if loc in ours else english,
            "whatsNew": metadata.whats_new(loc),
            "supportUrl": metadata.SUPPORT_URL, "privacyPolicyUrl": metadata.PRIVACY_URL,
        }
    return out


def hard_limits(meta: dict) -> list[str]:
    bad = []
    for loc, m in meta.items():
        if len(m["name"]) > 30 or len(m["subtitle"]) > 30 or len(m["keywords"].encode()) > 100 \
                or len(m["promotionalText"]) > 170 or len(m["description"]) > 4000:
            bad.append(loc)
    return bad


if __name__ == "__main__":
    data = build()
    print(len(data), "locales:", ", ".join(data), "| over limit:", hard_limits(data) or "none")
