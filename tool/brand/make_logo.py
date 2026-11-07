"""Mentoria logosu (lacivert kare, beyaz M, turuncu çizgi) -> bütün ikonlar.

Kaynak: kullanıcının verdiği logo görseli ölçülüp vektöre çevrildi (köşe
siyahlıkları yok, her boyutta net). Çıktılar:

  assets/brand/logo.svg                 uygulama içi (flutter_svg)
  assets/brand/icon/app_icon.png        1024, köşesiz (iOS/Android kendisi yuvarlar)
  assets/brand/icon/store_icon.png      1024, köşesiz
  assets/brand/icon/adaptive_foreground.png  Android uyarlanır ikon ön yüzü
  web/favicon.png, web/icons/Icon-*.png (yuvarlak köşeli + maskable)

  python tool/brand/make_logo.py && dart run flutter_launcher_icons
"""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
NAVY = "#122B4B"
ORANGE = "#F5A623"
WHITE = "#FFFFFF"

# 512'lik kutuda ölçüler (kaynak görselden: kare 224 px, ölçek 512/224).
_S = 512 / 224


def _pt(x: float, y: float) -> tuple[float, float]:
    return ((x - 6) * _S, (y + 4) * _S)


M = [_pt(*p) for p in [
    (50, 157), (50, 39), (83, 39), (118, 85), (153, 39), (186, 39),
    (186, 157), (158, 157), (158, 89), (118, 139), (78, 89), (78, 157),
]]
BAR = (*_pt(50, 165), *_pt(186, 179))  # x0, y0, x1, y1 (uçları yuvarlak)
RADIUS = 50 * _S  # köşe yarıçapı (%22)


def svg() -> str:
    pts = " ".join(f"{x:.1f},{y:.1f}" for x, y in M)
    x0, y0, x1, y1 = BAR
    h = y1 - y0
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">\n'
        f'  <rect width="512" height="512" rx="{RADIUS:.1f}" fill="{NAVY}"/>\n'
        f'  <polygon points="{pts}" fill="{WHITE}"/>\n'
        f'  <rect x="{x0:.1f}" y="{y0:.1f}" width="{x1 - x0:.1f}" '
        f'height="{h:.1f}" rx="{h / 2:.1f}" fill="{ORANGE}"/>\n'
        "</svg>\n"
    )


def render(size: int, *, rounded: bool, mark_scale: float = 1.0,
           background: bool = True) -> Image.Image:
    """[mark_scale] < 1: M ve çizgi ortada küçülür (maskable güvenli alanı)."""
    k = 4  # kenar yumuşatma için büyük çizip küçült
    big = size * k
    f = big / 512
    im = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    if background:
        if rounded:
            d.rounded_rectangle((0, 0, big - 1, big - 1), RADIUS * f, fill=NAVY)
        else:
            d.rectangle((0, 0, big, big), fill=NAVY)

    def tr(x: float, y: float) -> tuple[float, float]:
        c = 256
        return ((c + (x - c) * mark_scale) * f, (c + (y - c) * mark_scale) * f)

    d.polygon([tr(x, y) for x, y in M], fill=WHITE)
    x0, y0 = tr(BAR[0], BAR[1])
    x1, y1 = tr(BAR[2], BAR[3])
    d.rounded_rectangle((x0, y0, x1, y1), (y1 - y0) / 2, fill=ORANGE)
    return im.resize((size, size), Image.LANCZOS)


def main() -> None:
    (ROOT / "assets/brand/logo.svg").write_text(svg(), encoding="utf-8")
    icon = ROOT / "assets/brand/icon"
    render(1024, rounded=False).convert("RGB").save(icon / "app_icon.png")
    render(1024, rounded=False).convert("RGB").save(icon / "store_icon.png")
    # Android uyarlanır ikon: zemin rengi pubspec'te; ön yüz güvenli alanda.
    render(1024, rounded=False, mark_scale=0.62, background=False).save(
        icon / "adaptive_foreground.png")
    web = ROOT / "web"
    render(64, rounded=True).save(web / "favicon.png")
    for n in (192, 512):
        render(n, rounded=True).save(web / "icons" / f"Icon-{n}.png")
        render(n, rounded=False, mark_scale=0.78).save(
            web / "icons" / f"Icon-maskable-{n}.png")
    print("logo üretildi")


if __name__ == "__main__":
    main()
