#!/usr/bin/env python3
"""生成「驰马时记」的启动图标（含 Android 自适应图标分层）。

用法：
    python tool/gen_icons.py            # 生成全部图标
    python tool/gen_icons.py --preview   # 额外输出裁切 / 安全区验证图

图形：品牌蓝渐变 #1E88E5 → #0D47A1 + 白色钟形圆环 + 环内 ¥（时间 × 工钱）。
      环沿用旧图标的钟面语言（等粗圆环），中心 ¥ 直接说「算工钱」。

尺寸口径（全部按 108dp 自适应画布计算）：
    - 安全区直径 66dp（Android 规范）是**上限**：任何图形不得超出，否则圆/圆角方遮罩会切边；
    - 但系统渲染时只显示画布中间 72dp（实测：环 154px / 图标 173px = 89.6%，
      即 64dp 的环在桌面上占可见区 89%，四边只剩 4dp，明显顶边）；
    - 因此环外沿取 54dp = 可见区 72dp 的 75%，桌面留白 12.5%，仍在 66dp 安全区内（余 6dp）；
    - 环宽 4.4dp → 环内半径 22.6dp；环内留白取环内半径的 36.1%（8.2dp），
      ¥ 高 = 2 × (22.6 - 8.2) = 28.9dp，与旧稿 11.4 / 27.4 ≈ 41.6% 同一比例区间，
      收一点是为了 48px 下 ¥ 笔画不糊。

产出：
    android/app/src/main/res/mipmap-*/ic_launcher.png            传统图标（圆角方块）
    android/app/src/main/res/mipmap-*/ic_launcher_background.png 自适应背景层（渐变，全出血）
    android/app/src/main/res/mipmap-*/ic_launcher_foreground.png 自适应前景层（环 + ¥，含安全区）
    store/icon-512.png                                          512×512 商店图标（不透明）
"""

import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
STORE = os.path.join(ROOT, "store")

BRAND_TOP = (30, 136, 229)    # #1E88E5，与 App 主色一致
BRAND_BOTTOM = (13, 71, 161)  # #0D47A1
WHITE = (255, 255, 255, 255)

# 传统图标：48 72 96 144 192；自适应层：108 162 216 324 432
DENSITIES = {
    "mdpi": (48, 108),
    "hdpi": (72, 162),
    "xhdpi": (96, 216),
    "xxhdpi": (144, 324),
    "xxxhdpi": (192, 432),
}

SS = 4  # 超采样倍数

# ——— 108dp 画布上的几何（改这里就能整体调整） ———
CANVAS_DP = 108.0
SAFE_DP = 66.0                       # 安全区直径：硬上限
RING_OUT_R = 27.0                    # 环外沿半径：环径 54dp = 可见区 72dp 的 75%
RING_W = 4.4                         # 环宽
RING_IN_R = RING_OUT_R - RING_W      # 22.6：环内半径
GAP_RATIO = 0.361                    # 环与 ¥ 的留白 = 环内半径 × 36.1%（8.2dp）
YUAN_H = 2 * (RING_IN_R - RING_IN_R * GAP_RATIO)  # 28.9：¥ 总高
YUAN_STEM = YUAN_H * 0.125           # 3.61：¥ 笔画宽（约为环宽的 0.82）
YUAN_SHIFT_Y = 0.34                  # 视觉居中：¥ 略下移
LEGACY_SCALE = 1.2                   # 传统图标/商店图不裁 72dp，图形放大 1.2 倍


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient(size, radius_frac=0.0, alpha=True):
    """竖向品牌渐变；radius_frac > 0 时裁成圆角方块。"""
    grad = Image.new("RGB", (1, size))
    for y in range(size):
        grad.putpixel((0, y), lerp(BRAND_TOP, BRAND_BOTTOM, y / max(size - 1, 1)))
    grad = grad.resize((size, size), Image.BICUBIC)
    if not alpha:
        return grad
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    if radius_frac <= 0:
        out.paste(grad, (0, 0))
        return out
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, size - 1, size - 1], radius=int(size * radius_frac), fill=255
    )
    out.paste(grad, (0, 0), mask)
    return out


