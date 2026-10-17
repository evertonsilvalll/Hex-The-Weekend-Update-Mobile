#!/usr/bin/env python3
"""Generate lossless Android menu atlases. Requires Pillow 11.3.0.

Only atlas coordinates and transparent borders change. Logical frame dimensions,
offsets, names and frame order remain unchanged. Desktop keeps original assets.
"""
from pathlib import Path
import argparse
import xml.etree.ElementTree as ET

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[1]
ATLASES = (
    ("preload/images/Title_Enter", "android/preload/images/Title_Enter"),
    ("preload/images/logoBumpin", "android/preload/images/logoBumpin"),
    ("hexMenu/images/main/FNF_main_menu_assets", "android/hexMenu/images/main/FNF_main_menu_assets"),
)


def pack(rectangles, width):
    shelves, positions = [], {}
    height = 0
    for rect in sorted(rectangles, key=lambda r: (-r[3], -r[2], r)):
        _, _, w, h = rect
        if w + 2 > width:
            return None
        candidates = [(sh - h, width - sx - w, i)
                      for i, (sy, sh, sx) in enumerate(shelves)
                      if sx + w + 2 <= width and h + 2 <= sh]
        if candidates:
            shelf = shelves[min(candidates)[2]]
            positions[rect] = (shelf[2] + 1, shelf[0] + 1)
            shelf[2] += w + 2
        else:
            positions[rect] = (1, height + 1)
            shelves.append([height, h + 2, w + 2])
            height += h + 2
    return width, height, positions


def rectangle(frame):
    return tuple(int(frame.get(key)) for key in ("x", "y", "width", "height"))


def pixels(image, frame):
    x, y, w, h = rectangle(frame)
    return image.crop((x, y, x + w, y + h))


def logical_frame(image, frame):
    crop = pixels(image, frame)
    canvas = Image.new("RGBA", (int(frame.get("frameWidth", crop.width)),
                                int(frame.get("frameHeight", crop.height))))
    canvas.alpha_composite(crop, (-int(frame.get("frameX", 0)),
                                 -int(frame.get("frameY", 0))))
    return canvas


def verify(source, target):
    old_frames = list(ET.parse(source.with_suffix(".xml")).getroot())
    new_frames = list(ET.parse(target.with_suffix(".xml")).getroot())
    if len(old_frames) != len(new_frames):
        raise ValueError("Frame count changed")
    with Image.open(source.with_suffix(".png")) as old_png, Image.open(target.with_suffix(".png")) as new_png:
        old, new = old_png.convert("RGBA"), new_png.convert("RGBA")
        if max(new.size) > 4096:
            raise ValueError("Android atlas exceeds 4096 pixels")
        for before, after in zip(old_frames, new_frames):
            for key in before.attrib.keys() - {"x", "y", "width", "height", "frameX", "frameY", "frameWidth", "frameHeight"}:
                if before.get(key) != after.get(key):
                    raise ValueError(f"Frame metadata changed: {key}")
            original, optimized = logical_frame(old, before), logical_frame(new, after)
            if original.size != optimized.size or ImageChops.difference(original, optimized).getbbox(alpha_only=False):
                raise ValueError(f"Visible pixels or placement changed: {before.get('name')}")
        print(f"{source.relative_to(ROOT)}: {old.width}x{old.height} -> {new.width}x{new.height}; "
              f"RGBA {old.width * old.height * 4 / 1048576:.1f} -> {new.width * new.height * 4 / 1048576:.1f} MiB; "
              f"{len(old_frames)} frames verified")


def generate(source, target):
    tree = ET.parse(source.with_suffix(".xml"))
    frames = list(tree.getroot())
    with Image.open(source.with_suffix(".png")) as png:
        image = png.convert("RGBA")
    trimmed = []
    for frame in frames:
        if frame.tag != "SubTexture" or frame.get("rotated", "false") != "false":
            raise ValueError("Only unrotated Sparrow frames are supported")
        x, y, w, h = rectangle(frame)
        bbox = pixels(image, frame).getchannel("A").getbbox()
        left, top, right, bottom = bbox if bbox else (0, 0, 1, 1)
        rect = (x + left, y + top, right - left, bottom - top)
        trimmed.append((frame, rect, left, top, w, h))
    rectangles = {item[1] for item in trimmed}
    candidates = [pack(rectangles, width) for width in (1024, 1536, 2048, 2560, 3072, 3584, 4096)]
    candidates = [item for item in candidates if item is not None and item[1] <= 4096]
    if not candidates:
        raise ValueError(f"Atlas cannot fit within 4096x4096: {source}")
    width, height, positions = min(candidates, key=lambda item: item[0] * item[1])
    output = Image.new("RGBA", (width, height))
    for rect, position in positions.items():
        x, y, w, h = rect
        output.paste(image.crop((x, y, x + w, y + h)), position)
    for frame, rect, left, top, w, h in trimmed:
        nx, ny = positions[rect]
        frame.set("frameWidth", frame.get("frameWidth", str(w)))
        frame.set("frameHeight", frame.get("frameHeight", str(h)))
        frame.set("frameX", str(int(frame.get("frameX", 0)) - left))
        frame.set("frameY", str(int(frame.get("frameY", 0)) - top))
        for key, value in zip(("x", "y", "width", "height"), (nx, ny, rect[2], rect[3])):
            frame.set(key, str(value))
    target.parent.mkdir(parents=True, exist_ok=True)
    output.save(target.with_suffix(".png"), optimize=False, compress_level=9)
    ET.indent(tree, space="\t")
    tree.write(target.with_suffix(".xml"), encoding="utf-8", xml_declaration=True)
    verify(source, target)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify", action="store_true", help="Check existing generated atlases without modifying them")
    args = parser.parse_args()
    for original, mobile in ATLASES:
        source, target = ROOT / "assets" / original, ROOT / "assets" / mobile
        (verify if args.verify else generate)(source, target)


if __name__ == "__main__":
    main()
