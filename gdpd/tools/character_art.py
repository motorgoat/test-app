#!/usr/bin/env python3
"""Erzeugt die SVG-Teile des eigenen Charakters (icons/character/**).

    python3 tools/character_art.py          # aus dem Ordner gdpd/

Regeln (siehe docs/GDPD_TAEGLICH_CHARAKTER.md, Abschnitt 3):
- Godot-sichere SVGs: nur path/circle/ellipse/rect/g mit fill/stroke/opacity/transform. Keine Verläufe, Filter,
  Masken, CSS oder Texte.
- Körperteile liegen auf der gemeinsamen Leinwand 256 x 256 (Füße bei y ~ 236, Mitte x = 128).
  Gesichtsteile auf 64 x 64, Zubehör auf 128 x 128 (Mitte = Ankerpunkt).
- `*_f.svg` wird mit `self_modulate` eingefärbt: weiß mit hellgrauer Schattenkante (#D6D6D6), dazu der dunkle Rand
  (Tinte). Tinte mal Farbe bleibt dunkel, der Rand passt sich der Farbe nur leicht an.
- `*_l.svg` und Teile ohne Endung sind fest (Tinte, feste Farben, Glanz) und werden nie eingefärbt.
- Neue Teile: eine Funktion hier + eine Datenzeile in scripts/character.gd.

Das Skript schreibt auch die .import-Dateien (svg/scale=2, Mipmaps), damit die Teile auch klein sauber aussehen.
"""
import math
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "icons", "character")
INK = "#1F2430"
GREY = "#D6D6D6"
WHITE = "#FFFFFF"
OUT = 5.0            # Randbreite (nach außen) der Körperteile
OUT_S = 4.0          # Randbreite der Gesichtsteile und des Zubehörs
MOUTH_DARK = "#5B2A3A"
TONGUE = "#F28C96"
PINK = "#F4A7B9"
GOLD_LIGHT = "#FFD88A"

# ---------------------------------------------------------------------------------------------------------------
# Formen: ("circle", cx, cy, r) · ("ellipse", cx, cy, rx, ry) · ("path", d) · ("tube", d, w) · ("rect", x, y, w, h, r)


def f(v):
    s = ("%.2f" % v).rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def el(shape, fill="none", stroke=None, sw=0.0, opacity=None, extra=""):
    kind = shape[0]
    op = "" if opacity is None else ' opacity="%s"' % f(opacity)
    st = ""
    if kind == "tube":
        # Röhre: ein dicker Strich in der Füllfarbe (+ Rand)
        width = shape[2] + sw
        color = stroke if stroke else fill
        return '<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round"%s%s/>' % (
            shape[1], color, f(width), op, extra)
    if stroke:
        st = ' stroke="%s" stroke-width="%s" stroke-linejoin="round" stroke-linecap="round"' % (stroke, f(sw))
    if kind == "circle":
        return '<circle cx="%s" cy="%s" r="%s" fill="%s"%s%s%s/>' % (f(shape[1]), f(shape[2]), f(shape[3]), fill, st, op, extra)
    if kind == "ellipse":
        return '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="%s"%s%s%s/>' % (
            f(shape[1]), f(shape[2]), f(shape[3]), f(shape[4]), fill, st, op, extra)
    if kind == "rect":
        return '<rect x="%s" y="%s" width="%s" height="%s" rx="%s" fill="%s"%s%s%s/>' % (
            f(shape[1]), f(shape[2]), f(shape[3]), f(shape[4]), f(shape[5]), fill, st, op, extra)
    return '<path d="%s" fill="%s"%s%s%s/>' % (shape[1], fill, st, op, extra)


def line(d, w=4.0, color=INK, opacity=None):
    op = "" if opacity is None else ' opacity="%s"' % f(opacity)
    return '<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round"%s/>' % (
        d, color, f(w), op)


def svg(size, body):
    w, h = (size, size) if isinstance(size, (int, float)) else size
    return '<svg xmlns="http://www.w3.org/2000/svg" width="%s" height="%s" viewBox="0 0 %s %s">%s</svg>\n' % (
        f(w), f(h), f(w), f(h), "".join(body))


def inset(shape, px, py, k):
    return '<g transform="translate(%s %s) scale(%s) translate(%s %s)">%s</g>' % (
        f(px), f(py), f(k), f(-px), f(-py), el(shape, WHITE))


def shade_point(shape, shade):
    """Punkt, zu dem die weiße Fläche schrumpft (oben links): unten rechts bleibt eine graue Kante."""
    if shape[0] == "circle":
        return (shape[1] - shape[3] * 0.32, shape[2] - shape[3] * 0.5, 0.86)
    if shape[0] == "ellipse":
        return (shape[1] - shape[3] * 0.32, shape[2] - shape[4] * 0.5, 0.86)
    if shape[0] == "rect":
        return (shape[1] + shape[3] * 0.35, shape[2] + shape[4] * 0.25, 0.86)
    return shade


