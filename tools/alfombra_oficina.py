# Alfombra de la oficina en pixel art, estilo persa: centro rojo con flores y medallón, borde azul oscuro con flores.
# Uso: python alfombra.py <salida.png> [escala]
import math
import random
import sys

from PIL import Image

W, H = 62, 125
STEP = 7            # distancia entre flores del borde
BAND = (3, 9)       # filas/columnas del borde azul (centro en 6)

RED = (150, 32, 36)
RED2 = (140, 28, 33)
DRED = (98, 18, 24)
NAVY = (30, 34, 60)
NAVY2 = (38, 44, 76)
CREAM = (230, 212, 168)
GOLD = (214, 168, 86)
GREEN = (96, 124, 82)
PINK = (210, 96, 84)

px = {}
rnd = random.Random(7)


def put(x, y, c):
    """Pinta con simetría en los 4 cuadrantes."""
    for xx in (x, W - 1 - x):
        for yy in (y, H - 1 - y):
            if 0 <= xx < W and 0 <= yy < H:
                px[(xx, yy)] = c


def put1(x, y, c):
    if 0 <= x < W and 0 <= y < H:
        px[(x, y)] = c


# Fondo: lana roja con leve variación
for y in range(H):
    for x in range(W):
        px[(x, y)] = RED if rnd.random() < 0.7 else RED2

# Marcos: orilla oscura, línea crema, borde azul, línea crema, línea roja oscura
for y in range(H):
    for x in range(W):
        d = min(x, y, W - 1 - x, H - 1 - y)
        if d == 0:
            px[(x, y)] = DRED
        elif d == 2 or d == 10:
            px[(x, y)] = CREAM
        elif BAND[0] <= d <= BAND[1]:
            px[(x, y)] = NAVY if (x + y) % 5 else NAVY2
        elif d == 11:
            px[(x, y)] = DRED

FLOWER = ["..R..",
          ".RCR.",
          "RCGCR",
          ".RCR.",
          "..R.."]
SMALL = [".P.",
         "PGP",
         ".P."]
COL = {"R": PINK, "C": CREAM, "G": GOLD, "P": PINK, "N": NAVY, "D": DRED, "g": GREEN}


def stamp(cx, cy, pat, sym=True, colors=COL):
    h = len(pat)
    w = len(pat[0])
    for j, row in enumerate(pat):
        for i, ch in enumerate(row):
            if ch != ".":
                (put if sym else put1)(cx - w // 2 + i, cy - h // 2 + j, colors[ch])


# Borde: flores cada STEP con una enredadera crema y hojas verdes entre ellas
c = (BAND[0] + BAND[1]) // 2
for x in range(c, W - c, 1):
    k = (x - c) % STEP
    if k == 0:
        continue
    wave = round(1.6 * math.sin((x - c) / STEP * math.pi))
    for y, side in ((c + wave, 1), (H - 1 - c - wave, -1)):
        put1(x, y, CREAM if k % 2 else GOLD)
    if k == 3:
        put1(x, c - wave, GREEN)
        put1(x, H - 1 - c + wave, GREEN)
for y in range(c, H - c, 1):
    k = (y - c) % STEP
    if k == 0:
        continue
    wave = round(1.6 * math.sin((y - c) / STEP * math.pi))
    for x in (c + wave, W - 1 - c - wave):
        put1(x, y, CREAM if k % 2 else GOLD)
    if k == 3:
        put1(c - wave, y, GREEN)
        put1(W - 1 - c + wave, y, GREEN)
BF = {"P": PINK, "G": CREAM}
for x in range(c, W - c + 1, STEP):
    stamp(x, c, SMALL, sym=False, colors=BF)
    stamp(x, H - 1 - c, SMALL, sym=False, colors=BF)
for y in range(c, H - c + 1, STEP):
    stamp(c, y, SMALL, sym=False, colors=BF)
    stamp(W - 1 - c, y, SMALL, sym=False, colors=BF)
for (x, y) in [(c, c), (W - 1 - c, c), (c, H - 1 - c), (W - 1 - c, H - 1 - c)]:
    stamp(x, y, FLOWER, sym=False)

# Campo: de 12 a W-13 / H-13
F0 = 12
cx, cy = (W - 1) / 2, (H - 1) / 2


def diamond(a, b, layers, ox=cx, oy=cy):
    """Rombo centrado en (ox, oy); layers = [(fracción, color)] de afuera hacia adentro."""
    for y in range(F0, H - F0):
        for x in range(F0, W - F0):
            t = abs(x - ox) / a + abs(y - oy) / b
            col = None
            for f, cc in layers:
                if t <= f:
                    col = cc
            if col:
                px[(x, y)] = col


# Medallón central: crema, azul, rojo con flor dorada
diamond(13, 24, [(1.0, CREAM), (0.92, NAVY), (0.62, GOLD), (0.55, RED), (0.25, CREAM)])
stamp(int(cx), int(cy), FLOWER)
# Pequeñas flores dentro del azul del medallón
for (dx, dy) in [(0, 17), (8, 0), (4, 9)]:
    stamp(int(cx) - dx, int(cy) - dy, SMALL, colors={"P": CREAM, "G": GOLD})
# Colgantes arriba y abajo del medallón
for dy in range(25, 31):
    put(int(cx), int(cy) - dy, CREAM if dy % 2 else GOLD)
stamp(int(cx), int(cy) - 32, FLOWER)

# Esquinas del campo: cuarto de rombo azul con borde crema
for y in range(F0, H - F0):
    for x in range(F0, W - F0):
        for (ox, oy) in [(F0, F0), (W - 1 - F0, F0), (F0, H - 1 - F0), (W - 1 - F0, H - 1 - F0)]:
            t = abs(x - ox) / 11 + abs(y - oy) / 17
            if t <= 1.0:
                px[(x, y)] = CREAM if t > 0.88 else (NAVY if t > 0.3 else GOLD)

# Ramitas y flores sueltas en el campo (un cuadrante, el resto por simetría)
sprays = [(18, 30), (24, 40), (17, 48), (25, 24), (20, 57), (14, 38), (27, 52)]
for (x, y) in sprays:
    stamp(x, y, SMALL)
    put(x - 1, y + 2, GREEN)
    put(x + 1, y + 2, GREEN)
    put(x, y + 3, DRED)
# Enredaderas oscuras que unen las flores
for t in range(0, 60):
    a = t / 59
    x = round(16 + 9 * a + 2 * math.sin(a * 6))
    y = round(28 + 32 * a)
    if px.get((x, y)) in (RED, RED2):
        put(x, y, DRED)

img = Image.new("RGB", (W, H))
for (x, y), col in px.items():
    img.putpixel((x, y), col)
scale = int(sys.argv[2]) if len(sys.argv) > 2 else 6
img.resize((W * scale, H * scale), Image.NEAREST).save(sys.argv[1])
print("ok", W * scale, H * scale)
