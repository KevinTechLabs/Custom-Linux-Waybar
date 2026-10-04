"""☢ REACTOR — 4K wallpaper: top-down reactor core with glowing fuel assemblies.

Regenerate:  python3 extras/generate-wallpaper.py   (needs python-pillow, python-numpy)
Writes wallpapers/reactor-core-4k.png. Change W/H for other resolutions.
"""
import math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 3840, 2160
random.seed(7); np.random.seed(7)
GLOW = (57, 255, 20)
DIM = (31, 143, 11)
AMBER = (255, 176, 0)
CX, CY = int(W * 0.555), int(H * 0.53)     # core sits right of center (sidebar lives left)
R = 760                                    # core radius
MONO = "/usr/share/fonts/TTF/DejaVuSansMono.ttf"          # Arch path (ttf-dejavu)
MONOB = "/usr/share/fonts/TTF/DejaVuSansMono-Bold.ttf"
import os
if not os.path.exists(MONO):  # Debian/Ubuntu path
    MONO, MONOB = (p.replace("/TTF/", "/truetype/dejavu/") for p in (MONO, MONOB))
f_s, f_m, f_l = ImageFont.truetype(MONO, 26), ImageFont.truetype(MONOB, 34), ImageFont.truetype(MONOB, 60)

# ---------------- background: deep green-black with radial falloff + grain ----------------
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
d = np.sqrt(((xx - CX) / 1.15) ** 2 + (yy - CY) ** 2)
base = np.clip(1 - d / 2600, 0, 1) ** 2.2
bg = np.zeros((H, W, 3), np.float32)
bg[..., 0] = 2 + 6 * base
bg[..., 1] = 5 + 26 * base
bg[..., 2] = 3 + 5 * base
bg += np.random.normal(0, 2.2, (H, W, 1))          # film grain
# darken the far left where the sidebar opens
bg *= (0.55 + 0.45 * np.clip(xx / (W * 0.35), 0, 1))[..., None]
img = Image.fromarray(np.clip(bg, 0, 255).astype(np.uint8)).convert("RGBA")

# ---------------- layers ----------------
glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))   # gets blurred → bloom
sharp = Image.new("RGBA", (W, H), (0, 0, 0, 0))  # crisp linework on top
g, s = ImageDraw.Draw(glow), ImageDraw.Draw(sharp)

# faint dot grid
for x in range(0, W, 48):
    for y in range(0, H, 48):
        if random.random() < 0.9:
            s.point((x, y), fill=(*DIM, 70))

# ---------------- fuel assemblies: hex lattice inside the core ----------------
pitch = 62
hexr = 27
rows = int(R / (pitch * 0.866)) + 2
control_rods = set()
for _ in range(19):
    control_rods.add((random.randint(-9, 9), random.randint(-9, 9)))
def hexagon(cx, cy, r):
    return [(cx + r * math.cos(math.radians(60 * k + 30)), cy + r * math.sin(math.radians(60 * k + 30))) for k in range(6)]
