"""Synthetic camera pictures of GoAbacUs sheets for the tutor_vision tests.

Renders the printed sheets (from make_calibration_sheets.py and the desk film
sheets) in sheet space at K px/mm, puts rods / an abacus / a finger on them,
projects with a random perspective into a 1280 x 720 "phone" frame and adds
uneven light, colour cast, blur, sensor noise and JPEG.

usage: python3 render_scenes.py <sheets_dir_300dpi> <film_png_dir> <out_dir>
"""
import json, math, os, sys
import numpy as np
import cv2

K = 8.0                     # texture px per mm
CAM_W, CAM_H = 1280, 720
rng = np.random.default_rng(7)

ROD_RGB = {1: (236, 226, 205), 2: (205, 40, 40), 3: (120, 190, 90), 4: (150, 70, 150), 5: (245, 205, 50),
           6: (35, 110, 55), 7: (30, 30, 30), 8: (130, 80, 25), 9: (40, 95, 165), 10: (240, 125, 20)}


def load_sheet(png, dpi, x0, y0, w, h):
    im = cv2.imread(png, cv2.IMREAD_COLOR)[:, :, ::-1]  # RGB
    k = dpi / 25.4
    page_h = im.shape[0] / k
    top = (page_h - y0 - h) * k
    crop = im[int(round(top)):int(round(top + h * k)), int(round(x0 * k)):int(round((x0 + w) * k))]
    return cv2.resize(crop, (int(w * K), int(h * K)), interpolation=cv2.INTER_AREA).astype(np.float32)


def tex_pt(x, y, H):
    return (x * K, (H - y) * K)


def draw_rod(tex, shadow, H, cx, cy, ang, n, color):
    L, Wd = 10.0 * n, 10.0
    c, s = math.cos(ang), math.sin(ang)
    pts = []
    for dx, dy in [(-L / 2, -Wd / 2), (L / 2, -Wd / 2), (L / 2, Wd / 2), (-L / 2, Wd / 2)]:
        pts.append(tex_pt(cx + dx * c - dy * s, cy + dx * s + dy * c, H))
    poly = np.array(pts, np.float32)
    sh = poly + np.array([1.6 * K, 1.2 * K], np.float32)
    cv2.fillPoly(shadow, [sh.astype(np.int32)], 1.0)
    col = np.array(color, np.float32) * rng.uniform(0.92, 1.05)
    m = np.zeros(tex.shape[:2], np.uint8)
    cv2.fillPoly(m, [poly.astype(np.int32)], 1)
    edge = cv2.erode(m, np.ones((5, 5), np.uint8))
    tex[m > 0] = col
    tex[(m > 0) & (edge == 0)] = col * 0.78


def render_rods(base, H, trains):
    shadow = np.zeros(base.shape[:2], np.float32)
    scratch = base.copy()
    for pass_ in range(2):
        tex = apply_shadow(base, shadow) if pass_ == 1 else scratch
        for (x, y, ang, values) in trains:
            off = 0.0
            L = 10.0 * sum(values)
            for v in values:
                mid = -L / 2 + off + 5.0 * v
                draw_rod(tex, shadow if pass_ == 0 else np.zeros_like(shadow), H,
                         x + mid * math.cos(ang), y + mid * math.sin(ang), ang, v, ROD_RGB[v])
                off += 10.0 * v
    return tex


def render_abacus(base, H, digits, field):
    """digits[0] = units = bottom wire."""
    shadow = np.zeros(base.shape[:2], np.float32)
    _draw_abacus(base.copy(), shadow, H, digits, field)
    tex = apply_shadow(base, shadow, 0.3, 2.0)
    _draw_abacus(tex, np.zeros_like(shadow), H, digits, field)
    return tex


def _draw_abacus(tex, shadow, H, digits, field):
    r0 = np.random.default_rng(sum(digits) * 31 + len(digits))
    fx, fy, fw, fh = field
    W, Hh = 230.0, 150.0
    ox, oy = fx + (fw - W) / 2, fy + (fh - Hh) / 2
    bar = 12.0
    wood = np.array((150, 100, 55), np.float32)

    def rect(x, y, w, h, col, shade=True):
        p0 = tex_pt(x, y + h, H); p1 = tex_pt(x + w, y, H)
        a = (int(p0[0]), int(p0[1])); b = (int(p1[0]), int(p1[1]))
        if shade:
            cv2.rectangle(shadow, (a[0] + 14, a[1] + 10), (b[0] + 14, b[1] + 10), 1.0, -1)
        tex[a[1]:b[1], a[0]:b[0]] = col

    rect(ox, oy, W, bar, wood); rect(ox, oy + Hh - bar, W, bar, wood)
    rect(ox, oy, bar, Hh, wood); rect(ox + W - bar, oy, bar, Hh, wood)
    inner_y0, inner_h = oy + bar, Hh - 2 * bar
    pitch = inner_h / 10
    bw, bh = 16.0, 11.0
    xl, xr = ox + bar, ox + W - bar
    for row in range(10):
        wy = inner_y0 + pitch * (row + 0.5)
        rect(xl, wy - 0.6, xr - xl, 1.2, (160, 160, 165), shade=False)
        d = digits[row]
        for b in range(10):
            if b < d:
                bx = xl + bw * (b + 0.5)
            else:
                bx = xr - bw * (10 - b - 0.5)
            col = (60, 38, 22) if b in (4, 5) else (222, 175, 105)
            col = np.array(col, np.float32) * r0.uniform(0.93, 1.05)
            c = tex_pt(bx, wy, H)
            cv2.ellipse(shadow, (int(c[0] + 10), int(c[1] + 8)), (int(bw / 2 * K), int(bh / 2 * K)), 0, 0, 360, 1.0, -1)
            cv2.ellipse(tex, (int(c[0]), int(c[1])), (int(bw / 2 * K), int(bh / 2 * K)), 0, 0, 360, col.tolist(), -1)
            cv2.ellipse(tex, (int(c[0]), int(c[1])), (int(bw / 2 * K), int(bh / 2 * K)), 0, 0, 360, (col * 0.7).tolist(), 3)


