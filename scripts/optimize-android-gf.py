#!/usr/bin/env python3
"""Split first-week GF atlases into lossless <=4096px Android texture pages.

Requires Pillow 11.3.0. All 252 frame names, ordering, offsets and pixels survive.
"""
import argparse
import copy
import importlib.util
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("atlas", ROOT / "scripts/optimize-android-atlases.py")
atlas = importlib.util.module_from_spec(spec)
spec.loader.exec_module(atlas)
NAMES = ("GF_assets", "sunsetgf", "nightgf", "glitchergf")


def process(name, verify_only):
    source = ROOT / "assets/shared/images/characters" / name
    target = ROOT / "assets/android/shared/images/characters" / name
    original = ET.parse(source.with_suffix(".xml")).getroot()
    with Image.open(source.with_suffix(".png")) as png:
        image = png.convert("RGBA")
    if not verify_only:
        rectangles = sorted({atlas.rectangle(f) for f in original}, key=lambda r: (-r[3], -r[2], r))
        groups = []
        for rect in rectangles:
            for group in groups:
                candidate = atlas.pack(group + [rect], 4096)
                if candidate is not None and candidate[1] <= 4096:
                    group.append(rect)
                    break
            else:
                groups.append([rect])
        manifest = ET.Element("TexturePages")
        for index, group in enumerate(groups):
            width, height, positions = atlas.pack(group, 4096)
            if height > 4096:
                raise ValueError("A frame cannot fit on a texture page")
            page_key = f"{name}-page{index}"
            page = ET.Element("TextureAtlas", imagePath=page_key + ".png")
            output = Image.new("RGBA", (width, height))
            for rect, pos in positions.items():
                x, y, w, h = rect
                output.paste(image.crop((x, y, x + w, y + h)), pos)
            for before in original:
                rect = atlas.rectangle(before)
                if rect in positions:
                    frame = copy.deepcopy(before)
                    frame.set("x", str(positions[rect][0]))
                    frame.set("y", str(positions[rect][1]))
                    page.append(frame)
            target.parent.mkdir(parents=True, exist_ok=True)
            output.save(target.parent / (page_key + ".png"), compress_level=9)
            ET.indent(page, space="\t")
            ET.ElementTree(page).write(target.parent / (page_key + ".xml"), encoding="utf-8", xml_declaration=True)
            ET.SubElement(manifest, "Page", key="characters/" + page_key)
        for frame in original:
            ET.SubElement(manifest, "Frame", name=frame.get("name"))
        ET.indent(manifest, space="\t")
        ET.ElementTree(manifest).write(target.with_suffix(".pages.xml"), encoding="utf-8", xml_declaration=True)
    manifest = ET.parse(target.with_suffix(".pages.xml")).getroot()
    frames = {}
    total_pixels = 0
    for page in manifest.findall("Page"):
        path = target.parent / Path(page.get("key")).name
        with Image.open(path.with_suffix(".png")) as png:
            page_image = png.convert("RGBA")
        assert max(page_image.size) <= 4096
        total_pixels += page_image.width * page_image.height
        for frame in ET.parse(path.with_suffix(".xml")).getroot():
            assert frame.get("name") not in frames
            frames[frame.get("name")] = (page_image, frame)
    assert [f.get("name") for f in original] == [f.get("name") for f in manifest.findall("Frame")]
    assert len(frames) == len(original)
    for before in original:
        page_image, after = frames[before.get("name")]
        assert {k: v for k, v in before.attrib.items() if k not in ("x", "y")} == {k: v for k, v in after.attrib.items() if k not in ("x", "y")}
        expected = atlas.logical_frame(image, before)
        actual = atlas.logical_frame(page_image, after)
        assert expected.size == actual.size
        assert ImageChops.difference(expected, actual).getbbox(alpha_only=False) is None
    print(f"{name}: {len(original)} exact frames, {len(manifest.findall('Page'))} pages <=4096px; {total_pixels * 4 / 1048576:.1f} MiB RGBA (was 256)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    for name in NAMES:
        process(name, args.verify)
