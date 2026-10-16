"""Mentoria'nın kendi seslerini sentezler (telifsiz, uygulamaya özel).

  bizz_tap.wav : Bızz'a dokununca: kısa "bızzt" vızıltısı + iki neşeli tını
  intro.wav    : açılış: Bızz uçarak yaklaşırken vızıltı, konunca 3 notalık çan

  pomodoro_*.wav: pomodoro bitiş zilleri (bal, vizilti, kristal, marimba, gong)

Kullanım: python tool/make_sounds.py assets/sounds android/app/src/main/res/raw
"""
import math
import random
import struct
import sys
import wave

SR = 22050
random.seed(7)


def silence(sec):
    return [0.0] * int(SR * sec)


def mix(dst, src, at):
    start = int(SR * at)
    need = start + len(src)
    if len(dst) < need:
        dst.extend([0.0] * (need - len(dst)))
    for i, v in enumerate(src):
        dst[start + i] += v


def buzz(sec, f0, f1, amp=0.5, attack=0.03, release=0.06, flutter=11.0):
    """Arı vızıltısı: bant sınırlı testere dişi (zengin harmonikler), hafif
    vibrato ve kanat çırpışı gibi genlik dalgalanması. Frekans f0→f1 kayar."""
    n = int(SR * sec)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / SR
        k = i / max(1, n - 1)
        f = f0 + (f1 - f0) * (k * k * (3 - 2 * k))  # yumuşak kayma
        f *= 1 + 0.012 * math.sin(2 * math.pi * 6.5 * t)  # vibrato
        phase += 2 * math.pi * f / SR
        s = 0.0
        for h in range(1, 9):
            s += math.sin(phase * h) / h * (0.92 ** h)
        am = 0.78 + 0.22 * math.sin(2 * math.pi * flutter * t)
        env = min(1.0, t / attack) * min(1.0, (sec - t) / release)
        out.append(s * am * env * amp)
    return out


def bell(f, sec, amp=0.5, decay=6.0):
    """Bal kavanozuna vuran kaşık gibi tatlı bir tını: temel + yumuşak
    çan kısmileri, hızlı atak, üstel sönüm."""
    n = int(SR * sec)
    partials = [(1.0, 1.0), (2.0, 0.35), (2.76, 0.18), (4.07, 0.08)]
    out = []
    for i in range(n):
        t = i / SR
        env = min(1.0, t / 0.004) * math.exp(-decay * t)
        s = 0.0
        for mult, a in partials:
            s += a * math.exp(-decay * (mult - 1) * 0.35 * t) * math.sin(2 * math.pi * f * mult * t)
        out.append(s * env * amp)
    return out


def normalize(sig, peak=0.82):
    m = max(abs(v) for v in sig) or 1.0
    return [v / m * peak for v in sig]


def fade_tail(sig, sec=0.03):
    n = int(SR * sec)
    for i in range(n):
        sig[-1 - i] *= i / n
    return sig


def write(path, sig):
    sig = fade_tail(normalize(sig))
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, v)) * 32767)) for v in sig))


def tap():
    # "Bızzt!" (yükselen), ardından iki tını: Do6 → Sol6 (kıkırdama gibi).
    s = buzz(0.20, 230, 400, amp=0.42, attack=0.015, release=0.05, flutter=14)
    mix(s, bell(1046.5, 0.30, amp=0.55, decay=9), 0.17)
    mix(s, bell(1568.0, 0.42, amp=0.50, decay=7), 0.27)
    return s + silence(0.02)


def intro():
    # Bızz uzaktan yaklaşır (vızıltı yükselir ve incelir), ~1,1 sn'de konar;
    # konunca Sol5–Do6–Mi6 çan arpeji ve kısa bir mutlu vızıltı.
    s = buzz(1.15, 180, 260, amp=0.30, attack=0.45, release=0.12, flutter=9)
    for (f, at, a) in [(783.99, 1.08, 0.50), (1046.5, 1.20, 0.52), (1318.5, 1.32, 0.55)]:
        mix(s, bell(f, 0.9, amp=a, decay=4.5), at)
    mix(s, buzz(0.16, 300, 420, amp=0.18, attack=0.02, release=0.05, flutter=16), 1.45)
    return s + silence(0.05)


# --- Pomodoro bitiş zilleri (5 farklı karakter) ---------------------------

def marimba(f, sec, amp=0.5):
    """Tahta tokmak: temel + 4. ve 10. kısmiler, çok hızlı sönüm."""
    n = int(SR * sec)
    out = []
    for i in range(n):
        t = i / SR
        env = min(1.0, t / 0.002)
        s = (math.exp(-7 * t) * math.sin(2 * math.pi * f * t)
             + 0.35 * math.exp(-22 * t) * math.sin(2 * math.pi * f * 4 * t)
             + 0.12 * math.exp(-40 * t) * math.sin(2 * math.pi * f * 10 * t))
        out.append(s * env * amp)
    return out


def gong(f, sec, amp=0.6):
    """Derin, yavaş açılan gong: uyumsuz kısmiler ve hafif dalgalanma."""
    n = int(SR * sec)
    partials = [(1.0, 1.0), (1.48, 0.6), (2.03, 0.45), (2.74, 0.3), (3.6, 0.18), (4.9, 0.1)]
    out = []
    for i in range(n):
        t = i / SR
        env = min(1.0, t / 0.06) * math.exp(-1.6 * t)
        s = 0.0
        for k, (m, a) in enumerate(partials):
            beat = 1 + 0.15 * math.sin(2 * math.pi * (1.3 + k * 0.4) * t)
            s += a * beat * math.exp(-0.5 * k * t) * math.sin(2 * math.pi * f * m * t)
        out.append(s * env * amp)
    return out