def fill_layer(shapes, outline=OUT, shade=None, flat=False):
    """Eingefärbte Ebene: Rand (Tinte), Grau, weiße Innenfläche."""
    out = []
    if outline > 0:
        for s in shapes:
            if s[0] == "tube":
                out.append(el(s, stroke=INK, sw=outline * 2))
            else:
                out.append(el(s, INK, INK, outline * 2))
    if flat:
        for s in shapes:
            out.append(el(s, WHITE) if s[0] != "tube" else el(s, stroke=WHITE))
        return out
    for s in shapes:
        out.append(el(s, GREY) if s[0] != "tube" else el(s, stroke=GREY))
    for s in shapes:
        if s[0] == "tube":
            w = s[2]
            out.append('<g transform="translate(%s %s)">%s</g>' % (f(-w * 0.1), f(-w * 0.14), el(("tube", s[1], w * 0.62), stroke=WHITE)))
            continue
        sp = shade_point(s, shade)
        if sp is None:
            out.append(el(s, WHITE))
        else:
            out.append(inset(s, sp[0], sp[1], sp[2]))
    return out


def write(rel, content):
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(content)
    write_import(path)
    WRITTEN.append(rel)


IMPORT_TEMPLATE = """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="res://icons/character/%s"

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
svg/scale=2.0
editor/scale_with_editor_scale=false
editor/convert_colors_with_editor_theme=false
"""


def write_import(path):
    imp = path + ".import"
    rel = os.path.relpath(path, ROOT).replace(os.sep, "/")
    if os.path.exists(imp):
        # Godot hat schon uid/Pfade ergänzt: nur die beiden wichtigen Werte sicherstellen
        txt = open(imp, encoding="utf-8").read()
        txt = txt.replace("svg/scale=1.0", "svg/scale=2.0").replace("mipmaps/generate=false", "mipmaps/generate=true")
        open(imp, "w", encoding="utf-8").write(txt)
        return
    open(imp, "w", encoding="utf-8").write(IMPORT_TEMPLATE % rel)


WRITTEN = []


def part(base, name, shapes, details=None, fixed_under=None, outline=OUT, shade=None, flat=False):
    """Eingefärbtes Teil: <name>_f.svg (+ <name>_l.svg mit festen Linien/Farben)."""
    write("%s/%s_f.svg" % (base, name), svg(256, fill_layer(shapes, outline, shade, flat)))
    body = (fixed_under or []) + (details or [])
    if body:
        write("%s/%s_l.svg" % (base, name), svg(256, body))


def fixed(base, name, body, size=256):
    write("%s/%s.svg" % (base, name), svg(size, body))


def mirror_x(d, cx=128.0):
    """Spiegelt einen einfachen Pfad (nur absolute M/L/C/Q/S/T/Z mit Zahlenpaaren) an x = cx."""
    toks = d.replace(",", " ").split()
    out = []
    expect_x = True
    for t in toks:
        if t[0].isalpha():
            out.append(t)
            expect_x = True
            continue
        v = float(t)
        if expect_x:
            out.append(f(2 * cx - v))
        else:
            out.append(f(v))
        expect_x = not expect_x
    return " ".join(out)


def circle_union_path(circles):
    return [("circle", cx, cy, r) for cx, cy, r in circles]


def sparkle(cx, cy, r, k=0.22):
    """Weiches Funkeln: vier Spitzen mit nach innen gewölbten Seiten (k: wie dick die Mitte ist)."""
    d = "M %s %s" % (f(cx), f(cy - r))
    pts = [(cx + r, cy), (cx, cy + r), (cx - r, cy), (cx, cy - r)]
    prev = (cx, cy - r)
    for p in pts:
        mx = (prev[0] + p[0]) / 2
        my = (prev[1] + p[1]) / 2
        qx = cx + (mx - cx) * k
        qy = cy + (my - cy) * k
        d += " Q %s %s %s %s" % (f(qx), f(qy), f(p[0]), f(p[1]))
        prev = p
    return d + " Z"


# ---------------------------------------------------------------------------------------------------------------
# Basen


