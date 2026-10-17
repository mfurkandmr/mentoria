"""Mentoria tanıtım videoları (1080×1920, 30 fps).

    python tool/promo/make_promo.py coach|student

Girdi: build/promo/shots/*.png (tool/promo/promo_shots_test.dart üretir),
build/promo/fonts/nunito_*.ttf. Çıktı: build/promo/<ad>_visual.mp4 (sessiz)
ve build/promo/<ad>.mp4 (müzikli; müzik make_music.py ile).
"""
import math
import os
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


def card(name, width=230):
    """Yuvarlak köşeli, beyaz kenarlı, gölgeli küçük ekran kartı."""
    shot = status_bar(Image.open(f'{SHOTS}/{name}.png'))
    hgt = int(shot.size[1] * width / shot.size[0])
    shot = shot.resize((width, hgt), Image.LANCZOS)
    b, r, m = 6, 26, 40
    body = Image.new('RGBA', (width + 2 * b, hgt + 2 * b), (0, 0, 0, 0))
    ImageDraw.Draw(body).rounded_rectangle((0, 0, body.size[0] - 1, body.size[1] - 1), radius=r + b,
                                           fill=(255, 255, 255, 255))
    mask = Image.new('L', shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, width - 1, hgt - 1), radius=r, fill=255)
    body.paste(shot, (b, b), mask)
    out = Image.new('RGBA', (body.size[0] + 2 * m, body.size[1] + 2 * m), (0, 0, 0, 0))
    sm = Image.new('L', out.size, 0)
    sm.paste(body.split()[3], (m, m + 16))
    sh = Image.new('RGBA', out.size, (0, 0, 0, 0))
    sh.putalpha(sm.filter(ImageFilter.GaussianBlur(18)).point(lambda v: int(v * 0.5)))
    out.alpha_composite(sh)
    out.alpha_composite(body, (m, m))
    return out


def vignette():
    y, x = np.mgrid[0:H, 0:W]
    d = np.sqrt(((x - W / 2) / (W * 0.62)) ** 2 + ((y - H * 0.48) / (H * 0.62)) ** 2)
    a = np.clip((d - 0.55) / 0.6, 0, 1) ** 1.6 * 170
    arr = np.zeros((H, W, 4), np.uint8)
    arr[..., 0], arr[..., 1], arr[..., 2] = 22, 12, 4
    arr[..., 3] = a.astype(np.uint8)
    return Image.fromarray(arr, 'RGBA')