def _rline(d, p0, p1, w):
    """圆头线段：先画线再补两端圆点，避免方头。"""
    d.line([p0, p1], fill=WHITE, width=max(1, int(round(w))))
    r = w / 2.0
    for (x, y) in (p0, p1):
        d.ellipse([x - r, y - r, x + r, y + r], fill=WHITE)


def draw_mark(size, dp_scale=CANVAS_DP, scale=1.0):
    """前景图形：白色圆环 + 环内 ¥。

    size    画布像素；
    dp_scale 画布对应 dp 数（自适应层 108，传统图标同口径）；
    scale   整体缩放（传统图标放大 1.2，因为不会被裁掉外圈 18dp）。
    """
    s = size * SS
    k = s / dp_scale * scale             # 1dp → k 像素
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = cy = s / 2

    # —— 圆环（钟面） ——
    R = RING_OUT_R * k
    w = RING_W * k
    d.ellipse([cx - R, cy - R, cx + R, cy + R], outline=WHITE,
              width=max(1, int(round(w))))

    # —— 环内 ¥ ——
    h = YUAN_H * k
    yc = cy + YUAN_SHIFT_Y * k
    y_top = yc - h * 0.47
    y_fork = yc - h * 0.08
    y_bot = yc + h * 0.47
    dx = h * 0.31
    stem = YUAN_STEM * k

    _rline(d, (cx, y_fork), (cx - dx, y_top), stem)
    _rline(d, (cx, y_fork), (cx + dx, y_top), stem)
    _rline(d, (cx, y_fork), (cx, y_bot), stem)

    bw = dx * 2.1
    bh = h * 0.078
    for yy in (yc + h * 0.02, yc + h * 0.21):
        d.rounded_rectangle(
            [cx - bw / 2, yy - bh / 2, cx + bw / 2, yy + bh / 2],
            radius=bh / 2,
            fill=WHITE,
        )

    return img.resize((size, size), Image.LANCZOS)


def compose_legacy(size):
    """传统图标：圆角方块 + 环内 ¥（不裁 72dp，图形放大 1.2 倍）。"""
    base = gradient(size, radius_frac=0.22)
    base.alpha_composite(draw_mark(size, scale=LEGACY_SCALE))
    return base


def device_view(cell):
    """按系统真实渲染模拟：108dp 画布只取中间 72dp，再缩放到图标尺寸。"""
    big = int(cell * CANVAS_DP / 72.0)
    canvas = gradient(big).convert("RGBA")
    canvas.alpha_composite(draw_mark(big))
    pad = int(round(big * 18.0 / CANVAS_DP))
    view = canvas.crop((pad, pad, big - pad, big - pad))
    return view.resize((cell, cell), Image.LANCZOS)


