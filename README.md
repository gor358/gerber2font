# gerber2font

Convert Gerber RS-274X artwork into a real TrueType glyph.

A Gerber draws a **stroked** path — a centreline plus a round aperture.
A font needs **filled** outlines. The conversion is the Minkowski sum of the
centreline with a disc of radius `aperture / 2`, which is exactly what a
photoplotter does when it runs a round tool along a path:

```
centreline  +  disc(aperture/2)  ->  filled contour
```

Because the disc is round, every stroke end and every corner comes out round
automatically. No square caps, no mitred joins — ever.

## Install

```bash
python -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

## Run

```bash
# one glyph from one Gerber, mapped to U+E000 (private use)
python gerber2font.py example.brd -o ae-logo.ttf --name ae

# several Gerbers, one glyph each, mapped to real characters
python gerber2font.py A.brd E.brd 2.brd -o ae.ttf --name ae --chars AE2

# thicker aperture in font units (default 100 = 1/10 em)
python gerber2font.py example.brd -o ae-logo.ttf --aperture-units 120
```

## How the scale is chosen

The aperture is the base unit of the whole system, so it is what gets mapped
to a round number of font units:

```
scale (units per inch) = aperture_units / aperture_in_inches
```

With a 10 mil aperture (`0.01in`) and `--aperture-units 100`:

| | value |
|---|---|
| units per em | 1000 |
| aperture | 100 units |
| 1 inch | 10 000 units |
| a 0.05in tall mark | 500 units |
| a 0.01in stroke | 100 units |

Change `--aperture-units` and every derived size follows — the proportions
stay locked to the artwork.

## What you get

A `.ttf` whose `name` table is yours: family name, copyright and licence are
whatever you pass on the command line. The outlines are generated from your
Gerber, so the glyphs are your work.

```bash
python gerber2font.py example.brd -o ae-logo.ttf --name ae \
  --copyright "Copyright 2026 a2e.tech" \
  --license "All rights reserved"
```

## Using the result

```css
@font-face{
  font-family:"ae";
  src:url("/ae-logo.ttf") format("truetype");
  font-display:swap;
}
.logo::before{ content:"\E000"; font-family:"ae"; }
```

Or convert to `.woff2` for the web:

```bash
pip install fonttools brotli
fonttools ttLib.woff2 compress ae-logo.ttf
```

## Notes and limits

- Supported: `%FSLAX..Y..%`, `%MOIN*%`, circular apertures (`%ADDnnC,<d>%`),
  `G01`/`G02`/`G03`, `D01`/`D02`, `I`/`J` arc offsets.
- Not supported yet: rectangular apertures, `G36`/`G37` regions, macros,
  step-and-repeat, negative polarity.
- Arcs are flattened at π/64 per segment — increase `ARC_STEP` resolution in
  the source if you need smoother curves.
- The glyph is placed with its lowest point on the baseline. Adjust `dy` in
  `main()` if you want a different vertical position.

## Licence

The code in this repository is released under the **MIT Licence** — see
[LICENSE](LICENSE).

**About the generated fonts.** Glyphs produced by this tool are outlines
derived from *your* Gerber artwork, so they carry whatever copyright and
licence you pass to `--copyright` and `--license`. They are not derived from
any third-party typeface.

If you mix these glyphs into a font that is based on an existing typeface,
that typeface's licence still applies to its own outlines. For example,
JetBrains Mono is distributed under the SIL Open Font License 1.1, which
requires keeping its copyright and licence notices, and requires renaming any
modified version.
