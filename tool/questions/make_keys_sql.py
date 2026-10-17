"""Düello cevap anahtarını (practice_keys) soru havuzundan üretip
20261018230000_duels.sql migration'ının sonuna yazar.

    python tool/questions/make_keys_sql.py

Havuz yeniden üretilirse bu da çalıştırılmalı; supabase/tests/duels_test.mjs
anahtarın havuzla aynı olduğunu denetler.
"""
import glob
import json
import os
import sys

ROOT = os.path.join(os.path.dirname(__file__), '..', '..')
MIGRATION = os.path.join(ROOT, 'supabase', 'migrations', '20261018230000_duels.sql')
MARKER = '-- python tool/questions/make_keys_sql.py)\n'


def main():
    rows = []
    for path in sorted(glob.glob(os.path.join(ROOT, 'assets', 'learn', 'questions', '*.json'))):
        with open(path, encoding='utf-8') as f:
            rows += [(q['id'], q['a']) for q in json.load(f)]
    lines = []
    for i in range(0, len(rows), 400):
        chunk = rows[i:i + 400]
        lines.append('insert into public.practice_keys (question_id, answer) values\n' +
                     ',\n'.join(f"('{q}',{a})" for q, a in chunk) + ';')
    with open(MIGRATION, encoding='utf-8') as f:
        text = f.read()
    head = text[:text.index(MARKER) + len(MARKER)]
    with open(MIGRATION, 'w', encoding='utf-8', newline='\n') as f:
        f.write(head + '\n'.join(lines) + '\n')
    print(f'{len(rows)} anahtar yazıldı')


if __name__ == '__main__':
    sys.exit(main())