def cafe_intro(photo, phone_xy, orbit_c, shots, caption):
    """Kafede telefonlu adam: ekranlar etrafında döner, birleşip telefona
    girer, kamera telefona dalar."""
    src = Image.open(photo).convert('RGB')
    k = W / src.size[0]
    img = src.resize((W, int(src.size[1] * k)), Image.LANCZOS).convert('RGBA')
    px, py = phone_xy[0] * k, phone_xy[1] * k
    ox, oy = orbit_c[0] * k, orbit_c[1] * k
    vig = vignette()
    cards = [card(n, 200) for n in shots]
    n = len(cards)
    glow = orb(90, (255, 230, 170), 255)
    head = Headline(caption, None, size=74, top=170)
    dur = 5.8
    T_CONV, T_IN, T_DIVE = 3.2, 4.3, 4.35

    def camera(t):
        s = 1.0 + 0.10 * ease_in_out(t / T_DIVE)
        cx = lerp(W / 2, px, 0.3 * ease_in_out(t / T_DIVE))
        cy = lerp(H / 2, py, 0.3 * ease_in_out(t / T_DIVE))
        dz = ease_in_out((t - T_DIVE) / 0.85) ** 1.4
        if dz > 0:
            s *= math.exp(math.log(10) * dz)
            cx, cy = lerp(cx, px, min(1, dz * 4)), lerp(cy, py, min(1, dz * 4))
        hw, hh = W / (2 * s), H / (2 * s)
        cx = min(max(cx, hw), W - hw)
        cy = min(max(cy, hh), img.size[1] - hh)
        return s, cx, cy

    def card_state(i, t):
        """(x, y, ölçek, alfa, derinlik) — görüntü koordinatlarında."""
        appear = 0.35 + 0.16 * i
        a_in = ease_out_cubic((t - appear) / 0.5)
        ang = 2 * math.pi * i / n + t * 0.95
        z = math.sin(ang)  # +1 önde (göğüs hizası), -1 arkada (başın üstü)
        x = ox + 455 * math.cos(ang)
        y = oy + (200 if z > 0 else 300) * z
        sc = 0.55 + 0.45 * (z + 1) / 2
        sc *= 0.4 + 0.6 * ease_out_back((t - appear) / 0.6, 1.4) if t > appear else 0
        alpha = a_in * (0.35 + 0.65 * (z + 1) / 2)
        c = ease_in_out((t - T_CONV - 0.05 * i) / (T_IN - T_CONV))
        if c > 0:
            c2 = c ** 1.7
            x, y = lerp(x, px, c2), lerp(y, py, c2)
            sc = lerp(sc, 0.06, c2)
            alpha *= 1 - 0.6 * c2 if c < 1 else 0
            z = lerp(z, 2, c)
        return x, y, sc, alpha, z

    def frame(t):
        s, cx, cy = camera(t)
        box = (cx - W / (2 * s), cy - H / (2 * s), cx + W / (2 * s), cy + H / (2 * s))
        fr = img.resize((W, H), Image.BILINEAR, box=box)

        def to_screen(x, y):
            return (x - cx) * s + W / 2, (y - cy) * s + H / 2

        items = []
        for i in range(n):
            for g in range(3 if t > T_CONV else 1):  # birleşirken iz
                st = card_state(i, t - g * 0.035)
                if st[3] > 0.01 and st[2] > 0.01:
                    items.append((st[4] - g * 0.001, i, st, 1 - g * 0.35))
        for _, i, (x, y, sc, a, z), gm in sorted(items, key=lambda v: v[0]):
            im = scaled(cards[i], sc * s)
            sx, sy = to_screen(x, y)
            safe_paste(fr, faded(im, a * gm), sx - im.size[0] / 2, sy - im.size[1] / 2)
        # Telefona giriş parlaması
        g = math.exp(-((t - T_IN - 0.1) / 0.35) ** 2)
        if g > 0.02:
            gi = scaled(glow, (0.6 + 1.6 * g) * min(s, 3))
            sx, sy = to_screen(px, py)
            safe_paste(fr, faded(gi, g), sx - gi.size[0] / 2, sy - gi.size[1] / 2)
        fr.alpha_composite(vig)
        head.draw(fr, t - 0.5, 1 - ease_out_cubic((t - 3.0) / 0.5))
        # Dalış sonunda sıcak beyaz ışık
        w = ease_in_out((t - 4.85) / 0.45)
        if w > 0:
            fr = Image.blend(fr, Image.new('RGBA', (W, H), (255, 246, 228, 255)), w)
        if t < 0.4:
            fr = Image.blend(Image.new('RGBA', (W, H), (0, 0, 0, 255)), fr, ease_in_out(t / 0.4))
        return fr

    sc = Scene(dur, None)
    sc.frame = frame
    return sc


class SwapPhone:
    """Aynı yerde sırayla değişen ekranlar (çapraz geçişli)."""

    def __init__(self, names, switch, cx, top, width, angle=0.0, delay=0.25):
        self.phones = [Phone(nm, cx, top, width, angle=angle, delay=delay) for nm in names]
        self.switch = switch  # her ekranın bitiş anı

    def zoom(self, t):
        return 0.0

    def index(self, t):
        for i, s in enumerate(self.switch):
            if t < s:
                return i, ease_in_out((t - (s - 0.35)) / 0.35)
        return len(self.phones) - 1, 0.0

    def draw(self, frame, t, dur):
        i, b = self.index(t)
        self.phones[i].draw(frame, t, dur)
        if b > 0 and i + 1 < len(self.phones):
            layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
            self.phones[i + 1].draw(layer, t, dur)
            frame.alpha_composite(faded(layer, b))


def chip(text, color):
    txt = render_text(text, font(800, 40), (255, 255, 255), shadow=False)
    pad = 28
    im = Image.new('RGBA', (txt.size[0] + 2 * pad, txt.size[1] + 2 * pad - 14), (0, 0, 0, 0))
    ImageDraw.Draw(im).rounded_rectangle((0, 0, im.size[0] - 1, im.size[1] - 1), radius=40, fill=color + (255,),
                                         outline=(255, 255, 255, 200), width=4)
    im.alpha_composite(txt, (pad, pad - 12))
    return im