def base_bart():
    b = "bart"
    # Haare hinten: wolkige Mähne um den Kopf
    part(b, "haar_hinten", circle_union_path([(128, 76, 50), (84, 92, 36), (172, 92, 36), (72, 128, 28), (184, 128, 28),
                                               (104, 62, 30), (152, 62, 30)]),
         details=[line("M 70 104 Q 62 116 68 128", 3.5, INK, 0.35), line("M 186 104 Q 194 116 188 128", 3.5, INK, 0.35)])
    # Gewand
    robe = ("path", "M 96 150 C 74 166 56 204 54 222 Q 53 236 68 236 Q 128 242 188 236 Q 203 236 202 222 C 200 204 182 166 160 150 Z")
    part(b, "robe", [robe], shade=(118, 150, 0.9),
         details=[line("M 104 200 Q 100 220 102 234", 3.5, INK, 0.3), line("M 152 200 Q 156 220 154 234", 3.5, INK, 0.3)])
    part(b, "haende", [("circle", 62, 204, 15), ("circle", 194, 204, 15)])
    # Kopf mit kleinen Ohren
    part(b, "kopf", [("circle", 74, 116, 11), ("circle", 182, 116, 11), ("circle", 128, 112, 56)],
         details=[line("M 80 112 Q 76 116 80 120", 3, INK, 0.35), line("M 176 112 Q 180 116 176 120", 3, INK, 0.35)])
    # Bart: rahmt den Mund ein (Lücke für den Mund), unten wolkige Bögen
    beard = ("path", "M 74 118 C 70 150 80 176 92 190 Q 98 206 112 202 Q 120 214 128 210 Q 136 214 144 202 "
                     "Q 158 206 164 190 C 176 176 186 150 182 118 C 176 132 166 140 156 142 "
                     "C 150 160 106 160 100 142 C 90 140 80 132 74 118 Z")
    part(b, "bart", [beard], shade=(122, 150, 0.9),
         details=[line("M 112 176 Q 116 188 112 196", 3.2, INK, 0.3), line("M 144 176 Q 140 188 144 196", 3.2, INK, 0.3),
                  line("M 128 182 L 128 200", 3.2, INK, 0.3)])
    # Haare vorne: kleine Locke auf der Stirn
    part(b, "haar_vorne", circle_union_path([(112, 62, 14), (130, 58, 16), (148, 64, 12)]))


def base_goettin():
    b = "goettin"
    hair = ("path", "M 128 48 C 76 48 62 92 64 130 C 66 164 58 186 66 198 Q 82 210 100 202 Q 114 210 128 204 "
                    "Q 142 210 156 202 Q 174 210 190 198 C 198 186 190 164 192 130 C 194 92 180 48 128 48 Z")
    part(b, "haar_lang", [hair], shade=(120, 90, 0.9),
         details=[line("M 84 150 Q 80 172 86 190", 3.5, INK, 0.3), line("M 172 150 Q 176 172 170 190", 3.5, INK, 0.3)])
    dress = ("path", "M 106 156 C 88 170 66 206 62 222 Q 60 236 76 236 Q 128 242 180 236 Q 196 236 194 222 C 190 206 168 170 150 156 Z")
    part(b, "kleid", [dress], shade=(120, 160, 0.9),
         details=[line("M 92 214 Q 128 224 164 214", 3.5, INK, 0.3)])
    part(b, "haende", [("circle", 72, 206, 13), ("circle", 184, 206, 13)])
    part(b, "kopf", [("rect", 116, 150, 24, 18, 8), ("circle", 128, 114, 52)])
    fringe = ("path", "M 76 108 C 72 74 96 56 128 56 C 164 56 188 76 180 116 C 172 96 154 86 138 84 "
                      "C 124 96 102 104 76 108 Z")
    part(b, "pony", [fringe], shade=(110, 70, 0.9),
         details=[line("M 136 84 Q 150 70 168 74", 3.2, INK, 0.3)])


def base_sonne():
    b = "sonne"
    cx, cy = 128.0, 132.0
    rays = []
    n = 12
    for i in range(n):
        a = -math.pi / 2 + i * 2 * math.pi / n
        tip = (cx + math.cos(a) * 104, cy + math.sin(a) * 104)
        bl = (cx + math.cos(a - 0.16) * 70, cy + math.sin(a - 0.16) * 70)
        br = (cx + math.cos(a + 0.16) * 70, cy + math.sin(a + 0.16) * 70)
        rays.append(("path", "M %s %s L %s %s L %s %s Z" % (f(bl[0]), f(bl[1]), f(tip[0]), f(tip[1]), f(br[0]), f(br[1]))))
    # Strahlen: runde Spitzen über die Tinten-Kante
    out = []
    for r in rays:
        out.append(el(r, INK, INK, OUT * 2 + 6))
    for r in rays:
        out.append(el(r, GREY, GREY, 6))
    for i, r in enumerate(rays):
        out.append('<g transform="translate(%s %s) scale(0.82) translate(%s %s)">%s</g>' % (
            f(cx), f(cy), f(-cx), f(-cy), el(r, WHITE, WHITE, 5)))
    write("%s/strahlen_f.svg" % b, svg(256, out))
    part(b, "scheibe", [("circle", cx, cy, 78)])
    fixed(b, "glanz", [line("M 76 104 A 58 58 0 0 1 112 70", 8, WHITE, 0.55), ('<circle cx="70" cy="122" r="4.5" fill="%s" opacity="0.55"/>' % WHITE)])