def tone_bal():
    # Bal Kavanozu: sıcak çan arpeji (Do–Mi–Sol–Do), iki kez.
    s = []
    for rep in range(2):
        for k, f in enumerate([523.25, 659.25, 783.99, 1046.5]):
            mix(s, bell(f, 1.2, amp=0.5, decay=3.5), rep * 1.1 + k * 0.16)
    return s + silence(0.1)


def tone_vizilti():
    # Arı Vızıltısı: iki kısa "bızzt", ardından neşeli iki tını; iki kez.
    s = []
    for rep in range(2):
        b = rep * 1.05
        mix(s, buzz(0.16, 240, 380, amp=0.4, attack=0.01, release=0.04, flutter=15), b)
        mix(s, buzz(0.16, 260, 420, amp=0.4, attack=0.01, release=0.04, flutter=15), b + 0.22)
        mix(s, bell(1174.7, 0.5, amp=0.55, decay=6), b + 0.42)
        mix(s, bell(1568.0, 0.6, amp=0.5, decay=5), b + 0.55)
    return s + silence(0.1)


def tone_kristal():
    # Kristal: hızlı, parlak tiz tınılar (bardak tıngırtısı).
    s = []
    notes = [2093.0, 2637.0, 3136.0, 2637.0, 2093.0, 3136.0, 4186.0]
    for k, f in enumerate(notes):
        mix(s, bell(f, 0.6, amp=0.35, decay=9), k * 0.12)
    mix(s, bell(4186.0, 1.2, amp=0.3, decay=4), 0.95)
    return s + silence(0.1)


def tone_marimba():
    # Marimba: tahta tokmakla neşeli bir melodi.
    s = []
    melody = [(784.0, 0.0), (987.8, 0.16), (1174.7, 0.32), (987.8, 0.48),
              (1174.7, 0.64), (1568.0, 0.84)]
    for f, at in melody:
        mix(s, marimba(f, 0.7, amp=0.55), at)
    for f, at in melody:
        mix(s, marimba(f, 0.7, amp=0.45), at + 1.2)
    return s + silence(0.1)


def tone_gong():
    # Gong: derin, sakin, yavaşça sönen tek vuruş + yumuşak ikinci vuruş.
    s = gong(98.0, 2.6, amp=0.7)
    mix(s, gong(146.8, 1.6, amp=0.35), 0.9)
    return s


def thud(sec, f0=150, f1=70, amp=0.6):
    """Yumuşak "bonk": hızla pesleşen kısa bir vuruş."""
    n = int(SR * sec)
    out, ph = [], 0.0
    for i in range(n):
        t = i / SR
        f = f1 + (f0 - f1) * math.exp(-t * 30)
        ph += 2 * math.pi * f / SR
        out.append(math.sin(ph) * math.exp(-t * 22) * min(1.0, t / 0.002) * amp)
    return out


def bump():
    # Arı değişimi (telefonu sallayınca): yaklaşan vızıltı (~0,55 sn),
    # "bonk" çarpma, savrulan arının inen vızıltısı, yeni arının kıkırdaması.
    # Çarpma anı uygulamadaki animasyonla aynı: BizzSwap.impactAt × 1,7 sn.
    s = buzz(0.56, 170, 330, amp=0.34, attack=0.35, release=0.02, flutter=12)
    mix(s, thud(0.25), 0.54)
    mix(s, bell(880.0, 0.25, amp=0.25, decay=14), 0.55)
    mix(s, buzz(0.45, 420, 200, amp=0.2, attack=0.01, release=0.2, flutter=17), 0.6)
    mix(s, bell(1318.5, 0.35, amp=0.45, decay=8), 1.05)
    mix(s, bell(1760.0, 0.5, amp=0.42, decay=6), 1.16)
    return s + silence(0.05)


def notification():
    # Mentoria bildirimi: kısa bir "bızt" ve bal damlası gibi iki tını
    # (Mi6 → La6), sonda yumuşak bir yankı. Kısa ve tanınır olsun (~0,9 sn).
    s = buzz(0.09, 300, 360, amp=0.22, attack=0.01, release=0.03, flutter=18)
    mix(s, bell(1318.5, 0.45, amp=0.55, decay=8), 0.07)
    mix(s, bell(1760.0, 0.75, amp=0.55, decay=5.5), 0.19)
    mix(s, bell(2637.0, 0.5, amp=0.12, decay=7), 0.21)
    return s + silence(0.05)


TONES = {
    'bal': tone_bal,
    'vizilti': tone_vizilti,
    'kristal': tone_kristal,
    'marimba': tone_marimba,
    'gong': tone_gong,
}


if __name__ == '__main__':
    out = sys.argv[1]
    # İsteğe bağlı 2. klasör: Android bildirim sesleri (res/raw).
    raw = sys.argv[2] if len(sys.argv) > 2 else None
    write(f'{out}/bizz_tap.wav', tap())
    write(f'{out}/intro.wav', intro())
    write(f'{out}/bizz_bump.wav', bump())
    # Bildirim sesi: uygulama içi kart (assets) + telefon bildirimi (res/raw).
    write(f'{out}/mentoria_bildirim.wav', notification())
    if raw:
        write(f'{raw}/mentoria_bildirim.wav', notification())
    for name, make in TONES.items():
        sig = make()
        write(f'{out}/pomodoro_{name}.wav', sig)
        if raw:
            write(f'{raw}/pomodoro_{name}.wav', make())
    print('ok')
