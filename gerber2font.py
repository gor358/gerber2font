#!/usr/bin/env python3
"""
gerber2font — turn a Gerber RS-274X artwork into a TrueType glyph.

A Gerber draws a *stroked* path: a centreline plus a round aperture.
A font needs *filled* outlines. The conversion is the Minkowski sum of the
centreline with a disc of radius aperture/2 — which is exactly what a
photoplotter does when it runs a round tool along a path.

    centreline  +  disc(aperture/2)  ->  filled contour

Because the disc is round, every stroke end and every corner comes out
round automatically. No square caps, no mitred joins, ever.

Usage
-----
    python gerber2font.py AE_logo.brd -o ae-logo.ttf --name ae

    # one glyph per Gerber file, mapped to a private-use codepoint
    python gerber2font.py A.brd B.brd C.brd -o ae.ttf --name ae --chars ABC

Requires: shapely, fonttools
    pip install shapely fonttools
"""

from __future__ import annotations

import argparse
import math
import re
import sys
from typing import Iterable, List, Sequence, Tuple

from shapely.geometry import LineString, Polygon, MultiPolygon
from shapely.ops import unary_union

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

Point = Tuple[float, float]

# --------------------------------------------------------------------------
# geometry
# --------------------------------------------------------------------------

ARC_STEP = math.pi / 64  # angular resolution when flattening arcs


def arc_points(
    x0: float, y0: float, x1: float, y1: float,
    cx: float, cy: float, ccw: bool,
) -> List[Point]:
    """Flatten a circular arc into points, excluding the start point."""
    r = math.hypot(x0 - cx, y0 - cy)
    a0 = math.atan2(y0 - cy, x0 - cx)
    a1 = math.atan2(y1 - cy, x1 - cx)

    delta = a1 - a0
    if ccw:
        while delta <= 0:
            delta += 2 * math.pi
    else:
        while delta >= 0:
            delta -= 2 * math.pi

    n = max(8, int(abs(delta) / ARC_STEP))
    return [
        (cx + r * math.cos(a0 + delta * i / n),
         cy + r * math.sin(a0 + delta * i / n))
        for i in range(1, n + 1)
    ]


# --------------------------------------------------------------------------
# Gerber parsing
# --------------------------------------------------------------------------

SKIP = re.compile(r"^(G04|M02|G54|G75|G36|G37|LP|IR|OF|MI|SF|IP|AS|IN|LN)")
CMD = re.compile(
    r"^(?:G(\d+))?(?:X(-?\d+))?(?:Y(-?\d+))?(?:I(-?\d+))?(?:J(-?\d+))?(?:D(\d+))?$"
)


def parse_gerber(text: str) -> Tuple[List[List[Point]], float]:
    """Return (polylines in inches, aperture diameter in inches)."""
    scale = 100000.0  # FSLAX25Y25 default
    aperture = None
    polylines: List[List[Point]] = []
    current: List[Point] = []
    x = y = 0.0
    mode = 1

    for raw in text.replace("\r", "").split("*"):
        s = re.sub(r"\s+", "", raw).strip("%")
        if not s:
            continue

        if s.startswith("FSLA"):
            m = re.search(r"X(\d)(\d)", s)
            if m:
                scale = 10.0 ** int(m.group(2))
            continue

        if s.startswith("ADD"):
            m = re.match(r"ADD\d+([A-Z]),([0-9.]+)", s)
            if m and m.group(1) == "C":
                aperture = float(m.group(2))
            continue

        if SKIP.match(s):
            continue

        m = CMD.match(s)
        if not m:
            continue

        if m.group(1):
            mode = int(m.group(1))

        nx = int(m.group(2)) / scale if m.group(2) else x
        ny = int(m.group(3)) / scale if m.group(3) else y
        i = int(m.group(4)) / scale if m.group(4) else 0.0
        j = int(m.group(5)) / scale if m.group(5) else 0.0
        d = m.group(6)

        if d == "02":  # move
            if len(current) > 1:
                polylines.append(current)
            current = [(nx, ny)]
        elif d == "01":  # draw
            if not current:
                current = [(x, y)]
            if mode == 1:
                current.append((nx, ny))
            else:
                current.extend(
                    arc_points(x, y, nx, ny, x + i, y + j, mode == 3)
                )

        x, y = nx, ny

    if len(current) > 1:
        polylines.append(current)

    if aperture is None:
        raise SystemExit("No circular aperture found (expected %ADDnnC,<diameter>*%)")

    return polylines, aperture


def stroke_to_polygons(polylines: Sequence[Sequence[Point]], aperture: float):
    """Minkowski sum of the centrelines with a disc of radius aperture/2."""
    radius = aperture / 2.0
    shapes = [
        LineString(p).buffer(radius, cap_style=1, join_style=1, resolution=32)
        for p in polylines
        if len(p) > 1
    ]
    if not shapes:
        raise SystemExit("No drawable segments found in the Gerber")
    return unary_union(shapes)