def whitelabel_scene(bg):
    h = Headline(['Kendi logon,', 'rengin, yazı tipin'], 'Uygulama kurumunun kimliğine bürünür')
    top = max(600, h.bottom + 80)
    sw = [2.2, 3.9, 9]
    left = SwapPhone(['w_editor', 'w_editor_fonts'], [3.2, 9], W * 0.29, top + 40, 470, angle=5, delay=0.25)
    right = SwapPhone(['w_learn_mentoria', 'w_learn_yildiz', 'w_learn_zirve'], sw, W * 0.71, top, 470, angle=-5,
                      delay=0.45)
    labels = [('Mentoria · Nunito', (108, 75, 216)), ('Yıldız Dershanesi · Poppins', (31, 128, 160)),
              ('Zirve Akademi · Baloo 2', (46, 140, 80))]
    chips = [chip(t, c) for t, c in labels]
    cy = top + 1040

    def extra(fr, t):
        i, b = right.index(t)
        p = ease_out_back((t - 0.9) / 0.5, 1.6)
        if p <= 0:
            return
        for k, a in ((i, 1 - b), (i + 1, b)):
            if k < len(chips) and a > 0:
                c = scaled(chips[k], p)
                safe_paste(fr, faded(c, a), W / 2 - c.size[0] / 2, cy + (1 - a) * 30)

    return Scene(6.4, bg, h, [left, right], extra)


# ----------------------------------------------------------------- videolar
INTRO_SHOTS_COACH = ['c01_coach_home', 'c02_coach_trends', 'a01_admin_home', 'c04_detail_exams', 'c06_detail_plan',
                     'w_learn_yildiz', 'c05_detail_learn']
INTRO_SHOTS_STUDENT = ['s01_home', 's04_learn_ayt', 's06_daily', 's08_duel_intro', 's11_score', 's14_plan',
                       's15_avatar']
HIT = 4.4  # ekranların telefona girdiği an (müzik vurgusu)


def coach_video():
    V = '#2B1F6B', '#6C4BD8'
    G = '#1D2B64', '#3D7BD9'
    O = '#7A2A55', '#E0663A'
    T = '#123B3A', '#2E9C7A'
    scenes = [cafe_intro('build/promo/cafe_coach.png', (400, 875), (430, 690), INTRO_SHOTS_COACH,
                         ['Bütün kurumun', 'tek telefonda'])]
    scenes.append(brand_scene(3.6, Background('#160F3D', '#5B3CC4', 1), 'bizz_idle',
                              ['Koçlar ve kurumlar için'], 'Koç destekli YKS takibi'))
    scenes.append(stat_scene(3.4, Background(*V, 2), 4, ' rol', ['Tek platform'],
                             'Koç · Kurum müdürü · Öğrenci · Veli'))

    def ph(name, lines, sub, bg, focus=None, top=600, width=700):
        h = Headline(lines, sub)
        return Scene(4.4 if not focus else 5.4, bg, h, [Phone(name, W / 2, max(top, h.bottom + 70), width, focus=focus)])

    scenes.append(ph('c01_coach_home', ['Tüm öğrencilerin', 'tek ekranda'], 'Haftalık soru, bekleyen görev, görüşmeler', Background(*V, 3)))
    scenes.append(ph('c02_coach_trends', ['Kim yükseliyor,', 'kim düşüyor?'], 'Son 5 denemede değişim, ana sayfada',
                     Background(*O, 4), focus=(0.22, 2.4, 1.55)))
    scenes.append(ph('c04_detail_exams', ['Her denemede', 'net gelişimi'], 'Ders ders analiz, trend ve tahmin', Background(*G, 5),
                     focus=(0.62, 2.4, 1.35)))
    scenes.append(ph('c06_detail_plan', ['Haftalık planı', 'sen yaz 📅'], 'Öğrenciye anında bildirim gider', Background(*T, 6)))
    scenes.append(ph('c05_detail_learn', ['Eğitim karnesi'], 'İsabet, son 7 gün ve en zayıf konu', Background(*V, 7),
                     focus=(0.36, 2.4, 1.4)))
    scenes.append(ph('c07_detail_mistakes', ["Hata Defteri'ni", 'birlikte izle'], 'Akıllı tekrar: 1 · 3 · 7 · 21 gün', Background(*O, 8)))
    scenes.append(ph('a01_admin_home', ['Kurum müdürü', 'paneli'], 'Lisans, koçlar, kurum görünümü', Background(*G, 9)))
    scenes.append(whitelabel_scene(Background(*O, 12)))
    scenes.append(ph('a03_admin_inactive', ['Hareketsiz öğrenciyi', 'kaçırma'], 'Bu hafta çalışmayanlar tek listede', Background(*T, 10)))
    scenes.append(brand_scene(4.6, Background('#160F3D', '#5B3CC4', 11), 'bizz_happy',
                              ['Öğrenciniz büyürken', 'siz izleyin.'], None, 'Davet kodunuzla hemen başlayın'))
    return 'mentoria_koc_mudur', scenes


