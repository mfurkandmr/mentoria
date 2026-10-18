"""Mentoria tanıtım videoları (1080×1920, 30 fps).

    python tool/promo/make_promo.py coach|student

Girdi: build/promo/shots/*.png (tool/promo/promo_shots_test.dart üretir),
build/promo/fonts/nunito_*.ttf. Çıktı: build/promo/<ad>_visual.mp4 (sessiz)
ve build/promo/<ad>.mp4 (müzik ve künye: mix_track.py; müzik dosyası MUSIC).
"""
import math
import subprocess
import sys

import imageio_ffmpeg
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H, FPS = 1080, 1920, 30
SHOTS = 'build/promo/shots'
FONTS = 'build/promo/fonts'
EMOJI = r'C:\Windows\Fonts\seguiemj.ttf'
OUT = 'build/promo'
TRANS = 0.5  # sahne geçişi (sn)
# Telifsiz müzik (CC BY 4.0, künye şart): silvermansound.com/free-music/spark-of-inspiration
MUSIC = 'build/promo/music_dl/spark-of-inspiration.mp3'
CREDIT = 'Music: Spark of Inspiration by Shane Ivers - silvermansound.com'


def font(w, size):
    return ImageFont.truetype(f'{FONTS}/nunito_{w}.ttf', size)


def ease_out_cubic(x):
    x = min(max(x, 0), 1)
    return 1 - (1 - x) ** 3


def ease_out_back(x, s=1.5):
    x = min(max(x, 0), 1)
    return 1 + (s + 1) * (x - 1) ** 3 + s * (x - 1) ** 2


def ease_in_out(x):
    x = min(max(x, 0), 1)
    return 3 * x * x - 2 * x * x * x


def lerp(a, b, t):
    return a + (b - a) * t


def hex_rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


# ----------------------------------------------------------------- metin
def is_emoji(ch):
    o = ord(ch)
    return o >= 0x2190 and not (0x2500 <= o <= 0x25FF) or o in (0xFE0F, 0x200D)


def text_runs(s):
    runs, cur, emo = [], '', None
    for ch in s:
        e = is_emoji(ch)
        if emo is None or e == emo:
            cur += ch
        else:
            runs.append((cur, emo))
            cur = ch
        emo = e
    if cur:
        runs.append((cur, emo))
    return runs


def render_text(s, fnt, color=(255, 255, 255), shadow=True):
    """Metni (emoji dahil) şeffaf RGBA görüntü olarak çizer."""
    size = fnt.size
    efont = ImageFont.truetype(EMOJI, int(size * 0.95))
    runs = text_runs(s)
    widths = []
    for txt, emo in runs:
        f = efont if emo else fnt
        widths.append(int(f.getlength(txt)))
    w = sum(widths) + 24
    h = int(size * 1.45)
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    x = 12
    for (txt, emo), tw in zip(runs, widths):
        if emo:
            d.text((x, int(size * 0.18)), txt, font=efont, embedded_color=True)
        else:
            d.text((x, 0), txt, font=fnt, fill=color)
        x += tw
    if shadow:
        sh = Image.new('RGBA', img.size, (0, 0, 0, 0))
        alpha = img.split()[3].filter(ImageFilter.GaussianBlur(10))
        sh.putalpha(alpha.point(lambda a: int(a * 0.45)))
        out = Image.new('RGBA', (w, h + 10), (0, 0, 0, 0))
        out.alpha_composite(sh, (0, 8))
        out.alpha_composite(img, (0, 0))
        return out
    return img