def base_wolke():
    b = "wolke"
    small = [(52, 88, 16), (66, 80, 16), (78, 92, 12), (196, 70, 14), (210, 64, 14), (220, 74, 11), (204, 192, 10), (216, 186, 12), (228, 194, 9)]
    part(b, "woelkchen", circle_union_path(small))
    body = circle_union_path([(128, 112, 54), (82, 140, 38), (174, 140, 38), (104, 92, 30), (156, 96, 30)])
    body.append(("rect", 50, 132, 156, 76, 38))
    part(b, "wolke", body)
    fixed(b, "bauch", ['<ellipse cx="128" cy="180" rx="46" ry="18" fill="%s" opacity="0.55"/>' % WHITE])


def base_katze():
    b = "katze"
    part(b, "schwanz", [("tube", "M 160 226 C 206 230 224 200 214 172 C 208 156 212 138 228 134", 22)])
    body = ("path", "M 84 236 C 74 204 92 160 128 158 C 164 160 182 204 172 236 Z")
    part(b, "koerper", [body, ("ellipse", 104, 232, 18, 10), ("ellipse", 152, 232, 18, 10)], shade=(118, 170, 0.9),
         details=[line("M 104 226 L 104 236", 3, INK, 0.4), line("M 152 226 L 152 236", 3, INK, 0.4)])
    ear_l = ("path", "M 66 104 L 70 42 Q 72 34 80 40 L 118 70 Z")
    ear_r = ("path", mirror_x(ear_l[1]))
    part(b, "ohren", [ear_l, ear_r], shade=(96, 60, 0.82),
         fixed_under=[el(("path", "M 76 92 L 78 54 L 104 74 Z"), PINK), el(("path", mirror_x("M 76 92 L 78 54 L 104 74 Z")), PINK)])
    part(b, "kopf", [("ellipse", 128, 116, 70, 56)])
    stripes = [("path", "M 120 62 Q 128 60 136 62 L 132 84 Q 128 88 124 84 Z"),
               ("path", "M 100 66 Q 106 63 112 64 L 112 82 Q 108 86 104 80 Z"),
               ("path", mirror_x("M 100 66 Q 106 63 112 64 L 112 82 Q 108 86 104 80 Z")),
               ("path", "M 58 118 L 76 114 Q 80 118 76 122 L 58 122 Z"),
               ("path", mirror_x("M 58 118 L 76 114 Q 80 118 76 122 L 58 122 Z"))]
    part(b, "muster", stripes, outline=0, flat=True)
    muzzle = [("circle", 116, 144, 15), ("circle", 140, 144, 15)]
    out = []
    for s in muzzle:
        out.append(el(s, INK, INK, 7))
    for s in muzzle:
        out.append(el(s, WHITE))
    out.append(el(("path", "M 120 130 Q 128 126 136 130 Q 134 138 128 140 Q 122 138 120 130 Z"), PINK, INK, 3.5))
    fixed(b, "schnauze", out)
    wh = []
    for side in (1, -1):
        for dy, ang in ((-4, -8), (4, 4)):
            x0 = 128 + side * 34
            x1 = 128 + side * 72
            wh.append(line("M %s %s Q %s %s %s %s" % (f(x0), f(146 + dy), f((x0 + x1) / 2), f(146 + dy + ang * 0.3), f(x1), f(146 + dy + ang)), 3.2, INK, 0.75))
    fixed(b, "schnurrhaare", wh)


def base_nudel():
    b = "nudel"
    strands = [
        ("tube", "M 92 186 C 84 204 98 214 88 236", 9),
        ("tube", "M 112 196 C 106 214 120 222 112 238", 9),
        ("tube", "M 144 196 C 150 214 136 222 144 238", 9),
        ("tube", "M 164 186 C 172 204 158 214 168 236", 9),
        ("tube", "M 76 170 C 58 182 64 198 50 210", 9),
        ("tube", "M 180 170 C 198 182 192 198 206 210", 9),
    ]
    part(b, "nudeln_hinten", strands)
    stalks = [("tube", "M 112 112 C 108 90 98 76 96 58", 9), ("tube", "M 144 112 C 148 90 158 76 160 58", 9),
              ("circle", 96, 56, 18), ("circle", 160, 56, 18)]
    part(b, "stiele", stalks)
    blob = circle_union_path([(128, 144, 50), (90, 154, 32), (166, 154, 32), (110, 178, 28), (146, 178, 28)])
    swirls = [line("M 92 140 C 100 124 120 124 122 138 C 124 152 104 156 100 146", 3.5, INK, 0.28),
              line("M 140 128 C 156 118 174 132 166 146 C 160 156 146 150 150 140", 3.5, INK, 0.28),
              line("M 104 178 C 116 170 132 172 136 184", 3.5, INK, 0.28),
              line("M 150 170 C 160 168 168 176 164 186", 3.5, INK, 0.28)]
    part(b, "knaeuel", blob, details=swirls)
    part(b, "baellchen", [("circle", 76, 120, 20), ("circle", 180, 120, 20)],
         details=['<circle cx="70" cy="112" r="4" fill="%s" opacity="0.45"/>' % WHITE, '<circle cx="174" cy="112" r="4" fill="%s" opacity="0.45"/>' % WHITE])