def student_video():
    Y = '#5A2D0C', '#F2A93B'
    V = '#2B1F6B', '#6C4BD8'
    P = '#5B1D4F', '#E0487A'
    T = '#123B3A', '#2E9C7A'
    B = '#1D2B64', '#3D7BD9'
    scenes = [cafe_intro('build/promo/cafe_student.png', (364, 866), (395, 680), INTRO_SHOTS_STUDENT,
                         ['Bütün YKS yolculuğun', 'tek telefonda'])]
    scenes.append(brand_scene(3.6, Background('#160F3D', '#5B3CC4', 21), 'bizz_happy',
                              ['YKS yolculuğun', 'artık eğlenceli'], 'Öğrenci ve veliler için 🐝'))

    def ph(name, lines, sub, bg, focus=None, width=700):
        h = Headline(lines, sub)
        return Scene(4.4 if not focus else 5.4, bg, h, [Phone(name, W / 2, max(600, h.bottom + 70), width, focus=focus)])

    def two(a, b, lines, sub, bg):
        h = Headline(lines, sub)
        top = max(640, h.bottom + 80)
        return Scene(4.8, bg, h, [Phone(a, W * 0.30, top + 40, 560, angle=6, delay=0.25),
                                   Phone(b, W * 0.70, top, 560, angle=-6, delay=0.45)])

    scenes.append(ph('s01_home', ['Merhaba, Elif!'], 'Geri sayım, hedefler ve koçunla görüşmen', Background(*V, 22)))
    scenes.append(stat_scene(3.4, Background(*Y, 23), 7200, '', ['telifsiz soru'], 'TYT + AYT · her gün yenilenen haklar'))
    scenes.append(two('s04_learn_ayt', 's05_quiz', ['Çöz, öğren,', 'ilerle'], 'Bilgi kartları ve anında çözüm', Background(*B, 24)))
    scenes.append(ph('s06_daily', ['Günün Sorusu ☀️'], 'Her sabah 09.00 · serini büyüt', Background(*Y, 25), focus=(0.12, 2.4, 1.45)))
    scenes.append(two('s08_duel_intro', 's10_duel_result', ['Arkadaşını', 'düelloya çağır ⚔️'], 'Aynı 10 soru · eşitlikte hızlı olan kazanır',
                      Background(*P, 26)))
    scenes.append(ph('s11_score', ['Kaç puan alırım?'], 'Hedefine kaç net kaldığını hemen gör', Background(*V, 27)))
    scenes.append(ph('s14_plan', ['Haftalık planın', 'cebinde'], 'Koçun hazırlar, sen işaretlersin', Background(*T, 28)))
    scenes.append(two('s12_mistakes', 's13_garden', ['Yanlışlarını', 'unutma'], 'Hata Defteri · Odak Bahçesi', Background(*B, 29)))
    scenes.append(ph('s15_avatar', ['Başarı = ödül 🏆'], 'Avatar parçaları başarımlarla açılır', Background(*P, 30)))
    scenes.append(two('p01_parent_home', 'p03_parent_plan', ['Veliler de', 'yanında'], 'Haftalık özet her pazar bildirimde',
                      Background(*T, 31)))
    scenes.append(brand_scene(4.6, Background('#160F3D', '#5B3CC4', 32), 'bizz_happy',
                              ['Hedefine birlikte', 'uçalım!'], None, 'Mentoria ile hemen başla 🐝'))
    return 'mentoria_ogrenci_veli', scenes


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


def mux(video, music, out):
    cmd = [imageio_ffmpeg.get_ffmpeg_exe(), '-y', '-loglevel', 'error', '-i', video, '-i', music,
           '-c:v', 'copy', '-c:a', 'aac', '-b:a', '192k', '-shortest', '-movflags', '+faststart', out]
    subprocess.run(cmd, check=True)


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
    if len(sys.argv) > 2 and sys.argv[2] == '--intro':
        s = scenes[0]
        times = [0.6, 1.5, 2.5, 3.3, 3.8, 4.2, 4.5, 4.9, 5.3]
        sheet = Image.new('RGB', (len(times) * 368, 648), (20, 20, 20))
        for k, t in enumerate(times):
            sheet.paste(s.frame(t).convert('RGB').resize((360, 640), Image.LANCZOS), (k * 368, 0))
        sheet.save(f'{OUT}/{name}_intro.png')
        sys.exit(0)
    if len(sys.argv) > 2 and sys.argv[2] == '--preview':
        preview(name, scenes)
        sys.exit(0)
    path, total = render(name, scenes)
    music = f'{OUT}/{name}_music.wav'
    subprocess.run([sys.executable, os.path.join(os.path.dirname(__file__), 'make_music.py'), f'{total + 0.2:.2f}', music,
                    '11' if which == 'coach' else '5', str(HIT)], check=True)
    mux(path, music, f'{OUT}/{name}.mp4')
    print('bitti', name, f'{total:.1f} sn')
