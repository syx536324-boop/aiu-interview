"""Read the Fade catalog and expose only registered GIFs from the media directory."""

from __future__ import annotations

import json
import os
import re
from pathlib import Path

from .config import WEB_ROOT


MEDIA_ROOT = Path(os.environ.get("AIU_FADE_LINEUP_ROOT", r"E:\aiu_fade_lineups")) / "media"
CATALOG_PATH = WEB_ROOT / "fade_lineups.json"


def read_catalog() -> dict:
    """Keep source records, including duplicates, and attach available GIF URLs."""
    catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    for entry in catalog.get("lineups", []):
        entry["media"] = []
        for number, chapter in enumerate(entry.get("chapters", []), start=1):
            chapter.pop("mediaUrl", None)
            name = f"{entry['id']}-{number:02d}.gif"
            if resolve_media(name, catalog) is not None:
                chapter["mediaUrl"] = f"/api/fade-lineups/media/{name}"
                entry["media"].append(chapter["mediaUrl"])
    return catalog


def resolve_media(name: str, catalog: dict | None = None) -> Path | None:
    """Reject unregistered names, traversal, and links outside the media root."""
    if not re.fullmatch(r"fade-[a-z0-9-]+-[0-9]{2}\.gif", name):
        return None
    if catalog is None:
        catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    allowed = {
        f"{entry['id']}-{number:02d}.gif"
        for entry in catalog.get("lineups", [])
        for number, _ in enumerate(entry.get("chapters", []), start=1)
    }
    if name not in allowed:
        return None
    root = MEDIA_ROOT.resolve()
    target = (root / name).resolve()
    if not target.is_relative_to(root) or not target.is_file():
        return None
    return target