# --------------------------------------------------------------------------
# font building
# --------------------------------------------------------------------------

def signed_area(coords: Sequence[Point]) -> float:
    a = 0.0
    for i in range(len(coords) - 1):
        x0, y0 = coords[i]
        x1, y1 = coords[i + 1]
        a += x0 * y1 - x1 * y0
    return a / 2.0


def draw_contour(pen: TTGlyphPen, coords, scale: float, dx: float, dy: float,
                 clockwise: bool) -> None:
    pts = [((px * scale) + dx, (py * scale) + dy) for px, py in coords]
    if (signed_area(pts) > 0) == clockwise:
        pts = pts[::-1]
    pen.moveTo(pts[0])
    for p in pts[1:]:
        pen.lineTo(p)
    pen.closePath()


def polygons_to_glyph(geom, scale: float, dx: float, dy: float):
    pen = TTGlyphPen(None)

    polys: Iterable[Polygon]
    if isinstance(geom, Polygon):
        polys = [geom]
    elif isinstance(geom, MultiPolygon):
        polys = list(geom.geoms)
    else:  # GeometryCollection
        polys = [g for g in geom.geoms if isinstance(g, Polygon)]

    for poly in polys:
        # TrueType: outer contours clockwise, holes counter-clockwise (y-up)
        draw_contour(pen, poly.exterior.coords, scale, dx, dy, clockwise=True)
        for hole in poly.interiors:
            draw_contour(pen, hole.coords, scale, dx, dy, clockwise=False)

    return pen.glyph()


def build_font(
    glyphs: dict,
    out_path: str,
    family: str,
    upm: int = 1000,
    ascent: int = 800,
    descent: int = -200,
    copyright_notice: str = "",
    license_notice: str = "",
) -> None:
    order = [".notdef"] + list(glyphs.keys())

    fb = FontBuilder(upm, isTTF=True)
    fb.setupGlyphOrder(order)
    fb.setupCharacterMap({cp: name for name, (cp, _) in glyphs.items()})

    glyf = {".notdef": TTGlyphPen(None).glyph()}
    metrics = {".notdef": (upm // 2, 0)}

    for name, (_, glyph) in glyphs.items():
        glyf[name] = glyph
        metrics[name] = (glyph.xMax + (upm // 20), 0)

    fb.setupGlyf(glyf)
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=ascent, descent=descent)
    fb.setupNameTable({
        "familyName": family,
        "styleName": "Regular",
        "uniqueFontIdentifier": f"{family} Regular 1.000",
        "fullName": f"{family} Regular",
        "psName": f"{family.replace(' ', '')}-Regular",
        "version": "Version 1.000",
        "copyright": copyright_notice,
        "licenseDescription": license_notice,
    })
    fb.setupOS2(sTypoAscender=ascent, sTypoDescender=descent, usWinAscent=ascent,
                usWinDescent=abs(descent))
    fb.setupPost()
    fb.save(out_path)


# --------------------------------------------------------------------------
# cli
# --------------------------------------------------------------------------

def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Convert Gerber artwork into a TrueType glyph.")
    ap.add_argument("gerbers", nargs="+", help="Gerber RS-274X files")
    ap.add_argument("-o", "--out", default="ae-logo.ttf", help="output .ttf")
    ap.add_argument("--name", default="ae", help="font family name")
    ap.add_argument("--chars", default="", help="codepoints to map, e.g. ABC or 0041,0042")
    ap.add_argument("--aperture-units", type=int, default=100,
                    help="aperture size in font units (default 100 = 1/10 em)")
    ap.add_argument("--upm", type=int, default=1000, help="units per em")
    ap.add_argument("--copyright", default="", help="copyright notice")
    ap.add_argument("--license", default="", help="license notice")
    args = ap.parse_args(argv)

    if args.chars:
        chars = [c for c in args.chars]
    else:
        chars = [chr(0xE000 + i) for i in range(len(args.gerbers))]

    glyphs = {}
    for path, char in zip(args.gerbers, chars):
        with open(path, "r", encoding="utf-8", errors="ignore") as fh:
            text = fh.read()

        polylines, aperture = parse_gerber(text)
        geom = stroke_to_polygons(polylines, aperture)

        # font units per inch, chosen so the aperture lands on a round number
        scale = args.aperture_units / aperture
        minx, miny, maxx, maxy = geom.bounds
        dx = -minx * scale
        dy = -miny * scale

        name = f"uni{ord(char):04X}"
        glyph = polygons_to_glyph(geom, scale, dx, dy)
        glyphs[name] = (ord(char), glyph)

        print(f"{path}: {len(polylines)} strokes, aperture {aperture:.4f}in "
              f"-> {scale:.0f} units/in, glyph {glyph.xMax}x{glyph.yMax}")

    build_font(
        glyphs, args.out, args.name, upm=args.upm,
        copyright_notice=args.copyright, license_notice=args.license,
    )
    print(f"wrote {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
