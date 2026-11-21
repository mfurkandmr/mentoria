#!/usr/bin/env python3
"""MEB TYMM verisinden (tool/maarif/data/*.json) supabase/seed_maarif_topics.sql üretir.

Veri kaynağı: https://tymm.meb.gov.tr (Türkiye Yüzyılı Maarif Modeli öğretim
programları). Konu = programın "İçerik Çerçevesi" maddesi; grup = tema/ünite.
Hiçbir madde uydurulmaz; kaynakta olmayan (yok) sınıf/ders atlanır.

Kullanım:  python tool/maarif/build_seed.py
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "tool" / "maarif" / "data"
OUT = ROOT / "supabase" / "seed_maarif_topics.sql"

# Dosya → uygulamadaki ders kodu. 9-11'de TYT / AYT ayrımı yok (NOTLAR §91);
# her ders için tek kod kullanılır. Edebiyat, uygulamadaki "Edebiyat" dersine
# (AYT_EDB) bağlanır.
SUBJECT = {
    "matematik": "TYT_MAT",
    "fizik": "TYT_FIZ",
    "kimya": "TYT_KIM",
    "biyoloji": "TYT_BIY",
    "tarih": "TYT_TAR",
    "cografya": "TYT_COG",
    "felsefe": "TYT_FEL",
    "din": "TYT_DIN",
    "edebiyat": "AYT_EDB",
}


def clean_group(name: str) -> str:
    """'1. Tema: Sözün İnceliği' / '1. Ünite : X' → 'Sözün İnceliği'."""
    return re.sub(r"^\s*\d+\.\s*(Tema|Ünite)\s*:\s*", "", name).strip()


def clean_topic(text: str) -> str:
    """'Yaşam Bilimi: Biyoloji: …' / 'Çevre Etiği (…)' → kısa başlık."""
    t = text.split(":")[0]
    t = t.split("(")[0]
    t = re.sub(r"\s+", " ", t).strip(" -–•")
    return t[:120]


def q(s: str) -> str:
    return "'" + s.replace("'", "''") + "'"


rows = []  # (subject, grade, sort, name, group, url)
for key, code in SUBJECT.items():
    d = json.loads((DATA / f"{key}.json").read_text(encoding="utf-8"))
    for sn in d["siniflar"]:
        grade = sn["sinif"]
        if not isinstance(grade, int) or not 9 <= grade <= 12:
            continue  # Hazırlık sınıfı programı dışarıda
        temas = sn.get("temalar") or []
        seen = {}
        for ti, tema in enumerate(temas):
            group = clean_group(tema["ad"])
            items = tema.get("icerik_cercevesi") or tema.get("icerik_basliklari") or []
            for ii, raw in enumerate(items):
                name = clean_topic(raw)
                if not name:
                    continue
                seen.setdefault(name, []).append((ti, ii, group, tema.get("unite_url")))
        for name, occ in seen.items():
            for ti, ii, group, url in occ:
                # Aynı ad bir derste birden çok temada geçiyorsa (örn. edebiyatta
                # "Okuma") tema adı öne eklenir.
                final = name if len(occ) == 1 else f"{group} · {name}"
                rows.append((code, grade, ti * 100 + ii + 1, final[:160], group, url))

# Yinelenen (ders, sınıf, ad) kalmasın.
uniq = {}
for r in rows:
    uniq.setdefault((r[0], r[1], r[3]), r)
rows = sorted(uniq.values(), key=lambda r: (r[0], r[1], r[2]))

lines = [
    "-- Türkiye Yüzyılı Maarif Modeli konu kataloğu (NOTLAR §104).",
    "-- ÜRETİLDİ: python tool/maarif/build_seed.py — elle düzenlenmez.",
    "-- Kaynak: https://tymm.meb.gov.tr (MEB Talim ve Terbiye Kurulu öğretim programları,",
    "-- 'İçerik Çerçevesi' maddeleri; grup = tema/ünite). Veri: tool/maarif/data/*.json.",
    "-- Tekrar çalıştırılabilir (aynı ders/sınıf/ad varsa atlar).",
    "",
    "insert into public.topics (subject_id, name, sort, curriculum, grade, group_name, source_url)",
    "select s.id, v.name, v.sort, 'maarif', v.grade, v.grp, v.url",
    "from (values",
]
vals = []
for code, grade, sort, name, group, url in rows:
    vals.append(
        f"  ({q(code)}, {grade}::smallint, {sort}, {q(name)}, {q(group)}, {q(url) if url else 'null'})"
    )
lines.append(",\n".join(vals))
lines += [
    ") as v (code, grade, sort, name, grp, url)",
    "join public.subjects s on s.code = v.code",
    "on conflict (subject_id, grade, name) where curriculum = 'maarif' do nothing;",
    "",
]
OUT.write_text("\n".join(lines), encoding="utf-8", newline="\n")
print(f"{len(rows)} konu → {OUT.relative_to(ROOT)}")
by = {}
for r in rows:
    by[(r[0], r[1])] = by.get((r[0], r[1]), 0) + 1
for k in sorted(by):
    print(k, by[k])