class Headline:
    """Kelime kelime aşağıdan kayarak gelen başlık + alt başlık."""

    def __init__(self, lines, sub=None, size=92, top=150, color=(255, 255, 255), sub_color=(255, 255, 255)):
        self.words = []  # (img, x, y, delay)
        f = font(900, size)
        y = top
        delay = 0.15
        for line in lines:
            parts = line.split(' ')
            imgs = [render_text(p, f, color) for p in parts]
            space = int(size * 0.28)
            total = sum(i.size[0] for i in imgs) + space * (len(imgs) - 1) - 24 * len(imgs)
            x = (W - total) // 2 - 12
            for im in imgs:
                self.words.append((im, x, y, delay))
                x += im.size[0] + space - 24
                delay += 0.07
            y += int(size * 1.12)
        self.subs = []
        if sub:
            fs = font(700, 46)
            y += 18
            for line in sub.split('\n'):
                im = render_text(line, fs, sub_color)
                self.subs.append((im, (W - im.size[0]) // 2, y, delay + 0.15))
                y += 62
        self.bottom = y

    def draw(self, frame, t, alpha_mul=1.0):
        for im, x, y, dl in self.words + self.subs:
            p = ease_out_cubic((t - dl) / 0.45)
            if p <= 0:
                continue
            a = p * alpha_mul
            dy = int((1 - p) * 46)
            if a < 1:
                im = im.copy()
                im.putalpha(im.split()[3].point(lambda v: int(v * a)))
            frame.alpha_composite(im, (x, y + dy))


# ----------------------------------------------------------------- telefon
def status_bar(shot):
    """Durum çubuğu (9:41, çentik, pil) ve alt çizgi."""
    img = shot.convert('RGBA')
    w, h = img.size
    top = np.asarray(img.crop((0, 0, w, 141)).convert('L')).mean()
    col = (255, 255, 255, 255) if top < 140 else (20, 20, 30, 255)
    d = ImageDraw.Draw(img)
    d.text((110, 50), '9:41', font=font(800, 50), fill=col)
    # Dynamic Island
    d.rounded_rectangle((w // 2 - 185, 32, w // 2 + 185, 132), radius=50, fill=(5, 5, 8, 255))
    # Sinyal, wifi, pil
    x0 = w - 300
    for i in range(4):
        hh = 14 + i * 9
        d.rounded_rectangle((x0 + i * 17, 95 - hh, x0 + i * 17 + 11, 95), radius=3, fill=col)
    cx, cy = x0 + 115, 96
    for r in (34, 23, 12):
        d.arc((cx - r, cy - r, cx + r, cy + r), 225, 315, fill=col, width=7)
    d.rounded_rectangle((w - 150, 62, w - 70, 98), radius=10, outline=col, width=4)
    d.rounded_rectangle((w - 143, 69, w - 95, 91), radius=5, fill=col)
    d.rounded_rectangle((w - 66, 74, w - 60, 86), radius=2, fill=col)
    # Alt gösterge
    bot = np.asarray(img.crop((0, h - 102, w, h)).convert('L')).mean()
    bc = (255, 255, 255, 200) if bot < 140 else (20, 20, 30, 200)
    d.rounded_rectangle((w // 2 - 200, h - 40, w // 2 + 200, h - 26), radius=7, fill=bc)
    return img


def phone_master(name, angle=0.0):
    """Ekran görüntüsünü çerçeve, köşe yuvarlama ve gölgeyle telefona çevirir."""
    shot = status_bar(Image.open(f'{SHOTS}/{name}.png'))
    sw, sh = shot.size
    bez = 40
    radius = 170
    pw, ph = sw + 2 * bez, sh + 2 * bez
    mask = Image.new('L', (sw, sh), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, sw - 1, sh - 1), radius=radius - bez, fill=255)
    body = Image.new('RGBA', (pw, ph), (0, 0, 0, 0))
    d = ImageDraw.Draw(body)
    d.rounded_rectangle((0, 0, pw - 1, ph - 1), radius=radius, fill=(18, 18, 26, 255))
    d.rounded_rectangle((3, 3, pw - 4, ph - 4), radius=radius - 3, outline=(70, 70, 90, 255), width=3)
    body.paste(shot, (bez, bez), mask)
    # Cam parlaması
    gl = Image.new('RGBA', (pw, ph), (0, 0, 0, 0))
    gd = ImageDraw.Draw(gl)
    gd.polygon([(0, 0), (int(pw * 0.55), 0), (0, int(ph * 0.35))], fill=(255, 255, 255, 18))
    glm = Image.new('L', (pw, ph), 0)
    ImageDraw.Draw(glm).rounded_rectangle((bez, bez, pw - bez, ph - bez), radius=radius - bez, fill=255)
    body.alpha_composite(Image.composite(gl, Image.new('RGBA', (pw, ph), (0, 0, 0, 0)), glm))
    if angle:
        body = body.rotate(angle, resample=Image.BICUBIC, expand=True)
    # Gölge
    m = 140
    out = Image.new('RGBA', (body.size[0] + 2 * m, body.size[1] + 2 * m), (0, 0, 0, 0))
    shadow = Image.new('RGBA', out.size, (0, 0, 0, 0))
    sm = Image.new('L', out.size, 0)
    sm.paste(body.split()[3], (m, m + 50))
    sm = sm.filter(ImageFilter.GaussianBlur(55)).point(lambda v: int(v * 0.55))
    shadow.putalpha(sm)
    out.alpha_composite(shadow)
    out.alpha_composite(body, (m, m))
    return out, m, bez


class Phone:
    def __init__(self, name, cx, top, width, angle=0.0, delay=0.25, focus=None):
        self.master, self.margin, self.bez = phone_master(name, angle)
        self.shot_w = Image.open(f'{SHOTS}/{name}.png').size[0]
        self.body_w = self.shot_w + 2 * self.bez
        self.cx, self.top, self.width = cx, top, width
        self.delay = delay
        self.focus = focus  # (ekran_y_oranı, başlangıç_sn, ölçek)
        self.mid = self.master.resize(
            (int(self.master.size[0] * 0.62), int(self.master.size[1] * 0.62)), Image.LANCZOS
        )

    def zoom(self, t):
        if not self.focus:
            return 0.0
        return ease_in_out((t - self.focus[1]) / 0.9)

    def draw(self, frame, t, dur):
        p = ease_out_back((t - self.delay) / 0.75, 1.2)
        if t < self.delay:
            return
        scale = self.width / self.body_w * (1 + 0.035 * (t / dur))
        cx, top = self.cx, self.top + (1 - p) * 520
        if self.focus:
            fy, fstart, fz = self.focus
            z = ease_in_out((t - fstart) / 0.9)
            if z > 0:
                scale *= lerp(1, fz, z)
                # Odak noktası (ekran yüksekliğinin fy oranı) ekranın ortasına.
                body_h = self.master.size[1] - 2 * self.margin
                pivot = (self.bez + fy * (body_h - 2 * self.bez)) * scale
                target_top = H * 0.60 - pivot
                top = lerp(top, target_top, z)
        src = self.master if scale > 0.5 else self.mid
        f = scale * self.master.size[0] / src.size[0]
        nw, nh = int(src.size[0] * f), int(src.size[1] * f)
        im = src.resize((nw, nh), Image.BILINEAR if t > self.delay + 0.8 else Image.BICUBIC)
        m = int(self.margin * scale)
        x = int(cx - nw / 2)
        y = int(top - m)
        frame.alpha_composite(im, dest=(max(0, x), max(0, y)), source=(max(0, -x), max(0, -y)))


# ----------------------------------------------------------------- zemin
def gradient(c1, c2, w=W, h=H):
    a = np.linspace(0, 1, h)[:, None]
    b = np.linspace(0, 1, w)[None, :]
    k = np.clip(0.75 * a + 0.25 * b, 0, 1)[..., None]
    arr = np.array(c1) * (1 - k) + np.array(c2) * k
    return Image.fromarray(arr.astype(np.uint8), 'RGB').convert('RGBA')


def honeycomb(alpha=16):
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = 70
    for row in range(-1, int(H / (r * 1.5)) + 2):
        for col in range(-1, int(W / (r * 1.732)) + 2):
            cx = col * r * 1.732 + (r * 0.866 if row % 2 else 0)
            cy = row * r * 1.5
            pts = [(cx + r * math.cos(math.radians(60 * i + 30)), cy + r * math.sin(math.radians(60 * i + 30))) for i in range(6)]
            d.polygon(pts, outline=(255, 255, 255, alpha), width=3)
    return img


def orb(r, color, a=90):
    img = Image.new('RGBA', (r * 4, r * 4), (0, 0, 0, 0))
    ImageDraw.Draw(img).ellipse((r, r, 3 * r, 3 * r), fill=color + (a,))
    return img.filter(ImageFilter.GaussianBlur(r * 0.55))


HONEY = None


class Background:
    def __init__(self, c1, c2, seed=0):
        global HONEY
        if HONEY is None:
            HONEY = honeycomb()
        self.base = gradient(hex_rgb(c1), hex_rgb(c2))
        rng = np.random.default_rng(seed)
        self.orbs = []
        for i in range(7):
            col = (255, 214, 102) if i % 3 == 0 else (255, 255, 255)
            r = int(rng.integers(50, 130))
            self.orbs.append((orb(r, col, int(rng.integers(40, 85))), rng.random() * W, rng.random() * H,
                              rng.random() * 6.28, 30 + rng.random() * 50))

    def draw(self, t):
        fr = self.base.copy()
        fr.alpha_composite(HONEY, (0, int(-30 * math.sin(t * 0.4))))
        for im, x, y, ph, amp in self.orbs:
            ox = x + amp * math.sin(t * 0.7 + ph) - im.size[0] / 2
            oy = y + amp * math.cos(t * 0.5 + ph) - im.size[1] / 2 - t * 18
            fr.alpha_composite(im, (int(ox), int(oy)) if ox > -im.size[0] else (0, 0))
        return fr


# ----------------------------------------------------------------- sahneler
class Scene:
    def __init__(self, dur, bg, headline=None, phones=(), extra=None):
        self.dur, self.bg, self.headline, self.phones, self.extra = dur, bg, headline, list(phones), extra

    def frame(self, t):
        fr = self.bg.draw(t)
        for p in self.phones:
            p.draw(fr, t, self.dur)
        if self.extra:
            self.extra(fr, t)
        if self.headline:
            # Kamera yakınlaşınca başlık çekilir; ekran öne çıkar.
            z = max([p.zoom(t) for p in self.phones] + [0.0])
            if z < 1:
                self.headline.draw(fr, t, 1 - z)
        return fr


def safe_paste(fr, im, x, y):
    x, y = int(x), int(y)
    if x >= fr.size[0] or y >= fr.size[1] or x + im.size[0] <= 0 or y + im.size[1] <= 0:
        return
    fr.alpha_composite(im, dest=(max(0, x), max(0, y)), source=(max(0, -x), max(0, -y)))


def scaled(im, s):
    s = max(s, 0.01)
    return im.resize((max(1, int(im.size[0] * s)), max(1, int(im.size[1] * s))), Image.BICUBIC)


def faded(im, a):
    if a >= 1:
        return im
    im = im.copy()
    im.putalpha(im.split()[3].point(lambda v: int(v * max(a, 0))))
    return im


def wordmark(size):
    """"mento" beyaz + "ria" bal sarısı."""
    f = font(900, size)
    a = render_text('mento', f, (255, 255, 255))
    b = render_text('ria', f, (255, 196, 46))
    img = Image.new('RGBA', (a.size[0] + b.size[0] - 24, max(a.size[1], b.size[1])), (0, 0, 0, 0))
    img.alpha_composite(a, (0, 0))
    img.alpha_composite(b, (a.size[0] - 24, 0))
    return img


def rays(n=14):
    s = 1500
    img = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = s / 2
    for i in range(n):
        a0 = 2 * math.pi * i / n
        a1 = a0 + math.pi / n * 0.55
        d.polygon([(c, c), (c + s * math.cos(a0), c + s * math.sin(a0)), (c + s * math.cos(a1), c + s * math.sin(a1))],
                  fill=(255, 225, 140, 34))
    return img.filter(ImageFilter.GaussianBlur(6))


RAYS = None


def brand_scene(dur, bg, bizz_name, title_lines, tagline, cta=None):
    global RAYS
    if RAYS is None:
        RAYS = rays()
    bizz = Image.open(f'{SHOTS}/{bizz_name}.png').convert('RGBA')
    bizz = bizz.crop(bizz.getbbox())
    bizz = scaled(bizz, 560 / bizz.size[0])
    mark = wordmark(150)
    tl = [render_text(l, font(900, 74)) for l in title_lines]
    tg = render_text(tagline, font(700, 44), (255, 236, 179)) if tagline else None
    cta_img = None
    if cta:
        txt = render_text(cta, font(900, 46), (40, 28, 80), shadow=False)
        pad = 34
        cta_img = Image.new('RGBA', (txt.size[0] + 2 * pad, txt.size[1] + 2 * pad - 10), (0, 0, 0, 0))
        ImageDraw.Draw(cta_img).rounded_rectangle((0, 0, cta_img.size[0] - 1, cta_img.size[1] - 1), radius=50,
                                                  fill=(255, 196, 46, 255))
        cta_img.alpha_composite(txt, (pad, pad - 12))

    def extra(fr, t):
        rot = RAYS.rotate(t * 12, resample=Image.BILINEAR)
        ra = ease_out_cubic(t / 0.8)
        safe_paste(fr, faded(rot, ra), W / 2 - rot.size[0] / 2, 620 - rot.size[1] / 2)
        p = ease_out_back((t - 0.1) / 0.7, 1.8)
        bob = 14 * math.sin(t * 3.2)
        if p > 0:
            b = scaled(bizz, p)
            safe_paste(fr, b, W / 2 - b.size[0] / 2, 620 - b.size[1] / 2 + bob)
        pm = ease_out_cubic((t - 0.55) / 0.6)
        if pm > 0:
            m = scaled(mark, 0.85 + 0.15 * pm)
            safe_paste(fr, faded(m, pm), W / 2 - m.size[0] / 2, 990 + (1 - pm) * 60)
        y = 1215
        for i, im in enumerate(tl):
            pp = ease_out_cubic((t - 0.9 - i * 0.12) / 0.5)
            if pp > 0:
                safe_paste(fr, faded(im, pp), W / 2 - im.size[0] / 2, y + (1 - pp) * 40)
            y += 92
        if tg:
            pp = ease_out_cubic((t - 1.3) / 0.5)
            if pp > 0:
                safe_paste(fr, faded(tg, pp), W / 2 - tg.size[0] / 2, y + 20)
            y += 90
        if cta_img is not None:
            pp = ease_out_back((t - 1.6) / 0.6, 1.6)
            if pp > 0:
                pulse = 1 + 0.03 * math.sin(max(0, t - 2.2) * 5)
                c = scaled(cta_img, pp * pulse)
                safe_paste(fr, c, W / 2 - c.size[0] / 2, y + 60 + (cta_img.size[1] - c.size[1]) / 2)

    return Scene(dur, bg, None, [], extra)


def stat_scene(dur, bg, value, suffix, lines, sub, decimals_sep='.'):
    """Büyük sayaç: 0'dan değere sayar."""
    big = font(900, 250)
    head = Headline(lines, sub, size=84, top=1100)
    bizz = Image.open(f'{SHOTS}/bizz_happy.png').convert('RGBA')
    bizz = scaled(bizz.crop(bizz.getbbox()), 300 / 900 * 1.3)

    def fmt(v):
        s = f'{int(v):,}'.replace(',', decimals_sep)
        return s + suffix

    def extra(fr, t):
        p = ease_out_cubic((t - 0.2) / 1.6)
        im = render_text(fmt(value * p), big, (255, 214, 64))
        sc = 0.9 + 0.1 * ease_out_back((t - 0.2) / 0.6)
        im = scaled(im, sc)
        safe_paste(fr, im, W / 2 - im.size[0] / 2, 720 - im.size[1] / 2)
        pb = ease_out_back((t - 0.4) / 0.7, 1.6)
        if pb > 0:
            b = scaled(bizz, pb)
            safe_paste(fr, b, W / 2 - b.size[0] / 2, 330 - b.size[1] / 2 + 10 * math.sin(t * 3))

    s = Scene(dur, bg, head, [], extra)
    return s


def chip(text, color):
    txt = render_text(text, font(800, 40), (255, 255, 255), shadow=False)
    pad = 28
    im = Image.new('RGBA', (txt.size[0] + 2 * pad, txt.size[1] + 2 * pad - 14), (0, 0, 0, 0))
    ImageDraw.Draw(im).rounded_rectangle((0, 0, im.size[0] - 1, im.size[1] - 1), radius=40, fill=color + (255,),
                                         outline=(255, 255, 255, 200), width=4)
    im.alpha_composite(txt, (pad, pad - 12))
    return im


BRANDS = [  # (ad, renk, logo görseli)
    ('Mentoria', (108, 75, 216), 'bizz'),
    ('Yıldız Dershanesi', (14, 140, 200), 'build/promo/logos/yildiz.png'),
    ('Zirve Akademi', (16, 150, 105), 'build/promo/logos/zirve.png'),
]


def brand_badge(logo, size=230):
    if logo == 'bizz':
        bz = Image.open(f'{SHOTS}/bizz_idle.png').convert('RGBA')
        bz = bz.crop(bz.getbbox())
        base = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        ImageDraw.Draw(base).rounded_rectangle((0, 0, size - 1, size - 1), radius=int(size * 0.22),
                                               fill=(255, 248, 231, 255))
        b = scaled(bz, size * 0.82 / max(bz.size))
        base.alpha_composite(b, ((size - b.size[0]) // 2, (size - b.size[1]) // 2))
        im = base
    else:
        im = Image.open(logo).convert('RGBA').resize((size, size), Image.LANCZOS)
    m = 30
    out = Image.new('RGBA', (size + 2 * m, size + 2 * m), (0, 0, 0, 0))
    sm = Image.new('L', out.size, 0)
    sm.paste(im.split()[3], (m, m + 12))
    sh = Image.new('RGBA', out.size, (0, 0, 0, 0))
    sh.putalpha(sm.filter(ImageFilter.GaussianBlur(14)).point(lambda v: int(v * 0.45)))
    out.alpha_composite(sh)
    out.alpha_composite(im, (m, m))
    return out


def brand_intro_scene(bg):
    """Özelleştirme bölümünün girişi: üç marka rozeti ve 1-2-3 adımları."""
    h = Headline(['Uygulama', 'senin markan olsun'], 'Kurum müdürü birkaç dakikada ayarlar', top=230)
    badges = [brand_badge(l) for _, _, l in BRANDS]
    names = [render_text(n, font(800, 36)) for n, _, _ in BRANDS]
    steps = [chip(t, c) for t, c in (('1 · Logo', (229, 72, 77)), ('2 · Renk', (14, 140, 200)),
                                      ('3 · Yazı tipi', (16, 150, 105)))]

    def extra(fr, t):
        for i, (b, nm) in enumerate(zip(badges, names)):
            p = ease_out_back((t - 0.6 - 0.18 * i) / 0.55, 1.7)
            if p <= 0:
                continue
            cx = W * (0.2 + 0.3 * i)
            bob = 10 * math.sin(t * 2.6 + i)
            im = scaled(b, p)
            safe_paste(fr, im, cx - im.size[0] / 2, 900 - im.size[1] / 2 + bob)
            safe_paste(fr, faded(nm, min(1, p)), cx - nm.size[0] / 2, 1060)
        y = 1260
        for i, c in enumerate(steps):
            p = ease_out_back((t - 1.5 - 0.25 * i) / 0.5, 1.6)
            if p > 0:
                im = scaled(c, p)
                safe_paste(fr, im, W / 2 - im.size[0] / 2, y + (c.size[1] - im.size[1]) / 2)
            y += c.size[1] + 26

    return Scene(5.2, bg, h, [], extra)


def three_scene(names, lines, sub, bg, labels=None, dur=5.2):
    """Yan yana üç telefon (ör. üç markanın giriş ekranı) ve altlarında etiket."""
    h = Headline(lines, sub)
    top = max(640, h.bottom + 90)
    phones = [Phone(n, W * (0.19 + 0.31 * i), top + (0 if i == 1 else 50), 400, angle=(5, 0, -5)[i],
                    delay=0.25 + 0.15 * i) for i, n in enumerate(names)]
    chips = [chip(t, c) for t, c in labels] if labels else []
    small = [scaled(c, 0.62) for c in chips]

    def extra(fr, t):
        for i, c in enumerate(small):
            p = ease_out_back((t - 1.0 - 0.15 * i) / 0.5, 1.6)
            if p > 0:
                im = scaled(c, p)
                safe_paste(fr, im, W * (0.19 + 0.31 * i) - im.size[0] / 2, top + 920)

    return Scene(dur, bg, h, phones, extra)


def ph_scene(name, lines, sub, bg, focus=None, width=700):
    h = Headline(lines, sub)
    return Scene(4.4 if not focus else 5.4, bg, h, [Phone(name, W / 2, max(600, h.bottom + 70), width, focus=focus)])


def two_scene(a, b, lines, sub, bg):
    h = Headline(lines, sub)
    top = max(640, h.bottom + 80)
    return Scene(4.8, bg, h, [Phone(a, W * 0.30, top + 40, 560, angle=6, delay=0.25),
                               Phone(b, W * 0.70, top, 560, angle=-6, delay=0.45)])


# ----------------------------------------------------------------- videolar
def coach_video():
    V = '#2B1F6B', '#6C4BD8'
    G = '#1D2B64', '#3D7BD9'
    O = '#7A2A55', '#E0663A'
    T = '#123B3A', '#2E9C7A'
    S = '#0B3B5C', '#0EA5E9'
    ph, two = ph_scene, two_scene
    s = [brand_scene(3.6, Background('#160F3D', '#5B3CC4', 1), 'bizz_idle',
                     ['Koçlar ve kurumlar için'], 'Koç destekli YKS takibi'),
         stat_scene(3.4, Background(*V, 2), 4, ' rol', ['Tek platform'], 'Koç · Kurum müdürü · Öğrenci · Veli'),
         ph('c01_coach_home', ['Tüm öğrencilerin', 'tek ekranda'], 'Haftalık soru, bekleyen görev, görüşmeler',
            Background(*V, 3)),
         ph('c16_invite', ['Öğrencini', 'kodla ekle'], 'Davet kodunu gönder, öğrenci kaydını kendisi açar',
            Background(*T, 4)),
         ph('c02_coach_trends', ['Kim yükseliyor,', 'kim düşüyor?'], 'Son 5 denemede değişim, ana sayfada',
            Background(*O, 5), focus=(0.22, 2.4, 1.55)),
         two('c15_import', 'c04_detail_exams', ['Denemeler', 'tek dosyayla'],
             "Excel'i yükle, netler öğrencilere dağıtılsın", Background(*G, 6)),
         two('c08_detail_questions', 'c10_detail_study', ['Soru ve süre', 'takibi'],
             'Günlük soru, doğruluk ve çalışma saati', Background(*V, 7)),
         ph('c09_detail_topics', ['Konu konu', 'ilerleme'], 'Biten, çalışılan ve tekrar gereken konular',
            Background(*T, 8)),
         two('c14_assign', 'c12_detail_homework', ['Konudan', 'ödev ver'],
             'Öğrenci işaretledikçe ilerlemeyi gör', Background(*O, 9)),
         two('c11_detail_tasks', 'c13_detail_notes', ['Görev ver,', 'not bırak'], 'Hedef soru sayısı ve son gün',
             Background(*G, 10)),
         ph('c06_detail_plan', ['Haftalık planı', 'sen yaz 📅'], 'Öğrenciye anında bildirim gider',
            Background(*T, 11)),
         ph('c05_detail_learn', ['Eğitim karnesi'], 'İsabet, son 7 gün ve en zayıf konu', Background(*V, 12),
            focus=(0.36, 2.4, 1.4)),
         ph('c07_detail_mistakes', ["Hata Defteri'ni", 'birlikte izle'], 'Akıllı tekrar: 1 · 3 · 7 · 21 gün',
            Background(*O, 13)),
         ph('a01_admin_home', ['Kurum müdürü', 'paneli'], 'Lisans, koçlar, kurum geneli', Background(*G, 14)),
         ph('a04_ranking', ['Başarı', 'sıralaması 🏆'], 'Son 5 denemenin ortalamasıyla kurum içi', Background(*O, 15)),
         ph('a03_admin_inactive', ['Hareketsiz öğrenciyi', 'kaçırma'], 'Bu hafta çalışmayanlar tek listede',
            Background(*T, 16)),
         # Özelleştirme (beyaz etiket)
         brand_intro_scene(Background('#160F3D', '#5B3CC4', 17)),
         ph('l_editor_yildiz', ['1 · Logonu ve', 'adını ekle'], 'Kurum görünümü ekranında',
            Background(*S, 18), width=760),
         ph('l_editor_yildiz', ['2 · Renklerini', 'seç 🎨'], 'Ana renk ve ikincil renk; önizleme anında değişir',
            Background(*O, 19), width=760),
         ph('l_editor_fonts_yildiz', ['3 · Yazı tipini', 'seç'], '10 yazı tipi: zarif, tombul, el yazısı…',
            Background(*G, 20), width=760),
         three_scene(['l_login_mentoria', 'l_login_yildiz', 'l_login_zirve'], ['Öğrencin', 'senin markanı görür'],
                     'Giriş ekranında logon, rengin, yazı tipin', Background(*V, 21),
                     labels=[(n, c) for n, c, _ in BRANDS]),
         two('l_home_yildiz', 'l_home_zirve', ['Her ekranda', 'kurumun'], 'Ana sayfadan bildirimlere kadar',
             Background(*T, 22)),
         brand_scene(4.6, Background('#160F3D', '#5B3CC4', 23), 'bizz_happy',
                     ['Öğrenciniz büyürken', 'siz izleyin.'], None, 'Davet kodunuzla hemen başlayın')]
    return 'mentoria_koc_mudur', s


def student_video():
    Y = '#5A2D0C', '#F2A93B'
    V = '#2B1F6B', '#6C4BD8'
    P = '#5B1D4F', '#E0487A'
    T = '#123B3A', '#2E9C7A'
    B = '#1D2B64', '#3D7BD9'
    ph, two = ph_scene, two_scene
    s = [brand_scene(3.6, Background('#160F3D', '#5B3CC4', 21), 'bizz_happy',
                     ['YKS yolculuğun', 'artık eğlenceli'], 'Öğrenci ve veliler için 🐝'),
         ph('s01_home', ['Merhaba, Elif!'], 'Geri sayım, hedefler ve koçunla görüşmen', Background(*V, 22)),
         two('s17_questions', 's18_study', ['Sorunu ve', 'süreni kaydet'], 'Pomodoro sayacı, günlük hedef, doğruluk',
             Background(*Y, 23)),
         ph('s19_topics', ['Hangi konu bitti?'], 'Konu konu ilerleme, tekrar gerekenler', Background(*T, 24)),
         stat_scene(3.4, Background(*Y, 25), 7200, '', ['telifsiz soru'], 'TYT + AYT · her gün yenilenen haklar'),
         two('s04_learn_ayt', 's05_quiz', ['Çöz, öğren,', 'ilerle'], 'Bilgi kartları ve anında çözüm',
             Background(*B, 26)),
         ph('s06_daily', ['Günün Sorusu ☀️'], 'Her sabah 09.00 · serini büyüt', Background(*Y, 27),
            focus=(0.12, 2.4, 1.45)),
         two('s20_exams', 's11_score', ['Denemelerin', 've puanın'], 'Net gelişimi ve hedefe kalan net',
             Background(*V, 28)),
         two('s08_duel_intro', 's10_duel_result', ['Arkadaşını', 'düelloya çağır ⚔️'],
             'Aynı 10 soru · eşitlikte hızlı olan kazanır', Background(*P, 29)),
         two('s21_homework', 's14_plan', ['Ödevin ve', 'planın cebinde'], 'Koçun hazırlar, sen işaretlersin',
             Background(*T, 30)),
         two('s12_mistakes', 's13_garden', ['Yanlışlarını', 'unutma'], 'Hata Defteri · Odak Bahçesi',
             Background(*B, 31)),
         two('s15_avatar', 's22_leaderboard', ['Başarı = ödül 🏆'], 'Avatar parçaları ve haftanın arıları',
             Background(*P, 32)),
         ph('s16_recap', ['Haftanın', 'Bal Raporu 🍯'], 'Her pazar haftanın özeti', Background(*Y, 33)),
         ph('s23_notifications', ['Hiçbir şeyi', 'kaçırma 🔔'], 'Yeni ödev, deneme sonucu, görüşme hatırlatması',
            Background(*V, 34)),
         two('p01_parent_home', 'p03_parent_plan', ['Veliler de', 'yanında'], 'Haftalık özet her pazar bildirimde',
             Background(*T, 35)),
         brand_scene(4.6, Background('#160F3D', '#5B3CC4', 36), 'bizz_happy',
                     ['Hedefine birlikte', 'uçalım!'], None, 'Mentoria ile hemen başla 🐝')]
    return 'mentoria_ogrenci_veli', s


def render(name, scenes):
    total = sum(s.dur for s in scenes) - TRANS * (len(scenes) - 1)
    nframes = int(total * FPS)
    starts = []
    acc = 0.0
    for s in scenes:
        starts.append(acc)
        acc += s.dur - TRANS
    path = f'{OUT}/{name}_visual.mp4'
    cmd = [imageio_ffmpeg.get_ffmpeg_exe(), '-y', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgb24',
           '-s', f'{W}x{H}', '-r', str(FPS), '-i', '-', '-c:v', 'libx264', '-preset', 'medium', '-crf', '17',
           '-pix_fmt', 'yuv420p', '-movflags', '+faststart', path]
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    for i in range(nframes):
        t = i / FPS
        active = [(k, s) for k, s in enumerate(scenes) if starts[k] <= t < starts[k] + s.dur]
        k, s = active[0]
        fr = s.frame(t - starts[k]).convert('RGB')
        if len(active) > 1:
            k2, s2 = active[1]
            tt = (t - starts[k2]) / TRANS
            a = ease_in_out(tt)
            nxt = s2.frame(t - starts[k2]).convert('RGB')
            # Çıkan küçülür, gelen hafif büyükten oturur.
            sc_out = 1 - 0.06 * a
            o = fr.resize((int(W * sc_out), int(H * sc_out)), Image.BILINEAR)
            base = Image.new('RGB', (W, H), (0, 0, 0))
            base.paste(o, ((W - o.size[0]) // 2, (H - o.size[1]) // 2))
            sc_in = 1.06 - 0.06 * a
            n = nxt.resize((int(W * sc_in), int(H * sc_in)), Image.BILINEAR).crop(
                ((int(W * sc_in) - W) // 2, (int(H * sc_in) - H) // 2, (int(W * sc_in) - W) // 2 + W, (int(H * sc_in) - H) // 2 + H))
            fr = Image.blend(base, n, a)
        proc.stdin.write(fr.tobytes())
        if i % 150 == 0:
            print(f'{name}: {i}/{nframes}', flush=True)
    proc.stdin.close()
    proc.wait()
    return path, total


def preview(name, scenes):
    tw, th = 270, 480
    sheet = Image.new('RGB', (len(scenes) * (tw + 8), 2 * (th + 8)), (20, 20, 20))
    for k, s in enumerate(scenes):
        for r, t in enumerate((1.3, s.dur - 0.35)):
            fr = s.frame(t).convert('RGB').resize((tw, th), Image.LANCZOS)
            sheet.paste(fr, (k * (tw + 8), r * (th + 8)))
    sheet.save(f'{OUT}/{name}_preview.png')
    print('önizleme', name)


if __name__ == '__main__':
    which = sys.argv[1]
    name, scenes = coach_video() if which == 'coach' else student_video()
    if len(sys.argv) > 2 and sys.argv[2] == '--preview':
        preview(name, scenes)
        sys.exit(0)
    path, total = render(name, scenes)
    import mix_track
    mix_track.main(path, MUSIC, f'{OUT}/{name}.mp4', CREDIT)
    print('bitti', name, f'{total:.1f} sn')
