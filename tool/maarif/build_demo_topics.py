#!/usr/bin/env python3
"""supabase/seed_maarif_topics.sql'den demo konu listesini üretir (lib/dev/demo_maarif_topics.dart).

Demo çevrimdışı çalışır; Maarif kataloğunun tamamını (gerçek MEB konuları) bellekte taşır.
Kullanım:  python tool/maarif/build_demo_topics.py   (seed değişince yeniden çalıştırın)
"""
import io
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SEED = ROOT / "supabase" / "seed_maarif_topics.sql"
OUT = ROOT / "lib" / "dev" / "demo_maarif_topics.dart"

BS = chr(92)  # ters bölü
APO = chr(39)  # tek tırnak

s = io.open(SEED, encoding="utf-8").read()
rows = re.findall(r"\('([A-Z_0-9]+)', (\d+)::smallint, (\d+), '((?:[^']|'')*)', '((?:[^']|'')*)', ", s)


def lit(sql_text: str) -> str:
    """SQL metnini ('' -> ') çözüp Dart tek tırnaklı dizgisine çevirir."""
    t = sql_text.replace(APO + APO, APO)
    t = t.replace(BS, BS + BS).replace(APO, BS + APO).replace("$", BS + "$")
    return APO + t + APO


out = [
    "// ÜRETİLDİ: python tool/maarif/build_demo_topics.py — elle düzenlenmez.",
    "// Kaynak: supabase/seed_maarif_topics.sql (MEB TYMM konuları, NOTLAR §104); demoda tam katalog.",
    "// (ders, sınıf, sıra, tema, konu)",
    "const demoMaarifTopics = <(String, int, int, String, String)>[",
]
for code, grade, sort, name, grp in rows:
    out.append(f"  ({lit(code)}, {grade}, {sort}, {lit(grp)}, {lit(name)}),")
out.append("];")
io.open(OUT, "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
print(f"{len(rows)} konu -> {OUT.relative_to(ROOT)}")