# ---------------------------------------------------------------------------------------------------------------
# Gesicht (64 x 64, Mitte 32/32). Augen einzeln (linkes Auge; rechts gespiegelt).

EYES = {
    # rx, ry, iris rx, iris ry, Pupille
    "rund": (11.5, 11.5, 8.0, 8.0, 4.4),
    "oval": (9.5, 13.0, 7.0, 9.0, 4.2),
    "gross": (14.5, 14.5, 10.5, 10.5, 5.6),
    "schmal": (13.0, 8.5, 6.8, 6.8, 3.6),
}


def ellipse_pts(cx, cy, rx, ry, n=72):
    return [(cx + math.cos(i * 2 * math.pi / n) * rx, cy + math.sin(i * 2 * math.pi / n) * ry) for i in range(n)]


def poly(pts):
    return "M " + " L ".join("%s %s" % (f(x), f(y)) for x, y in pts) + " Z"


def clip_above(pts, y_of_x):
    """Teil eines Polygons oberhalb der Linie y = y_of_x(x) (einfaches Sutherland-Hodgman an einer Kante)."""
    out = []
    n = len(pts)
    for i in range(n):
        a = pts[i]
        bp = pts[(i + 1) % n]
        ina = a[1] <= y_of_x(a[0])
        inb = bp[1] <= y_of_x(bp[0])
        if ina:
            out.append(a)
        if ina != inb:
            # Schnittpunkt per Bisektion
            lo, hi = 0.0, 1.0
            for _ in range(30):
                m = (lo + hi) / 2
                p = (a[0] + (bp[0] - a[0]) * m, a[1] + (bp[1] - a[1]) * m)
                if (p[1] <= y_of_x(p[0])) == ina:
                    lo = m
                else:
                    hi = m
            out.append((a[0] + (bp[0] - a[0]) * lo, a[1] + (bp[1] - a[1]) * lo))
    return out