def apply_shadow(tex, shadow, strength=0.35, blur_mm=1.5):
    s = cv2.GaussianBlur(shadow, (0, 0), blur_mm * K)
    return tex * (1 - strength * s[:, :, None])


def camera(tex, Wmm, Hmm, seed, mirrored=False, light=None, shift=(0, 0)):
    r = np.random.default_rng(seed)
    if mirrored:
        tex = tex[:, ::-1].copy()
    th, tw = tex.shape[:2]
    # sheet fills 70-85 % of the frame width, random perspective & rotation
    fill = r.uniform(0.66, 0.8)
    sw = CAM_W * fill
    sh = sw * Hmm / Wmm
    if sh > CAM_H * 0.88:
        sh = CAM_H * 0.88; sw = sh * Wmm / Hmm
    cx, cy = CAM_W / 2 + r.uniform(-30, 30) + shift[0], CAM_H / 2 + r.uniform(-12, 12) + shift[1]
    rot = r.uniform(-0.12, 0.12)
    quad = []
    for dx, dy in [(-0.5, -0.5), (0.5, -0.5), (0.5, 0.5), (-0.5, 0.5)]:
        x, y = dx * sw, dy * sh
        quad.append((cx + x * math.cos(rot) - y * math.sin(rot), cy + x * math.sin(rot) + y * math.cos(rot)))
    quad = np.array(quad, np.float32)
    # keystone: top edge shorter (camera tilted), random jitter
    k = r.uniform(0.0, 0.12)
    quad[0, 0] += sw * k / 2; quad[1, 0] -= sw * k / 2
    quad += r.uniform(-12, 12, quad.shape).astype(np.float32)
    if shift == (0, 0):
        lo = quad.min(0); hi = quad.max(0)
        quad -= (np.minimum(lo - 6, 0) + np.maximum(hi - np.array([CAM_W - 6, CAM_H - 6]), 0)).astype(np.float32)
    src = np.array([(0, 0), (tw, 0), (tw, th), (0, th)], np.float32)
    M = cv2.getPerspectiveTransform(src, quad)
    bgc = r.uniform(60, 120, 3)
    img = cv2.warpPerspective(tex, M, (CAM_W, CAM_H), flags=cv2.INTER_AREA, borderMode=cv2.BORDER_CONSTANT,
                              borderValue=bgc.tolist())
    # uneven light and colour cast
    yy, xx = np.mgrid[0:CAM_H, 0:CAM_W].astype(np.float32)
    if light is None:
        light = (r.uniform(-0.25, 0.25), r.uniform(-0.2, 0.2), r.uniform(0.8, 1.0), r.uniform(0.85, 1.1, 3))
    gx, gy, base, cast = light
    field = base * (1 + gx * (xx / CAM_W - 0.5) + gy * (yy / CAM_H - 0.5))
    img = img * field[:, :, None] * np.array(cast, np.float32)[None, None, :]
    img = cv2.GaussianBlur(img, (0, 0), 0.8)
    img += r.normal(0, 3.0, img.shape)
    img = np.clip(img, 0, 255).astype(np.uint8)
    return img, light


def save(out, name, img):
    cv2.imwrite(os.path.join(out, name), img[:, :, ::-1], [cv2.IMWRITE_JPEG_QUALITY, 82])