for j in range(-rows, rows + 1):
    for i in range(-rows, rows + 1):
        x = CX + (i + (j % 2) * 0.5) * pitch
        y = CY + j * pitch * 0.866
        dist = math.hypot(x - CX, y - CY)
        if dist > R - 40:
            continue
        heat = (1 - dist / R) ** 1.3                   # hotter toward the middle
        heat *= 0.75 + 0.5 * random.random()
        heat = min(1.0, heat)
        if (i // 2, j // 2) in control_rods and random.random() < 0.35:
            # control rod: amber-rimmed, dark center
            s.polygon(hexagon(x, y, hexr), outline=(*AMBER, 200), width=3)
            s.ellipse([x - 8, y - 8, x + 8, y + 8], fill=(*AMBER, 220))
            g.ellipse([x - 14, y - 14, x + 14, y + 14], fill=(*AMBER, 120))
            continue
        a = int(60 + 195 * heat)
        col = (int(57 + 150 * heat ** 3), 255, int(20 + 120 * heat ** 3))   # whiter at the hot center
        s.polygon(hexagon(x, y, hexr), outline=(*GLOW, int(90 + 120 * heat)), width=2)
        s.polygon(hexagon(x, y, hexr - 7), fill=(*col, a))
        g.polygon(hexagon(x, y, hexr + 4), fill=(*GLOW, int(150 * heat)))

# core bloom (Cherenkov-style glow, in green)
g.ellipse([CX - R * 0.55, CY - R * 0.55, CX + R * 0.55, CY + R * 0.55], fill=(*GLOW, 70))

# ---------------- containment rings + ticks ----------------
for rr, w, a in [(R, 4, 230), (R + 28, 2, 140), (R + 110, 3, 200), (R + 125, 1, 90), (R + 260, 2, 110)]:
    s.ellipse([CX - rr, CY - rr, CX + rr, CY + rr], outline=(*GLOW, a), width=w)
    g.ellipse([CX - rr, CY - rr, CX + rr, CY + rr], outline=(*GLOW, a // 2), width=w + 6)
for k in range(360):
    ang = math.radians(k)
    r1 = R + 40
    r2 = r1 + (34 if k % 30 == 0 else 18 if k % 10 == 0 else 9)
    s.line([(CX + r1 * math.cos(ang), CY + r1 * math.sin(ang)), (CX + r2 * math.cos(ang), CY + r2 * math.sin(ang))],
           fill=(*GLOW, 220 if k % 10 == 0 else 120), width=2 if k % 10 == 0 else 1)
# dashed arc segments on the outer ring
for k in range(0, 360, 4):
    a0 = k + 0.5
    rr = R + 190
    s.arc([CX - rr, CY - rr, CX + rr, CY + rr], a0, a0 + 2.2, fill=(*DIM, 200), width=6)
# bright arc sweeps (like a scanner)
for a0, a1, rr in [(200, 285, R + 150), (20, 70, R + 150), (110, 140, R + 230)]:
    s.arc([CX - rr, CY - rr, CX + rr, CY + rr], a0, a1, fill=(*GLOW, 255), width=8)
    g.arc([CX - rr, CY - rr, CX + rr, CY + rr], a0, a1, fill=(*GLOW, 200), width=22)

# crosshair lines through the core
L = R + 420
for (x1, y1, x2, y2) in [(CX - L, CY, CX - R - 300, CY), (CX + R + 300, CY, min(lx - 60 if False else W - 700, CX + L), CY),
                         (CX, CY - L, CX, CY - R - 300), (CX, CY + R + 300, CX, min(H, CY + L))]:
    s.line([(x1, y1), (x2, y2)], fill=(*GLOW, 160), width=2)
s.line([(CX - L, CY), (CX - L + 60, CY)], fill=(*GLOW, 255), width=6)

# ---------------- radiation trefoil in the middle ----------------
def trefoil(draw, cx, cy, r, fill):
    for c in (90, 210, 330):   # PIL angles are clockwise from +x; blades at top-left/top-right/bottom
        draw.pieslice([cx - r, cy - r, cx + r, cy + r], c - 30 + 120, c + 30 + 120, fill=fill)
    rin = r * 0.30
    draw.ellipse([cx - rin, cy - rin, cx + rin, cy + rin], fill=(0, 0, 0, 0))
    rc = r * 0.20
    draw.ellipse([cx - rc, cy - rc, cx + rc, cy + rc], fill=fill)
tre = Image.new("RGBA", (W, H), (0, 0, 0, 0))
td = ImageDraw.Draw(tre)
td.ellipse([CX - 205, CY - 205, CX + 205, CY + 205], fill=(4, 14, 3, 235))      # dark plate behind the symbol
td.ellipse([CX - 205, CY - 205, CX + 205, CY + 205], outline=(*GLOW, 255), width=5)
trefoil(td, CX, CY, 170, (*GLOW, 255))
# cut the inner ring properly (pieslice + clear circle, then core dot)
tmask = Image.new("L", (W, H), 0)
tm = ImageDraw.Draw(tmask)
for c in (90, 210, 330):
    tm.pieslice([CX - 170, CY - 170, CX + 170, CY + 170], c - 30 + 120, c + 30 + 120, fill=255)
tm.ellipse([CX - 51, CY - 51, CX + 51, CY + 51], fill=0)
tm.ellipse([CX - 34, CY - 34, CX + 34, CY + 34], fill=255)
tre = Image.new("RGBA", (W, H), (0, 0, 0, 0))
td = ImageDraw.Draw(tre)
td.ellipse([CX - 205, CY - 205, CX + 205, CY + 205], fill=(4, 14, 3, 240))
td.ellipse([CX - 205, CY - 205, CX + 205, CY + 205], outline=(*GLOW, 255), width=5)
tre.paste(Image.new("RGBA", (W, H), (*GLOW, 255)), (0, 0), tmask)
g.bitmap((0, 0), tmask, fill=(*GLOW, 255))

# ---------------- HUD text ----------------
def txt(x, y, t, font=f_s, col=GLOW, a=230):
    s.text((x, y), t, font=font, fill=(*col, a))
lx = W - 660
txt(lx, CY - 560, "☢ REACTOR CORE · UNIT 01", f_m)
txt(lx, CY - 515, "PRESSURIZED WATER · 3411 MWt", f_s, DIM)
rows_txt = [("CORE TEMP", "312.4 °C"), ("COOLANT FLOW", "18 900 kg/s"), ("NEUTRON FLUX", "3.2e13 n/cm²s"),
            ("CONTROL RODS", "19 / 53 INSERTED"), ("CONTAINMENT", "NOMINAL")]
for k, (a, b) in enumerate(rows_txt):
    y = CY - 450 + k * 46
    txt(lx, y, a, f_s, DIM)
    txt(lx + 290, y, b, f_s)
    s.line([(lx, y + 38), (lx + 560, y + 38)], fill=(*DIM, 90), width=1)
# small output bars
for k in range(18):
    hgt = int(30 + 90 * abs(math.sin(k * 0.7 + 1.3)) * (0.6 + 0.4 * random.random()))
    x = lx + k * 30
    s.rectangle([x, CY + 20 - hgt, x + 18, CY + 20], fill=(*GLOW, 200))
txt(lx, CY + 40, "OUTPUT · LAST 18H", f_s, DIM)

# bottom-left readout (kept away from the sidebar's top area)
bx, by = 520, H - 260
txt(bx, by, "● REACTOR ONLINE", f_l)
txt(bx + 4, by + 80, "ALL SYSTEMS NOMINAL · CORE STABLE", f_m, DIM)
txt(bx + 4, by + 128, "LAT 41.2N  ·  GRID SYNC 60.00 Hz  ·  K-EFF 1.0002", f_s, DIM)

# corner brackets
for (x, y, dx, dy) in [(60, 90, 1, 1), (W - 60, 90, -1, 1), (60, H - 60, 1, -1), (W - 60, H - 60, -1, -1)]:
    s.line([(x, y), (x + 120 * dx, y)], fill=(*GLOW, 200), width=4)
    s.line([(x, y), (x, y + 120 * dy)], fill=(*GLOW, 200), width=4)

# ---------------- composite: bloom (3 radii) + sharp + trefoil ----------------
bloom = Image.new("RGBA", (W, H), (0, 0, 0, 0))
for rad, k in [(6, 0.9), (22, 0.7), (70, 0.55)]:
    b = glow.filter(ImageFilter.GaussianBlur(rad))
    arr = np.array(b).astype(np.float32)
    arr[..., 3] *= k
    bloom = Image.alpha_composite(bloom, Image.fromarray(arr.clip(0, 255).astype(np.uint8)))
out = Image.alpha_composite(img, bloom)
out = Image.alpha_composite(out, sharp)
out = Image.alpha_composite(out, tre)
# trefoil glow on top
tg = Image.new("RGBA", (W, H), (*GLOW, 0)); tg.putalpha(tmask.filter(ImageFilter.GaussianBlur(18)).point(lambda v: v * 0.7))
out = Image.alpha_composite(out, tg)

# scanlines + vignette
arr = np.array(out.convert("RGB")).astype(np.float32)
arr[::3] *= 0.93
vig = np.clip(1.15 - (np.sqrt(((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 2)) ** 2)) * 0.45, 0.55, 1)
arr *= vig[..., None]
import os
out_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "wallpapers", "reactor-core-4k.png")
Image.fromarray(arr.clip(0, 255).astype(np.uint8)).save(out_path, optimize=True)
print("wrote", os.path.normpath(out_path))
