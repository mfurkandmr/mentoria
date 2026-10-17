"""Eğitim bölümünün soru havuzunu üretir (telifsiz, bu depoda özgün).

    python tool/questions/make_questions.py assets/learn/questions

Havuz büyüklüğü = günlük hak × 30: Türkçe ve Matematik 20 × 30 = 600, diğer
TYT dersleri 10 × 30 = 300. Üretim sabit tohumla yapılır; her çalıştırmada
aynı sorular çıkar (soru kimlikleri değişmez, öğrencinin geçmişi bozulmaz).
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))

import biy  # noqa: E402
import cog  # noqa: E402
import din  # noqa: E402
import fel  # noqa: E402
import fiz  # noqa: E402
import kim  # noqa: E402
import mat  # noqa: E402
import tar  # noqa: E402
import tur  # noqa: E402
from common import build  # noqa: E402

DAILY = {'TYT_TUR': 20, 'TYT_MAT': 20}
MODULES = [tur, mat, fiz, kim, biy, tar, cog, fel, din]


def validate(code, items):
    for it in items:
        o = it['o']
        assert len(o) == 5, (code, it)
        assert len(set(o)) == 5, (code, 'tekrarlı şık', it)
        assert all(isinstance(x, str) and x.strip() for x in o), (code, it)
        assert 0 <= it['a'] < 5, (code, it)
        assert it['q'].strip() and it['e'].strip(), (code, it)


def main(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    summary = {}
    for i, m in enumerate(MODULES):
        code = m.T
        target = DAILY.get(code, 10) * 30
        items = build(code, target, m.GENERATORS, seed=20261017 + i)
        validate(code, items)
        with open(os.path.join(out_dir, f'{code}.json'), 'w', encoding='utf-8', newline='\n') as f:
            json.dump(items, f, ensure_ascii=False, separators=(',', ':'))
        topics = {}
        for it in items:
            topics[it['t']] = topics.get(it['t'], 0) + 1
        summary[code] = (len(items), len(topics))
    for code, (n, t) in summary.items():
        print(f'{code}: {n} soru, {t} konu')
    print('toplam', sum(n for n, _ in summary.values()))


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'assets/learn/questions')
