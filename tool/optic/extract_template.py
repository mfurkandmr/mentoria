"""Boş bir optik formun taramasından şablon iskeleti çıkarır.

Yayınevi / dershane formunu uygulamaya eklemek için: formun düz, tam
çözünürlüklü taraması ya da PDF'ten alınmış resmi verilir; araç

  * hizalama işaretlerini (dört köşe karesi ya da kenardaki zamanlama
    çubukları),
  * tüm baloncuk ızgaralarını (ilk baloncuğun yeri, şıklar ve satırlar
    arası mesafe, sütun ve satır sayısı)

bulur ve sayfa birimine (genişlik 1000) çevirir. Çıktılar:

  <çıktı>.json      bulunan her şey
  <çıktı>.dart      `OpticTemplate` iskeleti (ızgaraların dersleri elle
                    yazılır: `subjects: ['TODO']`)
  <çıktı>.png       kontrol resmi: baloncuklar yeşil, ızgaralar numaralı
                    kırmızı kutu, çubuklar mavi, köşe kareleri mor

Sonra şablon `lib/features/optic/data/omr/optic_template.dart`'taki
`opticTemplates` listesine eklenir ve dolu bir formun fotoğrafıyla denenir.

Kullanım:
  python tool/optic/extract_template.py bos_form.png [--out build/sablon]
      [--threshold 12]

Gerekenler: Python 3, numpy, opencv-python (`pip install numpy opencv-python`).
"""

import argparse
import json
import math
import sys
from pathlib import Path

import cv2
import numpy as np

PAGE_WIDTH = 1000.0


def load_gray(path, work_width=2000):
    image = cv2.imdecode(np.fromfile(path, dtype=np.uint8), cv2.IMREAD_COLOR)
    if image is None:
        sys.exit(f'Resim okunamadı: {path}')
    h, w = image.shape[:2]
    scale = work_width / w
    image = cv2.resize(image, (work_width, round(h * scale)),
                       interpolation=cv2.INTER_AREA)
    return image, cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)


