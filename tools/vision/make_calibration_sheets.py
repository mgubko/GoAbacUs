"""Printable calibration sheets for the GoAbacUs camera (test without mirrors).

Same frame as the desk film sheets (/mnt/project-files/goabacus/film-templates):
sheet = camera zone 220 x 160 mm, working field 200 x 140 mm at (10, 10),
ArUco DICT_4X4_50 8 mm corner markers 0-3 (TL, TR, BR, BL as the child sees it),
sheet-ID marker at (201, 151), 12-patch colour strip along the bottom border.
Coordinates in mm, origin = bottom-left corner of the sheet, y up.

Page 1  (id 14) "Калибровка и палочки": grey field with a 1 cm grid and two
        20 cm tracks, for rods and for checking the normalisation.
Page 2  (id 15) "Коврик для счётов": A4-size mat, markers at the page corners
        (field 257 x 170), for a real abacus lying flat.
"""
import sys
import cv2
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
from matplotlib.patches import Rectangle

A4W, A4H = 297.0, 210.0
ARUCO = cv2.aruco.getPredefinedDictionary(cv2.aruco.DICT_4X4_50)
ROD_COLOURS = [('#ffffff', 'white'), ('#9a9a9a', 'grey'), ('#f2e6cf', '1'), ('#e41a1c', '2'), ('#8fd16a', '3'),
               ('#a64ca6', '4'), ('#ffd92f', '5'), ('#1b7837', '6'), ('#111111', '7'), ('#8c510a', '8'),
               ('#2166ac', '9'), ('#ff7f00', '10')]
FIELD_GREY = '#a8a8a8'
DPI = 150


def marker(ax, mid, x, y, size=8.0):
    img = cv2.aruco.generateImageMarker(ARUCO, mid, 60, borderBits=1)
    ax.imshow(img, cmap='gray', vmin=0, vmax=255, extent=(x, x + size, y, y + size),
              interpolation='nearest', zorder=5)
    ax.add_patch(Rectangle((x - 1, y - 1), size + 2, size + 2, fc='white', ec='none', zorder=4))


def ruler(ax, x, y):
    ax.plot([x, x + 100], [y, y], color='k', lw=0.6)
    for t in range(0, 101, 10):
        ax.plot([x + t] * 2, [y, y + 1.5], color='k', lw=0.4)
    ax.text(x + 105, y, '← 100 мм: проверьте линейкой', fontsize=5, va='center', color='#666')


def strip(ax, x0, y0):
    for i, (c, lab) in enumerate(ROD_COLOURS):
        x = x0 + i * 9.5
        ax.add_patch(Rectangle((x, y0), 8, 7, fc=c, ec='#444', lw=0.3))
        ax.text(x + 4, y0 + 3.5, lab, ha='center', va='center', fontsize=4,
                color='#fff' if lab in ('2', '4', '6', '7', '8', '9', 'grey') else '#333')


def new_page():
    fig = plt.figure(figsize=(A4W / 25.4, A4H / 25.4))
    ax = fig.add_axes([0, 0, 1, 1]); ax.set_xlim(0, A4W); ax.set_ylim(0, A4H); ax.axis('off')
    return fig, ax


def page_calibration(pdf, out_png):
    SW, SH = 220.0, 160.0
    X0, Y0 = (A4W - SW) / 2, (A4H - SH) / 2
    fig, ax = new_page()
    ax.add_patch(Rectangle((X0, Y0), SW, SH, fc='none', ec='#888', lw=0.4, ls=(0, (2, 2))))
    fx, fy = X0 + 10, Y0 + 10
    ax.add_patch(Rectangle((fx, fy), 200, 140, fc=FIELD_GREY, ec='#2c7fb8', lw=0.6))
    for i in range(1, 20):
        ax.plot([fx + 10 * i] * 2, [fy, fy + 140], color='#989898', lw=0.3)
    for j in range(1, 14):
        ax.plot([fx, fx + 200], [fy + 10 * j] * 2, color='#989898', lw=0.3)
    # two 20 cm tracks for rod "trains", marks at 5, 10, 15
    for ty in (fy + 100, fy + 60):
        ax.add_patch(Rectangle((fx, ty), 200, 10, fc='none', ec='#7a7a7a', lw=0.5))
        for k in (5, 10, 15):
            ax.plot([fx + 10 * k] * 2, [ty - 2, ty], color='#555', lw=0.8 if k == 10 else 0.5)
            ax.text(fx + 10 * k, ty - 4, str(k), fontsize=5, ha='center', color='#555')
    ax.text(fx + 2, fy + 132, 'Положите палочки на поле; дорожки — для «поездов» до 20', fontsize=5, color='#444')
    ax.text(fx + 2, fy + 3, 'GoAbacUs · калибровка v1 · лист 14', fontsize=4.5, color='#555')
    for mid, (x, y) in zip((0, 1, 2, 3), [(X0 + 1, Y0 + SH - 9), (X0 + SW - 9, Y0 + SH - 9),
                                          (X0 + SW - 9, Y0 + 1), (X0 + 1, Y0 + 1)]):
        marker(ax, mid, x, y)
    marker(ax, 14, X0 + SW - 19, Y0 + SH - 9)
    strip(ax, X0 + 14, Y0 + 1.5)
    ax.text(X0 + 12, Y0 + SH - 5, 'Калибровка и палочки', fontsize=7, va='center', color='#333')
    ax.text(X0 + SW / 2, Y0 - 4, 'GoAbacUs · печать 100 %, без масштабирования · отрезать по пунктиру (220 × 160 мм) не обязательно',
            ha='center', fontsize=5.5, color='#666')
    ruler(ax, X0 + 20, Y0 - 9)
    pdf.savefig(fig); fig.savefig(out_png, dpi=DPI); plt.close(fig)


def page_abacus(pdf, out_png):
    # mat = whole printable area: markers 8 mm at 12 mm from the page edges
    m = 12.0
    fig, ax = new_page()
    W, H = A4W - 2 * m, A4H - 2 * m          # 273 x 186 between outer marker corners
    X0, Y0 = m, m
    ax.add_patch(Rectangle((X0 + 10, Y0 + 10), W - 20, H - 20, fc=FIELD_GREY, ec='#2c7fb8', lw=0.6))
    for mid, (x, y) in zip((0, 1, 2, 3), [(X0 + 1, Y0 + H - 9), (X0 + W - 9, Y0 + H - 9),
                                          (X0 + W - 9, Y0 + 1), (X0 + 1, Y0 + 1)]):
        marker(ax, mid, x, y)
    marker(ax, 15, X0 + W - 19, Y0 + H - 9)
    strip(ax, X0 + 14, Y0 + 1.5)
    ax.text(X0 + 12, Y0 + H - 5, 'Коврик для счётов · лист 15', fontsize=7, va='center', color='#333')
    ax.text(A4W / 2, A4H / 2, 'Положите счёты сюда.\nПроволоки — слева направо, вдоль длинной стороны.\n'
            'Метки по углам не закрывать.', ha='center', va='center', fontsize=9, color='#888', zorder=3)
    ax.text(A4W / 2, 4, 'GoAbacUs · печать 100 % · поле 253 × 166 мм', ha='center', fontsize=5.5, color='#666')
    pdf.savefig(fig); fig.savefig(out_png, dpi=DPI); plt.close(fig)


if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else '.'
    if len(sys.argv) > 2:
        DPI = int(sys.argv[2])
    with PdfPages(f'{out}/calibration-sheets.pdf') as pdf:
        page_calibration(pdf, f'{out}/calibration.png')
        page_abacus(pdf, f'{out}/abacus-mat.png')
    print('ok')