def main():
    sheets, film, out = sys.argv[1:4]
    os.makedirs(out, exist_ok=True)
    truth = {}
    calib = load_sheet(f'{sheets}/calibration.png', 300, 38.5, 25, 220, 160)
    mat = load_sheet(f'{sheets}/abacus-mat.png', 300, 12, 12, 273, 186)
    table = load_sheet(f'{film}/add-answers.png', 150, 38.5, 25, 220, 160)

    # 1. Calibration: pose only
    for i in range(6):
        mir = i >= 4
        img, _ = camera(calib, 220, 160, 100 + i, mirrored=mir)
        save(out, f'calib_{i}.jpg', img)
        truth[f'calib_{i}.jpg'] = {'sheet': 14, 'mirrored': mir, 'hint': 'ok'}
    img, _ = camera(calib, 220, 160, 150, shift=(260, 0))
    save(out, 'calib_6.jpg', img)
    truth['calib_6.jpg'] = {'sheet': 14, 'mirrored': False, 'hint': 'cutRight'}

    # 2. Rods: empty reference + scene with the same pose
    rod_scenes = [
        [(60, 120, 0.0, [3]), (150, 120, 0.0, [7]), (60, 90, 0.0, [5]), (150, 50, 0.0, [10])],
        [(110, 115, 0.0, [7, 5]), (110, 75, 0.0, [8, 2]), (60, 40, 0.3, [4])],
        [(50, 120, 0.0, [1]), (80, 120, 0.0, [2]), (135, 120, 0.0, [6]), (175, 95, 1.57, [9]), (80, 60, -0.5, [8])],
        [(110, 115, 0.0, [9, 6]), (100, 75, 0.0, [3, 3, 3]), (60, 35, 0.0, [10]), (170, 35, 0.0, [1])],
        [(60, 110, 0.1, [2, 5]), (150, 110, -0.1, [6, 4]), (110, 50, 0.0, [7, 1])],
        [(55, 125, 0.0, [5]), (55, 95, 0.0, [4]), (55, 65, 0.0, [3]), (55, 35, 0.0, [2]), (125, 80, 0.0, [10, 5])],
    ]
    for i, trains in enumerate(rod_scenes):
        tex = render_rods(calib, 160, trains)
        seed = 200 + i
        ref, light = camera(calib, 220, 160, seed)
        img, _ = camera(tex, 220, 160, seed, light=(light[0], light[1], light[2] * 0.97, light[3]))
        save(out, f'rods_{i}_empty.jpg', ref)
        save(out, f'rods_{i}.jpg', img)
        truth[f'rods_{i}.jpg'] = {'trains': sorted([t[3] for t in trains])}

    # 3. Abacus on the mat
    ab_digits = [[0] * 10, [3, 0, 7, 0, 0, 0, 0, 0, 0, 0], [5, 2, 9, 4, 1, 0, 0, 0, 0, 0],
                 [10, 0, 6, 8, 3, 5, 1, 2, 7, 4], [1, 1, 1, 1, 1, 1, 1, 1, 1, 1]]
    for i, digits in enumerate(ab_digits):
        tex = render_abacus(mat, 186, digits, (10, 10, 253, 166))
        seed = 300 + i
        ref, light = camera(mat, 273, 186, seed)
        img, _ = camera(tex, 273, 186, seed, light=light)
        save(out, f'abacus_{i}_empty.jpg', ref)
        save(out, f'abacus_{i}.jpg', img)
        truth[f'abacus_{i}.jpg'] = {'digits': digits}

    # 4. Touches on the addition table, seen from behind through matte film
    behind = 255 - (255 - table) * 0.55
    behind = cv2.GaussianBlur(behind, (0, 0), 0.4 * K) * 0.85
    cs = 140 / 12
    cases = [(3, 4, 0), (7, 9, 0), (11, 2, 0), (1, 11, 0), (6, 6, 0), (5, 3, 2.5), (9, 8, 4), (2, 6, 8)]
    for i, (r, c, hover) in enumerate(cases):
        px, py = 40 + cs * (c + 0.5), 150 - cs * (r + 0.5)
        shadow = np.zeros(behind.shape[:2], np.float32)
        layers = []
        # fingertip at height `hover`, finger rising towards the child (down), palm higher
        for t in np.linspace(0, 1, 9):
            hgt = hover + t * 25
            x, y = px + t * 8, py - t * 60
            layers.append((x, y, 7 + t * 3, 9 + t * 4, hgt))
        layers.append((px + 20, py - 85, 35, 30, 45))
        dark = np.zeros_like(shadow)
        for (x, y, rx, ry, hgt) in layers:
            m = np.zeros_like(shadow)
            cc = tex_pt(x, y, 160)
            cv2.ellipse(m, (int(cc[0]), int(cc[1])), (int(rx * K), int(ry * K)), 0, 0, 360, 1.0, -1)
            sig = (0.35 + 1.0 * hgt) * K
            m = cv2.GaussianBlur(m, (0, 0), sig)
            att = 0.55 * math.exp(-hgt / 60)
            dark = np.maximum(dark, att * m)
        scene = behind * (1 - dark[:, :, None])
        seed = 400 + i
        ref, light = camera(behind, 220, 160, seed, mirrored=True)
        img, _ = camera(scene, 220, 160, seed, mirrored=True, light=light)
        save(out, f'touch_{i}_empty.jpg', ref)
        save(out, f'touch_{i}.jpg', img)
        truth[f'touch_{i}.jpg'] = {'cell': [r, c] if hover == 0 else None, 'hover_mm': hover}

    with open(os.path.join(out, 'truth.json'), 'w') as f:
        json.dump(truth, f, indent=1)
    print('scenes:', len(truth))


if __name__ == '__main__':
    main()
