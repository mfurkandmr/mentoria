"""Uygulamanın kullandığı Google Fonts dosyalarını indirip assets/google_fonts/
altına koyar. Böylece uygulama yazı tiplerini çalışırken Google'dan
indirmez (KVKK: kullanıcının IP adresi Google'a gitmez; çevrimdışı da çalışır).

Adresler ve SHA-256 özetleri google_fonts paketinin kendi listesinden okunur;
indirilen her dosya bu özetle doğrulanır. google_fonts sürümü değişirse ya da
lib/core/theme/app_fonts.dart'a yazı tipi eklenirse yeniden çalıştır:

    python tool/fonts/fetch_fonts.py
"""

from __future__ import annotations

import hashlib
import os
import pathlib
import re
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "google_fonts"

# app_fonts.dart'taki GoogleFonts fonksiyonları.
FAMILIES = [
    "nunito", "poppins", "merriweather", "playfairDisplay", "robotoSlab",
    "oswald", "baloo2", "patrickHand", "spaceMono", "exo2",
]
# Uygulamada kullanılan kalınlıklar (FontWeight.w400 … w900).
WEIGHTS = [400, 500, 600, 700, 800, 900]
# Eğik yazı yalnızca varsayılan yazı tipinde (KVKK metinleri vb.).
ITALIC_FAMILIES = {"nunito"}

NAMES = {100: "Thin", 200: "ExtraLight", 300: "Light", 400: "Regular",
         500: "Medium", 600: "SemiBold", 700: "Bold", 800: "ExtraBold",
         900: "Black"}


def package_dir() -> pathlib.Path:
    lock = (ROOT / "pubspec.lock").read_text(encoding="utf-8")
    m = re.search(r"google_fonts:\n(?:.*\n)*?\s+version: \"([^\"]+)\"", lock)
    if not m:
        sys.exit("pubspec.lock'ta google_fonts bulunamadı")
    cache = pathlib.Path(os.environ.get("PUB_CACHE")
                         or pathlib.Path(os.environ["LOCALAPPDATA"]) / "Pub" / "Cache")
    return cache / "hosted" / "pub.dev" / f"google_fonts-{m.group(1)}" / "lib" / "src"


def variants(src: str, func: str) -> tuple[str, list[tuple[int, bool, str, int]]]:
    start = src.index(f"static TextStyle {func}(")
    body = src[start:src.index("return googleFontsTextStyle(", start) + 400]
    family = re.search(r"fontFamily: '([^']+)'", body).group(1)
    found = re.findall(
        r"fontWeight: FontWeight\.w(\d+),\s*fontStyle: FontStyle\.(normal|italic),\s*"
        r"\): GoogleFontsFile\(\s*'([0-9a-f]{64})',\s*(\d+),",
        body,
    )
    return family, [(int(w), s == "italic", h, int(n)) for w, s, h, n in found]


def main() -> None:
    parts = package_dir() / "google_fonts_parts"
    src = "".join(p.read_text(encoding="utf-8") for p in sorted(parts.glob("*.dart")))
    OUT.mkdir(parents=True, exist_ok=True)
    total = 0
    for func in FAMILIES:
        family, vs = variants(src, func)
        for weight, italic, digest, size in vs:
            if weight not in WEIGHTS or (italic and func not in ITALIC_FAMILIES):
                continue
            name = NAMES[weight]
            if italic:
                name = "Italic" if weight == 400 else f"{name}Italic"
            target = OUT / f"{family}-{name}.ttf"
            if target.exists() and hashlib.sha256(target.read_bytes()).hexdigest() == digest:
                total += size
                continue
            url = f"https://fonts.gstatic.com/s/a/{digest}.ttf"
            data = urllib.request.urlopen(url, timeout=60).read()
            if len(data) != size or hashlib.sha256(data).hexdigest() != digest:
                sys.exit(f"{target.name}: boyut ya da özet tutmadı, dosya yazılmadı")
            target.write_bytes(data)
            total += size
            print(f"{target.name}  {size // 1024} KB")
    print(f"Toplam {total / 1024 / 1024:.1f} MB: {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
