#!/usr/bin/env python3
"""Generate the Dragon Agent "DR" launcher icons (assets/icon.png, icon_fg.png).

Pure stdlib (zlib + struct) — no imaging dependencies. Renders a bold
geometric DR monogram with the app's ember gradient over the charcoal
background, anti-aliased by 2x2 supersampling.
"""
import math
import struct
import zlib

SIZE = 1024

BG = (0x0B, 0x0C, 0x10)
GOLD = (0xFF, 0xC5, 0x3D)
EMBER = (0xFF, 0x6A, 0x3D)
EMBER_DEEP = (0xE5, 0x48, 0x4D)


def lerp(a, b, t):
    return a + (b - a) * t


def mix(c1, c2, t):
    return tuple(lerp(a, b, t) for a, b in zip(c1, c2))


def gradient(t):
    """gold -> ember -> deep red, t in 0..1"""
    if t < 0.5:
        return mix(GOLD, EMBER, t / 0.5)
    return mix(EMBER, EMBER_DEEP, (t - 0.5) / 0.5)


# ---------------- glyph geometry (unit space, y down) ----------------
Y0, Y1 = 0.315, 0.685          # cap height band
T = 0.058                       # stroke weight


def in_d(x, y):
    xL = 0.155
    if not (Y0 <= y <= Y1):
        return False
    # stem
    if xL <= x <= xL + T:
        return True
    # bowl: right half-annulus centred on stem's left edge
    cx, cy = xL, (Y0 + Y1) / 2
    r_out = (Y1 - Y0) / 2
    dx, dy = x - cx, y - cy
    d = math.hypot(dx, dy)
    return r_out - T <= d <= r_out and dx >= 0


def in_r(x, y):
    xR = 0.505
    if not (Y0 <= y <= Y1):
        return False
    # stem
    if xR <= x <= xR + T:
        return True
    # bowl: upper half-annulus
    r_out = 0.118
    cx, cy = xR, Y0 + r_out
    dx, dy = x - cx, y - cy
    d = math.hypot(dx, dy)
    if r_out - T <= d <= r_out and dy <= 0:
        pass
    else:
        # leg: diagonal bar from under the bowl to the baseline
        p1 = (xR + T * 0.55, Y0 + 2 * r_out * 0.92)
        p2 = (xR + 0.305, Y1)
        vx, vy = p2[0] - p1[0], p2[1] - p1[1]
        wx, wy = x - p1[0], y - p1[1]
        seg_len2 = vx * vx + vy * vy
        tt = max(0.0, min(1.0, (wx * vx + wy * vy) / seg_len2))
        px, py = p1[0] + tt * vx, p1[1] + tt * vy
        if math.hypot(x - px, y - py) <= T * 0.62:
            return True
        return False
    return True


def glyph_alpha(x, y):
    return 1.0 if (in_d(x, y) or in_r(x, y)) else 0.0


# ---------------- rasterizer ----------------

def render(with_background):
    ss = 2  # 2x2 supersampling
    step = 1.0 / (SIZE * ss)
    rows = []
    grad_top, grad_bot = Y0, Y1
    for py in range(SIZE):
        row = bytearray([0])  # filter byte
        sy = py / SIZE
        for px in range(SIZE):
            sx = px / SIZE
            cov = 0
            for oy in range(ss):
                for ox in range(ss):
                    u = sx + (ox + 0.5) * step
                    v = sy + (oy + 0.5) * step
                    cov += glyph_alpha(u, v)
            a = cov / (ss * ss)
            if with_background:
                col = bytearray(BG)
                # ambient ember glow
                g = max(0.0, 1.0 - math.hypot(sx - 0.5, sy - 0.47) / 0.58)
                g = g * g
                for i in range(3):
                    col[i] = int(lerp(col[i], EMBER[i], g * 0.32))
                if a > 0:
                    gc = gradient(
                        min(1.0, max(0.0, (sy - grad_top) / (grad_bot - grad_top))))
                    for i in range(3):
                        col[i] = int(lerp(col[i], gc[i], a))
                col.append(255)
                row += bytes(col)
            else:
                gc = gradient(
                    min(1.0, max(0.0, (sy - grad_top) / (grad_bot - grad_top))))
                row += bytes(min(255, max(0, int(c))) for c in gc)
                row += bytes([min(255, max(0, int(a * 255)))])
        rows.append(bytes(row))

    def chunk(tag, data):
        raw = tag + data
        return (struct.pack('>I', len(data)) + raw +
                struct.pack('>I', zlib.crc32(raw) & 0xFFFFFFFF))

    ihdr = struct.pack('>IIBBBBB', SIZE, SIZE, 8,
                       6 if with_background else 6, 0, 0, 0)
    png = (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', ihdr) +
           chunk(b'IDAT', zlib.compress(b''.join(rows), 6)) +
           chunk(b'IEND', b''))
    return png


if __name__ == '__main__':
    import os
    out_dir = os.path.join(os.path.dirname(__file__), '..', 'assets')
    os.makedirs(out_dir, exist_ok=True)
    with open(os.path.join(out_dir, 'icon.png'), 'wb') as f:
        f.write(render(True))
    print('wrote assets/icon.png')
    with open(os.path.join(out_dir, 'icon_fg.png'), 'wb') as f:
        f.write(render(False))
    print('wrote assets/icon_fg.png')
