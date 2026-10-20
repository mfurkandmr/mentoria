"""docs/kvkk taslaklarından uygulamada gösterilecek KVKK metinlerini üretir.

Avukata yönelik notlar (">" ile başlayan satırlar), "Uygulamadaki görünüm"
bölümü ve yalnızca avukat kararına bağlı maddeler çıkarılır; sonuç
assets/legal/*.md olur. Metin değişince:

    python tool/legal/build_legal.py

ve `lib/features/privacy/data/consent_repository.dart` içindeki
`legalVersion`'ı artır (kullanıcılardan yeniden onay istenir).
"""

from __future__ import annotations

import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / "docs" / "kvkk"
OUT = ROOT / "assets" / "legal"

DOCS = {
    "aydinlatma.md": "02_aydinlatma_metni.md",
    "acik_riza.md": "03_acik_riza_metni.md",
    "veli_onay.md": "04_veli_onay_metni.md",
    "gizlilik.md": "05_gizlilik_politikasi.md",
    "kullanim_kosullari.md": "08_kullanim_kosullari.md",
}

# Bu başlıkla başlayan bölümler (bir sonraki aynı/üst düzey başlığa kadar)
# uygulamada gösterilmez.
DROP_SECTIONS = (
    "## Uygulamadaki görünüm",
    "### ☐ 3. Yurt dışına aktarım",
    "## Mağaza formları için özet",
)


def clean(text: str) -> str:
    out: list[str] = []
    dropping: int | None = None  # düşürülen bölümün başlık düzeyi
    for line in text.splitlines():
        heading = re.match(r"^(#+) ", line)
        if heading:
            level = len(heading.group(1))
            if dropping is not None and level <= dropping:
                dropping = None
            if any(line.startswith(d) for d in DROP_SECTIONS):
                dropping = level
                continue
        if dropping is not None:
            continue
        if line.startswith(">"):
            continue
        # Başlıktaki "(taslak)" uygulamada görünmesin.
        line = line.replace(" (taslak)", "")
        out.append(line)
    # Art arda boş satırları ve baştaki/sondaki boşlukları sadeleştir.
    result = re.sub(r"\n{3,}", "\n\n", "\n".join(out)).strip() + "\n"
    # Ayırıcıyla başlayan/biten kalıntılar.
    result = re.sub(r"^---\n+", "", result)
    return re.sub(r"\n+---\n$", "\n", result)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, src in DOCS.items():
        text = (SRC / src).read_text(encoding="utf-8")
        (OUT / name).write_text(clean(text), encoding="utf-8", newline="\n")
        print(f"assets/legal/{name}")


if __name__ == "__main__":
    main()