def dark_mask(gray, threshold):
    """Yerel ortalamadan belirgin koyu pikseller (renkli / pembe baskı da)."""
    block = max(31, (gray.shape[1] // 40) | 1)
    return cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_MEAN_C,
                                 cv2.THRESH_BINARY_INV, block, threshold)


def components(mask):
    n, labels, stats, centroids = cv2.connectedComponentsWithStats(mask, 8)
    out = []
    for i in range(1, n):
        x, y, w, h, area = stats[i]
        out.append({
            'x': float(centroids[i][0]), 'y': float(centroids[i][1]),
            'w': int(w), 'h': int(h), 'area': int(area),
            'left': int(x), 'top': int(y),
            'solidity': area / float(w * h),
        })
    return out


def find_anchors(comps, width, height):
    squares = [c for c in comps
               if c['solidity'] > 0.85 and 0.7 < c['w'] / c['h'] < 1.4
               and c['w'] > width * 0.015]
    if len(squares) < 4:
        return None
    biggest = max(c['area'] for c in squares)
    squares = [c for c in squares if c['area'] > biggest * 0.35]
    picked = []
    for cx, cy in [(0, 0), (width, 0), (width, height), (0, height)]:
        rest = [c for c in squares if c not in picked]
        if not rest:
            return None
        picked.append(min(rest, key=lambda c: math.hypot(c['x'] - cx, c['y'] - cy)))
    return picked


def find_track(comps, width):
    """En çok çubuk içeren dikey sıra (benzer boyda, dolu, uzunca lekeler)."""
    bars = [c for c in comps
            if c['solidity'] > 0.75 and c['w'] > width * 0.006
            and 1.6 < max(c['w'], c['h']) / min(c['w'], c['h']) < 9]
    best = []
    for a in bars:
        same = [c for c in bars
                if abs(c['x'] - a['x']) < width * 0.006
                and 0.5 < c['area'] / a['area'] < 2]
        if len(same) > len(best):
            best = same
    if len(best) < 15:
        return None
    best.sort(key=lambda c: c['y'])
    gaps = np.diff([c['y'] for c in best])
    dy = float(np.median(gaps))
    # İlk ve son çubuk arasından eşit aralık (eksik çubuklar sayılır).
    count = int(round((best[-1]['y'] - best[0]['y']) / dy)) + 1
    dy = (best[-1]['y'] - best[0]['y']) / (count - 1)
    return {
        'x': float(np.mean([c['x'] for c in best])),
        'first_y': best[0]['y'], 'dy': dy, 'count': count,
        'bar_width': float(np.median([c['w'] for c in best])),
        'bar_height': float(np.median([c['h'] for c in best])),
        'found': len(best), 'items': best,
    }


def find_bubbles(comps, width, mask):
    """Boş baloncuk çerçeveleri: yuvarlak, içi boş halkalar."""
    out = []
    for c in comps:
        if not 0.75 < c['w'] / c['h'] < 1.33:
            continue
        if not width * 0.007 < c['w'] < width * 0.045:
            continue
        if not 0.05 < c['solidity'] < 0.65:
            continue
        # Dolu daireyi doluluk oranı eler; içindeki harf ayrı bir lekedir.
        # Yuvarlak olmalı: halkanın kutu köşeleri boştur; kare kutunun (ör.
        # numaranın üstündeki elle yazma kareleri) köşeleri doludur.
        k = max(1, int(min(c["w"], c["h"]) * 0.1))
        box = mask[c['top']:c['top'] + c['h'], c['left']:c['left'] + c['w']]
        corners = [box[:k, :k], box[:k, -k:], box[-k:, :k], box[-k:, -k:]]
        if max(q.mean() for q in corners) > 255 * 0.25:
            continue
        cx = c['left'] + c['w'] / 2.0
        cy = c['top'] + c['h'] / 2.0
        out.append({'x': cx, 'y': cy, 'r': (c['w'] + c['h']) / 4.0})
    # Aynı boydakiler (çoğunluk): harf "O" gibi rastlantıları ele.
    if out:
        median_r = float(np.median([b['r'] for b in out]))
        out = [b for b in out if 0.75 < b['r'] / median_r < 1.3]
    return out


def find_grids(bubbles):
    """Baloncukları komşuluğa göre ızgaralara ayırır."""
    if not bubbles:
        return []
    r = float(np.median([b['r'] for b in bubbles]))
    n = len(bubbles)
    xy = np.array([[b['x'], b['y']] for b in bubbles])
    parent = list(range(n))

    def root(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    for i in range(n):
        d = xy - xy[i]
        horiz = (np.abs(d[:, 1]) < r * 0.5) & (np.abs(d[:, 0]) < r * 3.4)
        vert = (np.abs(d[:, 0]) < r * 0.5) & (np.abs(d[:, 1]) < r * 3.6)
        for j in np.nonzero(horiz | vert)[0]:
            if j != i:
                parent[root(i)] = root(int(j))
    groups = {}
    for i in range(n):
        groups.setdefault(root(i), []).append(i)
    grids = []
    small = []
    for members in groups.values():
        if len(members) < 4:
            small.append([{'x': float(xy[i][0]), 'y': float(xy[i][1])} for i in members])
            continue
        pts = xy[members]
        xs = np.sort(np.unique(np.round(pts[:, 0] / (r * 0.5)))) * r * 0.5
        ys = np.sort(np.unique(np.round(pts[:, 1] / (r * 0.5)))) * r * 0.5
        dx = _spacing(pts[:, 0], r)
        dy = _spacing(pts[:, 1], r)
        x0, y0 = pts[:, 0].min(), pts[:, 1].min()
        cols = int(round((pts[:, 0].max() - x0) / dx)) + 1 if dx else 1
        rows = int(round((pts[:, 1].max() - y0) / dy)) + 1 if dy else 1
        grids.append({
            'x': float(x0), 'y': float(y0), 'dx': float(dx or 0),
            'dy': float(dy or 0), 'cols': cols, 'rows': rows,
            'bubbles': len(members), 'r': r,
        })
    grids.sort(key=lambda g: (round(g['y'] / (r * 20)), g['x']))
    return grids, small


def _spacing(values, r):
    """Bir eksendeki ardışık farklı konumlar arasındaki tipik aralık."""
    pos = np.sort(values)
    gaps = np.diff(pos)
    gaps = gaps[gaps > r * 0.8]
    return float(np.median(gaps)) if len(gaps) else 0.0


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('image')
    ap.add_argument('--out', default=None)
    ap.add_argument('--threshold', type=int, default=12,
                    help='koyu sayılma eşiği (yerel ortalamadan fark)')
    args = ap.parse_args()

    color, gray = load_gray(args.image)
    h, w = gray.shape
    k = PAGE_WIDTH / w
    mask = dark_mask(gray, args.threshold)
    comps = components(mask)
    # Köşe kareleri ve çubuklar siyah basılır; yerel eşikleme büyük dolu
    # karelerin içini boş gösterdiği için onlar düz bir eşikle aranır.
    solid = components(((gray < 110) * 255).astype(np.uint8))
    anchors = find_anchors(solid, w, h)
    track = find_track(solid, w)
    bubbles = find_bubbles(comps, w, mask)
    grids, small = find_grids(bubbles)

    def u(v):
        return round(v * k, 1)

    result = {
        'width': PAGE_WIDTH, 'height': u(h),
        'bubble_radius': u(float(np.median([b['r'] for b in bubbles]))) if bubbles else None,
        'anchors': [{'x': u(a['x']), 'y': u(a['y'])} for a in anchors] if anchors else None,
        'anchor_size': u(float(np.median([a['w'] for a in anchors]))) if anchors else None,
        'track': None if not track else {
            'x': u(track['x']), 'first_y': u(track['first_y']), 'dy': round(track['dy'] * k, 3),
            'count': track['count'], 'found': track['found'],
            'bar_width': u(track['bar_width']), 'bar_height': u(track['bar_height']),
        },
        'grids': [{
            'index': i + 1, 'x': u(g['x']), 'y': u(g['y']),
            'option_dx': round(g['dx'] * k, 2), 'row_dy': round(g['dy'] * k, 2),
            'cols': g['cols'], 'rows': g['rows'], 'bubbles': g['bubbles'],
        } for i, g in enumerate(grids)],
        # Izgaraya girmeyen tek tük baloncuklar: oturum / kitapçık gibi
        # seçim alanları olabilir (ChoiceField elle yazılır).
        'loose_bubbles': [[{'x': u(b['x']), 'y': u(b['y'])} for b in grp] for grp in small],
    }

    out = Path(args.out) if args.out else Path('build') / (Path(args.image).stem + '_sablon')
    out.parent.mkdir(parents=True, exist_ok=True)
    out.with_suffix('.json').write_text(json.dumps(result, ensure_ascii=False, indent=2),
                                        encoding='utf-8')
    out.with_suffix('.dart').write_text(dart_snippet(result), encoding='utf-8')
    # cv2.imwrite Türkçe karakterli yollarda (Masaüstü) yazamıyor.
    png = cv2.imencode('.png', overlay(color, anchors, track, bubbles, grids))[1]
    png.tofile(str(out.with_suffix('.png')))

    print(f'Baloncuk: {len(bubbles)}, ızgara: {len(grids)}, '
          f'hizalama: {"köşe kareleri" if anchors else ("zamanlama çizgisi" if track else "BULUNAMADI")}')
    for g in result['grids']:
        print(f"  #{g['index']}: {g['cols']} sütun × {g['rows']} satır, "
              f"({g['x']}, {g['y']}), şık aralığı {g['option_dx']}, satır aralığı {g['row_dy']}")
    print(f'Çıktılar: {out}.json / .dart / .png')


def dart_snippet(r):
    lines = [
        "// extract_template.py çıktısı: dersleri, alanları ve adı doldur.",
        "const yeniForm = OpticTemplate(",
        "  id: 'TODO',",
        "  trName: 'TODO',",
        f"  width: {r['width']},",
        f"  height: {r['height']},",
    ]
    if r['anchors']:
        pts = ', '.join(f"(x: {a['x']}, y: {a['y']})" for a in r['anchors'])
        lines += [f"  anchors: [{pts}],", f"  anchorSize: {r['anchor_size']},"]
    elif r['track']:
        t = r['track']
        lines += [
            "  track: TimingTrack(",
            f"    x: {t['x']},",
            f"    firstY: {t['first_y']},",
            f"    dy: {t['dy']},",
            f"    count: {t['count']},",
            f"    barWidth: {t['bar_width']},",
            f"    barHeight: {t['bar_height']},",
            "  ),",
        ]
    else:
        lines.append("  // HİZALAMA BULUNAMADI: köşe karesi ya da zamanlama çizgisi yok.")
    lines.append(f"  bubbleRadius: {r['bubble_radius']},")
    numbers = [g for g in r['grids'] if g['rows'] == 10 and g['cols'] <= 14]
    if numbers:
        g = numbers[0]
        lines.append(
            f"  // Izgara #{g['index']} öğrenci numarası olabilir ({g['cols']} hane).")
        lines.append(
            f"  studentNumber: NumberField(x: {g['x']}, y: {g['y']}, digits: {g['cols']}, "
            f"dx: {g['option_dx']}, dy: {g['row_dy']}),")
    if r['loose_bubbles']:
        pts = '; '.join(', '.join(f"({b['x']}, {b['y']})" for b in grp)
                        for grp in r['loose_bubbles'])
        lines.append(f"  // Tek tük baloncuklar (kitapçık / oturum alanı olabilir): {pts}")
        lines.append("  // booklet: ChoiceField(values: ['A', 'B'], bubbles: [...]),")
    lines.append("  layouts: {")
    lines.append("    ExamType.tyt: [")
    for g in r['grids']:
        if g['cols'] not in (4, 5):
            continue
        lines += [
            f"      // Izgara #{g['index']}: {g['cols']} şık × {g['rows']} soru",
            "      AnswerBlock(",
            "        subjects: ['TODO'],",
            f"        x: {g['x']},",
            f"        y: {g['y']},",
            f"        optionDx: {g['option_dx']},",
            f"        rowDy: {g['row_dy']},",
            *(["        options: 'ABCD',"] if g['cols'] == 4 else []),
            "      ),",
        ]
    lines += ["    ],", "  },", ");", ""]
    return '\n'.join(lines)


def overlay(color, anchors, track, bubbles, grids):
    img = color.copy()
    for b in bubbles:
        cv2.circle(img, (int(b['x']), int(b['y'])), int(b['r']), (0, 170, 0), 2)
    for i, g in enumerate(grids):
        r = int(g['r'] * 1.4)
        x1 = int(g['x'] - r)
        y1 = int(g['y'] - r)
        x2 = int(g['x'] + (g['cols'] - 1) * g['dx'] + r)
        y2 = int(g['y'] + (g['rows'] - 1) * g['dy'] + r)
        cv2.rectangle(img, (x1, y1), (x2, y2), (0, 0, 220), 2)
        cv2.putText(img, f'#{i + 1}', (x1, max(20, y1 - 8)), cv2.FONT_HERSHEY_SIMPLEX,
                    0.9, (0, 0, 220), 2)
    if track:
        for c in track['items']:
            cv2.rectangle(img, (c['left'], c['top']),
                          (c['left'] + c['w'], c['top'] + c['h']), (220, 80, 0), 3)
    if anchors:
        for a in anchors:
            cv2.circle(img, (int(a['x']), int(a['y'])), 30, (200, 0, 200), 4)
    return img


if __name__ == '__main__':
    main()