def face_parts():
    fd = "face"
    for stil, (rx, ry, irx, iry, pr) in EYES.items():
        eye = ("ellipse", 32, 32, rx, ry)
        write("%s/augen_%s_weiss.svg" % (fd, stil), svg(64, [el(eye, INK, INK, OUT_S * 2), el(eye, WHITE)]))
        iris = ("ellipse", 32, 32, irx, iry)
        write("%s/augen_%s_iris.svg" % (fd, stil), svg(64, [
            el(iris, GREY), inset(iris, 32 - irx * 0.2, 32 - iry * 0.45, 0.84)]))
        write("%s/augen_%s_pupille.svg" % (fd, stil), svg(64, [
            el(("ellipse", 32, 32.5, pr, pr * (iry / irx)), INK),
            el(("circle", 32 - irx * 0.36, 32 - iry * 0.4, max(2.2, irx * 0.3)), WHITE),
            el(("circle", 32 + irx * 0.38, 32 + iry * 0.36, max(1.1, irx * 0.13)), WHITE, opacity=0.9)]))
        w = rx + 1.5
        write("%s/augen_%s_froh.svg" % (fd, stil), svg(64, [
            line("M %s %s Q 32 %s %s %s" % (f(32 - w), f(35), f(35 - ry * 1.5 - 4), f(32 + w), f(35)), 5.2)]))
        write("%s/augen_%s_zu.svg" % (fd, stil), svg(64, [
            line("M %s %s Q 32 %s %s %s" % (f(32 - w), f(32), f(32 + 9), f(32 + w), f(32)), 5.2)]))
        write("%s/augen_%s_zwinker.svg" % (fd, stil), svg(64, [
            line("M %s %s Q %s %s %s %s" % (f(32 - w), f(34), f(32), f(26), f(32 + w), f(34)), 5.2),
            line("M %s %s L %s %s" % (f(32 + w - 1), f(34), f(32 + w + 3), f(30)), 4.0)]))
        # Müdes Lid: obere Hälfte, gerade Kante
        pts = clip_above(ellipse_pts(32, 32, rx + 0.6, ry + 0.6), lambda x: 32.5)
        lid = ("path", poly(pts))
        write("%s/lid_muede_%s.svg" % (fd, stil), svg(64, [el(lid, INK, INK, OUT_S * 2), el(lid, GREY), inset(lid, 32, 20, 0.86)]))
        # Trauriges Lid: außen (links beim linken Auge) tiefer
        # Linie: innen (x = 32 + rx) hoch oben, außen (x = 32 - rx) tiefer
        pts = clip_above(ellipse_pts(32, 32, rx + 0.6, ry + 0.6), lambda x, rx=rx, ry=ry: 32 - ry * 0.75 + (32 + rx - x) / (2 * rx) * ry * 1.05)
        lid = ("path", poly(pts))
        write("%s/lid_traurig_%s.svg" % (fd, stil), svg(64, [el(lid, INK, INK, OUT_S * 2), el(lid, GREY), inset(lid, 32, 20, 0.86)]))
    # Brauen (linke Braue; rechts gespiegelt). Innen = rechte Seite.
    brows = {
        "neutral": "M 20 35 Q 31 29 43 33",
        "hoch": "M 19 35 Q 31 24 43 31",
        "sorge": "M 20 36 Q 32 34 43 26",
        "streng": "M 20 28 Q 32 30 43 37",
    }
    for k, d in brows.items():
        write("%s/brauen_%s.svg" % (fd, k), svg(64, [line(d, 5.6)]))
    # Münder (64 x 64, Mitte 32/32)
    halo = lambda d: line(d, 9.5, WHITE, 0.3)
    m = {}
    m["neutral"] = [halo("M 24 32 Q 32 36.5 40 32"), line("M 24 32 Q 32 36.5 40 32", 5)]
    m["laecheln"] = [halo("M 19 29 Q 32 43 45 29"), line("M 19 29 Q 32 43 45 29", 5)]
    open_d = "M 17 26 Q 32 28 47 26 Q 46 47 32 47 Q 18 47 17 26 Z"
    m["lachen"] = [el(("path", open_d), MOUTH_DARK),
                   el(("path", "M 23 42 Q 32 35 41 42 Q 37 47 32 47 Q 27 47 23 42 Z"), TONGUE),
                   el(("path", open_d), "none", INK, 4.5)]
    m["stolz"] = [halo("M 20 31 Q 33 40 44 26"), line("M 20 31 Q 33 40 44 26", 5), line("M 42 23 Q 46 26 45 30", 3.6)]
    m["sorge"] = [halo("M 18 34 Q 22.5 29 27 33 Q 32 37 37 33 Q 41.5 29 46 34"), line("M 18 34 Q 22.5 29 27 33 Q 32 37 37 33 Q 41.5 29 46 34", 4.6)]
    m["traurig"] = [halo("M 24 37 Q 32 29.5 40 37"), line("M 24 37 Q 32 29.5 40 37", 5)]
    m["o"] = [el(("ellipse", 32, 33, 5.5, 6.5), MOUTH_DARK, INK, 4.2)]
    tongue = "M 33 35.5 Q 34 43 38.5 42.5 Q 42.5 41.5 41 34.5 Z"
    m["frech"] = [halo("M 19 29 Q 31 40 45 27"), el(("path", tongue), TONGUE, INK, 3.4), line("M 19 29 Q 31 40 45 27", 5)]
    for k, body in m.items():
        write("%s/mund_%s.svg" % (fd, k), svg(64, body))
    write("%s/wangen.svg" % fd, svg(64, [el(("ellipse", 32, 32, 10.5, 6.2), PINK, opacity=0.7)]))
    # Funkeln (128 x 128) rund um den Kopf
    sp = []
    for (x, y, r) in ((16, 30, 13), (110, 20, 15), (114, 100, 9), (12, 96, 8)):
        d = sparkle(x, y, r, 0.3)
        sp.append(el(("path", d), INK, INK, 5))
        sp.append(el(("path", d), "#F2A93B"))
        sp.append(el(("path", sparkle(x - r * 0.08, y - r * 0.08, r * 0.45, 0.3)), GOLD_LIGHT))
    write("%s/funkeln.svg" % fd, svg(128, sp))
    drop = ("path", "M 32 14 C 38 24 44 32 44 39 C 44 46 38 51 32 51 C 26 51 20 46 20 39 C 20 32 26 24 32 14 Z")
    write("%s/schweiss.svg" % fd, svg(64, [el(drop, "#A8D4F7", INK, 3.6), line("M 26 38 Q 26 44 30 46", 3, WHITE, 0.9)]))
    z = []
    for (x, y, s, w) in ((10, 52, 14, 4.2), (30, 32, 11, 3.8), (46, 16, 8, 3.4)):
        z.append(line("M %s %s L %s %s L %s %s L %s %s" % (f(x), f(y - s), f(x + s), f(y - s), f(x), f(y), f(x + s), f(y)), w))
    write("%s/zzz.svg" % fd, svg(64, z))


