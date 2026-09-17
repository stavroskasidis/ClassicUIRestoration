r"""
Generates the CurseForge project logo (curseforge/logo.png, 400x400 and a
1024x1024 variant) with Pillow, drawn at 4x and downsampled for clean edges.

Motif: a classic unit frame reduced to its essentials - the golden circular
portrait with a "restore" (counter-clockwise) arrow inside, and the flat
green health / blue mana bars on their black backdrop.

	python curseforge\make_logo.py
"""

import math
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
SIZE = 400
SCALE = 4
S = SIZE * SCALE

# Palette (classic UI gold / bar colours on a dark plate).
BG_OUTER = (16, 18, 24, 255)
BG = (28, 32, 41, 255)
BG_BORDER = (110, 86, 36, 255)
GOLD = (214, 172, 58, 255)
GOLD_DARK = (150, 114, 34, 255)
PORTRAIT = (40, 46, 58, 255)
BACKDROP = (0, 0, 0, 160)
HEALTH = (36, 196, 36, 255)
HEALTH_DARK = (22, 120, 22, 255)
MANA = (44, 78, 224, 255)
MANA_DARK = (26, 46, 140, 255)


def px(v):
	return int(round(v * SCALE))


def rounded_rect(draw, box, radius, fill, outline=None, width=0):
	draw.rounded_rectangle([px(v) for v in box], radius=px(radius), fill=fill, outline=outline, width=px(width))


def ring(draw, cx, cy, r_outer, r_inner, fill):
	draw.ellipse([px(cx - r_outer), px(cy - r_outer), px(cx + r_outer), px(cy + r_outer)], fill=fill)
	draw.ellipse([px(cx - r_inner), px(cy - r_inner), px(cx + r_inner), px(cy + r_inner)], fill=PORTRAIT)


def restore_arrow(draw, cx, cy, r, width, fill):
	# 270 degrees of arc (counter-clockwise visual), with an arrow head at the end.
	start, end = 300, 210  # PIL angles: clockwise from 3 o'clock
	draw.arc([px(cx - r), px(cy - r), px(cx + r), px(cy + r)], start=start, end=end, fill=fill, width=px(width))
	# Arrow head at the "end" angle, pointing along the direction of travel.
	a = math.radians(end)
	tip_x, tip_y = cx + r * math.cos(a), cy + r * math.sin(a)
	# Tangent direction of a clockwise-drawn arc at angle a (PIL draws start->end clockwise in screen space).
	tx, ty = -math.sin(a), math.cos(a)
	nx, ny = math.cos(a), math.sin(a)
	head = 20
	p1 = (tip_x + tx * head * 0.9, tip_y + ty * head * 0.9)
	p2 = (tip_x + nx * head * 0.8, tip_y + ny * head * 0.8)
	p3 = (tip_x - nx * head * 0.8, tip_y - ny * head * 0.8)
	draw.polygon([(px(x), px(y)) for x, y in (p1, p2, p3)], fill=fill)


def bar(draw, box, fill, dark, fraction):
	x0, y0, x1, y1 = box
	draw.rectangle([px(x0), px(y0), px(x1), px(y1)], fill=dark)
	draw.rectangle([px(x0), px(y0), px(x0 + (x1 - x0) * fraction), px(y1)], fill=fill)
	# Classic bars have a lighter highlight line along the top.
	hl = tuple(min(255, c + 50) for c in fill[:3]) + (255,)
	draw.rectangle([px(x0), px(y0), px(x0 + (x1 - x0) * fraction), px(y0 + 2)], fill=hl)


def make():
	img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
	draw = ImageDraw.Draw(img)

	# Plate.
	rounded_rect(draw, (0, 0, SIZE, SIZE), 56, BG_OUTER)
	rounded_rect(draw, (10, 10, SIZE - 10, SIZE - 10), 48, BG, outline=BG_BORDER, width=4)

	# Backdrop behind the bars (the classic semi-transparent black box).
	backdrop = Image.new("RGBA", (S, S), (0, 0, 0, 0))
	bd = ImageDraw.Draw(backdrop)
	bd.rectangle([px(150), px(138), px(352), px(262)], fill=BACKDROP)
	img.alpha_composite(backdrop)
	draw = ImageDraw.Draw(img)

	# Bars.
	bar(draw, (160, 150, 342, 196), HEALTH, HEALTH_DARK, 0.78)
	bar(draw, (160, 206, 342, 250), MANA, MANA_DARK, 0.55)

	# Portrait ring with the restore arrow.
	cx, cy = 128, 200
	ring(draw, cx, cy, 84, 68, GOLD_DARK)
	ring(draw, cx, cy, 80, 68, GOLD)
	restore_arrow(draw, cx, cy, 40, 12, GOLD)

	out = img.resize((SIZE, SIZE), Image.LANCZOS)
	out.save(os.path.join(HERE, "logo.png"))
	img.resize((1024, 1024), Image.LANCZOS).save(os.path.join(HERE, "logo-1024.png"))
	print("wrote logo.png (400x400) and logo-1024.png")


if __name__ == "__main__":
	make()