def _font(size=18):
    """预览图用的中文字体；找不到就退回默认字体（只是标签，不影响图标）。"""
    from PIL import ImageFont
    for path in (r"C:\Windows\Fonts\msyhbd.ttc", r"C:\Windows\Fonts\msyh.ttc"):
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def mask_sheet(out_path, cell=220):
    """按真机口径（可见区 72dp）预览三种蒙版 + 安全区参考线 + 小尺寸可读性。"""
    f = _font(18)
    circle = Image.new("L", (cell, cell), 0)
    ImageDraw.Draw(circle).ellipse([0, 0, cell - 1, cell - 1], fill=255)
    squircle = Image.new("L", (cell, cell), 0)
    ImageDraw.Draw(squircle).rounded_rectangle(
        [0, 0, cell - 1, cell - 1], radius=int(cell * 0.22), fill=255
    )
    square = Image.new("L", (cell, cell), 255)

    cols = [("圆", circle), ("圆角方", squircle), ("方形", square)]
    pad = 18
    W = (len(cols) + 1) * cell + (len(cols) + 2) * pad
    H = cell + 52
    sh = Image.new("RGB", (W, H), (245, 246, 248))
    d = ImageDraw.Draw(sh)

    for i, (name, m) in enumerate(cols):
        canvas = device_view(cell)
        masked = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
        masked.paste(canvas, (0, 0))
        masked.putalpha(m)
        x = pad + i * (cell + pad)
        sh.paste(masked, (x, 34), masked)
        d.text((x, 10), name, font=f, fill=(60, 60, 60))

    # 最后一列：可见区里同时画安全区（黄圈）与环外沿（红圈）
    canvas = device_view(cell)
    dd = ImageDraw.Draw(canvas)
    r_safe = cell * (SAFE_DP / 2) / 72.0
    dd.ellipse(
        [cell / 2 - r_safe, cell / 2 - r_safe, cell / 2 + r_safe, cell / 2 + r_safe],
        outline=(255, 214, 0, 255), width=3,
    )
    r_ring = cell * RING_OUT_R / 72.0
    dd.ellipse(
        [cell / 2 - r_ring, cell / 2 - r_ring, cell / 2 + r_ring, cell / 2 + r_ring],
        outline=(255, 0, 0, 255), width=1,
    )
    x = pad + len(cols) * (cell + pad)
    sh.paste(canvas, (x, 34))
    d.text((x, 10), "安全区 66dp / 可见 72dp", font=f, fill=(60, 60, 60))

    # 底部补一排真实尺寸，检查缩小后是否还认得出
    row_h = 96 * 2
    out = Image.new("RGB", (W, H + row_h + 56), (245, 246, 248))
    out.paste(sh, (0, 0))
    d2 = ImageDraw.Draw(out)
    for i, sz in enumerate((96, 72, 48)):
        im = compose_legacy(sz).resize((sz * 2, sz * 2), Image.NEAREST)
        x = pad + i * (96 * 2 + pad)
        out.paste(im, (x, H + 32), im)
        d2.text((x, H + 6), f"{sz}px", font=f, fill=(60, 60, 60))

    out.save(out_path)
    return out_path


def check_safe_area(size=432):
    """前景层像素级校验：所有不透明像素到中心距离必须 ≤ 安全区半径。"""
    img = draw_mark(size).convert("RGBA")
    px = img.load()
    cx = cy = size / 2
    limit = size * (SAFE_DP / 2) / CANVAS_DP
    worst = 0.0
    for y in range(size):
        for x in range(size):
            if px[x, y][3] > 8:
                dx, dy = x + 0.5 - cx, y + 0.5 - cy
                worst = max(worst, (dx * dx + dy * dy) ** 0.5)
    return worst, limit


def main():
    os.makedirs(STORE, exist_ok=True)
    worst, limit = check_safe_area(432)
    print(f"安全区校验：图形最远点 {worst:.2f}px / 上限 {limit:.2f}px "
          f"（{'通过' if worst <= limit else '超界'}）")
    if worst > limit:
        raise SystemExit("图形超出 66/108 安全区，拒绝生成")

    for density, (legacy, adaptive) in DENSITIES.items():
        out_dir = os.path.join(RES, f"mipmap-{density}")
        os.makedirs(out_dir, exist_ok=True)
        compose_legacy(legacy).save(os.path.join(out_dir, "ic_launcher.png"))
        gradient(adaptive).save(os.path.join(out_dir, "ic_launcher_background.png"))
        draw_mark(adaptive).save(os.path.join(out_dir, "ic_launcher_foreground.png"))
        print(f"mipmap-{density}: legacy {legacy}px, adaptive {adaptive}px")

    # 512 商店图标：不透明全出血方形，Play / 应用市场自行加圆角蒙版
    store = gradient(512, alpha=False).convert("RGBA")
    store.alpha_composite(draw_mark(512))
    store.convert("RGB").save(os.path.join(STORE, "icon-512.png"))
    print("store/icon-512.png")

    if "--preview" in sys.argv:
        out = os.path.join(ROOT, "build", "icon-preview.png")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        mask_sheet(out)
        print(out)


if __name__ == "__main__":
    main()