# ---------------------------------------------------------------------------------------------------------------
# Zubehör (128 x 128, Mitte 64/64 = Ankerpunkt)


def acc_part(name, shapes, details=None, fixed_under=None, shade=None, outline=OUT_S):
    write("acc/%s_f.svg" % name, svg(128, fill_layer(shapes, outline, shade)))
    body = (fixed_under or []) + (details or [])
    if body:
        write("acc/%s_l.svg" % name, svg(128, body))


def accessories():
    # Krone (sitzt mit der Unterkante bei y ~ 80)
    crown = ("path", "M 34 82 L 30 46 Q 30 40 36 44 L 48 56 L 60 34 Q 64 28 68 34 L 80 56 L 92 44 Q 98 40 98 46 L 94 82 Q 64 88 34 82 Z")
    acc_part("krone", [crown], shade=(56, 48, 0.88),
             details=[el(("circle", 64, 70, 5.5), "#EF5B4C", INK, 3), el(("circle", 46, 72, 3.8), "#3B8EEA", INK, 2.6),
                      el(("circle", 82, 72, 3.8), "#3FA85F", INK, 2.6), line("M 36 64 Q 64 70 92 64", 3, INK, 0.3)])
    # Heiligenschein: schwebender Ring (feste Farbe)
    ring = ("ellipse", 64, 52, 38, 11)
    write("acc/heiligenschein.svg", svg(128, [
        '<ellipse cx="64" cy="52" rx="38" ry="11" fill="none" stroke="%s" stroke-width="%s"/>' % (INK, f(9 + OUT_S * 2)),
        '<ellipse cx="64" cy="52" rx="38" ry="11" fill="none" stroke="%s" stroke-width="9"/>' % GOLD_LIGHT,
        '<path d="M 36 48 Q 50 42 70 42" fill="none" stroke="%s" stroke-width="3" stroke-linecap="round" opacity="0.8"/>' % WHITE]))
    # Blumenkranz (feste Farben): Ranke + Blüten vorne
    wreath = [line("M 22 74 Q 64 92 106 74", 6 + OUT_S * 2, INK), line("M 22 74 Q 64 92 106 74", 6, "#3FA85F")]
    leaves = []
    for (x, y, a) in ((32, 76, -30), (54, 84, 20), (76, 84, -20), (96, 76, 30)):
        leaves.append('<ellipse cx="%s" cy="%s" rx="7" ry="4" fill="#5DBB72" stroke="%s" stroke-width="2.6" transform="rotate(%s %s %s)"/>' % (
            f(x), f(y), INK, f(a), f(x), f(y)))
    flowers = []
    for (x, y, col) in ((22, 72, "#F4A7B9"), (43, 81, "#FFFFFF"), (64, 85, "#F2D27A"), (85, 81, "#FFFFFF"), (106, 72, "#F4A7B9")):
        petals = []
        for i in range(5):
            a = -math.pi / 2 + i * 2 * math.pi / 5
            petals.append(("circle", x + math.cos(a) * 5.2, y + math.sin(a) * 5.2, 4.6))
        for p in petals:
            flowers.append(el(p, INK, INK, 5))
        for p in petals:
            flowers.append(el(p, col))
        flowers.append(el(("circle", x, y, 3.2), "#F2A93B"))
    write("acc/blumenkranz.svg", svg(128, wreath + leaves + flowers))
    # Zauberhut
    cone = ("path", "M 34 82 C 44 64 50 40 60 20 Q 64 12 70 18 C 76 26 84 30 92 28 C 82 34 80 56 92 82 Z")
    brim = ("ellipse", 64, 84, 44, 9)
    acc_part("zauberhut", [cone, brim], shade=(56, 40, 0.88),
             details=[el(("path", sparkle(58, 58, 8, 0.3)), GOLD_LIGHT, INK, 2.4), el(("path", sparkle(73, 40, 5.5, 0.3)), GOLD_LIGHT, INK, 2.2),
                      line("M 38 76 Q 64 82 90 76", 3, INK, 0.3)])
    # Schleife
    loop_l = ("path", "M 62 70 C 50 52 30 50 28 64 C 26 78 48 82 62 72 Z")
    loop_r = ("path", mirror_x(loop_l[1], 64))
    knot = ("rect", 55, 62, 18, 18, 7)
    acc_part("schleife", [loop_l, loop_r, knot], shade=(56, 56, 0.86),
             details=[line("M 36 64 Q 42 68 50 68", 3, INK, 0.3), line(mirror_x("M 36 64 Q 42 68 50 68", 64), 3, INK, 0.3)])
    # Brillen: ein Glas je Auge (64 x 64, Mitte = Auge; rechts gespiegelt) + Steg (64 x 64, Mitte = Gesicht).
    # Das Glas passt um ein Auge mit Radius ~14,5; der Charakter skaliert es mit der Augenform.
    ring = ("tube", "M 15 32 A 17 17 0 1 0 49 32 A 17 17 0 1 0 15 32 Z", 5)
    write("acc/rundbrille_glas_f.svg", svg(64, fill_layer([ring], OUT_S)))
    write("acc/rundbrille_glas_l.svg", svg(64, ['<circle cx="32" cy="32" r="14.5" fill="%s" opacity="0.16"/>' % WHITE,
                                              line("M 21 25 Q 25 19 32 18.5", 3, WHITE, 0.85)]))
    write("acc/rundbrille_steg_f.svg", svg(64, fill_layer([("tube", "M 20 31 Q 32 25 44 31", 5)], OUT_S)))
    shade_d = "M 13 24 Q 13 19 18 19 L 46 19 Q 51 19 51 24 Q 50 46 32 47 Q 14 46 13 24 Z"
    write("acc/sonnenbrille_glas.svg", svg(64, [el(("path", shade_d), INK, INK, OUT_S * 2), el(("path", shade_d), "#2B2B33"),
                                              line("M 20 26 L 29 24", 3.4, WHITE, 0.5), line("M 21 32 L 25 31", 3, WHITE, 0.35)]))
    write("acc/sonnenbrille_steg.svg", svg(64, [line("M 18 25 Q 32 20 46 25", 5 + OUT_S * 2, INK), line("M 18 25 Q 32 20 46 25", 5, "#2B2B33")]))
    # Monokel: rechtes Auge (nicht gespiegelt), Kettchen außen
    mono = ("tube", "M 15 32 A 17 17 0 1 0 49 32 A 17 17 0 1 0 15 32 Z", 5)
    chain = ("tube", "M 46 42 Q 54 52 50 62", 2.6)
    write("acc/monokel_f.svg", svg(64, fill_layer([chain, mono], OUT_S)))
    write("acc/monokel_l.svg", svg(64, ['<circle cx="32" cy="32" r="14.5" fill="%s" opacity="0.16"/>' % WHITE,
                                        line("M 21 25 Q 25 19 32 18.5", 3, WHITE, 0.85)]))
    # Fliege
    bow_l = ("path", "M 60 64 L 34 50 Q 28 48 28 54 L 28 74 Q 28 80 34 78 Z")
    bow_r = ("path", mirror_x(bow_l[1], 64))
    acc_part("fliege", [bow_l, bow_r, ("rect", 55, 56, 18, 16, 6)], shade=(48, 54, 0.84))
    # Schal: Band + Ende
    band = ("rect", 26, 52, 76, 22, 11)
    end = ("path", "M 78 66 L 96 66 Q 100 66 100 70 L 98 104 Q 98 108 94 108 L 84 108 Q 80 108 80 104 Z")
    acc_part("schal", [end, band], shade=(50, 54, 0.86),
             details=[line("M 84 82 L 96 82", 3.6, WHITE, 0.6), line("M 83 94 L 96 94", 3.6, WHITE, 0.6),
                      line("M 46 56 L 42 70", 3.6, WHITE, 0.5), line("M 64 56 L 60 70", 3.6, WHITE, 0.5)])
    # Amulett: Schnur (fest) + Sonnenscheibe (eingefärbt)
    disk = [("circle", 64, 82, 13)]
    rays = []
    for i in range(8):
        a = i * math.pi / 4
        rays.append(line("M %s %s L %s %s" % (f(64 + math.cos(a) * 17), f(82 + math.sin(a) * 17), f(64 + math.cos(a) * 21), f(82 + math.sin(a) * 21)), 3.4))
    acc_part("amulett", disk, fixed_under=[], details=rays + [el(("circle", 64, 82, 5), "none", INK, 2.6, opacity=0.45)])
    write("acc/amulett_band.svg", svg(128, [line("M 34 48 Q 46 70 60 70", 3.2, INK), line("M 94 48 Q 82 70 68 70", 3.2, INK)]))


if __name__ == "__main__":
    base_bart()
    base_goettin()
    base_sonne()
    base_wolke()
    base_katze()
    base_nudel()
    face_parts()
    accessories()
    print("%d Dateien geschrieben nach %s" % (len(WRITTEN), os.path.normpath(ROOT)))
