"""Pastel EVA-01 VS Code theme preview for Python."""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable, Literal


THEME_NAME = "EVA-01 Pastel"
MAX_WALLPAPERS = 9
ACCENT_SEQUENCE = ("purple", "green", "lavender", "orange", "rose")


@dataclass
class RicePalette:
    background: str = "#0F1020"
    purple: str = "#7C5FB8"
    green: str = "#A3D977"
    orange: str = "#F6C177"
    enabled: bool = True
    weights: dict[str, float] = field(
        default_factory=lambda: {
            "purple": 0.38,
            "green": 0.20,
            "dark_surfaces": 0.22,
            "lavender": 0.08,
            "orange": 0.05,
            "rose": 0.04,
            "frost": 0.03,
        }
    )

    @property
    def primary_pair(self) -> tuple[str, str]:
        return self.background, self.purple


def load_wallpapers(folder: Path, limit: int = MAX_WALLPAPERS) -> list[Path]:
    """Return the first matching wallpapers in deterministic order."""
    return sorted(folder.glob("*.jpg"))[:limit]


def describe_palette(
    palette: RicePalette,
    mode: Literal["compact", "verbose"] = "compact",
) -> str:
    if not palette.enabled:
        raise RuntimeError("The EVA-01 palette is disabled")

    lines = [f"{THEME_NAME}: {palette.background} -> {palette.purple}"]
    if mode == "verbose":
        for name, weight in palette.weights.items():
            lines.append(f"- {name.replace('_', ' ')}: {weight:.0%}")
    return "\n".join(lines)


def export_manifest(paths: Iterable[Path], palette: RicePalette) -> str:
    payload = {
        "theme": THEME_NAME,
        "enabled": palette.enabled,
        "accent_sequence": ACCENT_SEQUENCE,
        "wallpapers": [path.name for path in paths],
        "colors": {
            "background": palette.background,
            "purple": palette.purple,
            "green": palette.green,
            "orange": palette.orange,
        },
    }
    return json.dumps(payload, indent=2, sort_keys=True)


if __name__ == "__main__":
    root = Path(__file__).resolve().parents[1]
    palette = RicePalette()
    wallpapers = load_wallpapers(root / "wallpapers")
    print(describe_palette(palette, mode="verbose"))
    print(export_manifest(wallpapers, palette))
