#!/usr/bin/env python3
"""Place the graph in the primary monitor work area in Cinnamon stage pixels."""
import json
import math
from pathlib import Path
import sys


def position(scale_size, area):
    if not math.isfinite(scale_size) or not 0.5 <= scale_size <= 5:
        raise ValueError("Invalid system widget scale")
    for key in ("x", "y", "width", "height", "scale"):
        if type(area[key]) is not int:
            raise ValueError("Invalid monitor geometry")
    if area["width"] <= 0 or area["height"] <= 0 or not 1 <= area["scale"] <= 4:
        raise ValueError("Invalid monitor dimensions or scale")
    factor = area["scale"]
    left, top = area["x"] * factor, area["y"] * factor
    width, height = area["width"] * factor, area["height"] * factor
    # The graph is 330 x 120 at scale 1. Reserve room for Cinnamon's desklet
    # borders/header, then leave a 30 px gap inside the panel-aware work area.
    graph_width = math.ceil((330 * scale_size + 26) * factor)
    graph_height = math.ceil((120 * scale_size + 70) * factor)
    if graph_width > width or graph_height > height:
        raise ValueError("System widget does not fit this monitor; reduce its scale-size first")
    margin = 30 * factor
    x = max(left, left + width - graph_width - margin)
    y = min(top + margin, top + height - graph_height)
    return x, y


def main():
    scale_size = float(sys.argv[1])
    test_root = sys.argv[2]
    if test_root:
        fixture = Path(test_root) / "monitor.json"
        area = json.loads(fixture.read_text()) if fixture.exists() else {
            "x": 0, "y": 0, "width": 1920, "height": 1080, "scale": 1}
    else:
        import gi
        gi.require_version("Gdk", "3.0")
        from gi.repository import Gdk
        display = Gdk.Display.get_default()
        if display is None:
            raise ValueError("No display available to query the primary monitor")
        monitor = display.get_primary_monitor() or display.get_monitor(0)
        if monitor is None:
            raise ValueError("No monitor available")
        rectangle = monitor.get_workarea()
        # GDK reports application pixels; Cinnamon's stage uses device pixels.
        area = {"x": rectangle.x, "y": rectangle.y,
                "width": rectangle.width, "height": rectangle.height,
                "scale": monitor.get_scale_factor()}
    print(*position(scale_size, area))


if __name__ == "__main__":
    try:
        main()
    except (ImportError, ValueError, KeyError, OSError) as error:
        raise SystemExit(str(error))
