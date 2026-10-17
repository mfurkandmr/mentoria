"""Tanıtım videoları için özgün (telifsiz), yumuşak arka plan müziği.

    python tool/promo/make_music.py <saniye> <çıktı.wav> [tohum] [vuruş_sn]

76 BPM; Fmaj7 - Am7 - Dm7 - Bbmaj7. Elektrikli piyano (FM), yumuşak pad,
seyrek çan melodisi, derin bas ve çok hafif shaker; hepsi yankılı. Davul
(kick/clap) yok. [vuruş_sn] verilirse o anda yükselen bir esinti ve çan
("ekranlar telefona girdi" anı).
"""
import sys
import wave

import numpy as np

SR = 44100
BPM = 76
BEAT = 60 / BPM
BAR = 4 * BEAT

CHORDS = [  # MIDI
    [53, 57, 60, 64],  # Fmaj7
    [57, 60, 64, 67],  # Am7
    [50, 53, 57, 60],  # Dm7
    [46, 50, 53, 57],  # Bbmaj7
]
ROOTS = [41, 45, 38, 34]
# Çan melodisi: F majör pentatonik (ölçü, vuruş, nota).
MELODY = [(0, 0, 77), (0, 2.5, 76), (1, 1, 72), (1, 3, 74), (2, 0, 77), (2, 2, 81),
          (3, 1, 79), (3, 2.5, 77)]


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def adsr(n, a, d, s, r):
    a, d, r = int(a * SR), int(d * SR), int(r * SR)
    e = np.full(n, s, dtype=np.float64)
    a = min(a, n)
    e[:a] = np.linspace(0, 1, a, endpoint=False)
    dd = min(d, max(0, n - a))
    e[a:a + dd] = np.linspace(1, s, dd, endpoint=False)
    rr = min(r, n)
    e[n - rr:] *= np.linspace(1, 0, rr)
    return e


def onepole_lp(x, cutoff):
    a = 1 - np.exp(-2 * np.pi * cutoff / SR)
    # Birkaç kez uygulanan tek kutuplu filtre (vektörel, kümülatif yaklaşım).
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a * (x[i] - acc)
        y[i] = acc
    return y


def reverb_ir(seconds=2.8, seed=3):
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    env = np.exp(-t * 3.2)
    ir_l = rng.standard_normal(n) * env
    ir_r = rng.standard_normal(n) * env
    # Yüksek frekansları zamanla yumuşat (sıcak yankı).
    k = 64
    ker = np.ones(k) / k
    ir_l = np.convolve(ir_l, ker, mode='same')
    ir_r = np.convolve(ir_r, ker, mode='same')
    ir_l[: int(0.012 * SR)] = 0
    ir_r[: int(0.017 * SR)] = 0
    return ir_l / np.sqrt(np.sum(ir_l ** 2)), ir_r / np.sqrt(np.sum(ir_r ** 2))


def fft_convolve(x, h):
    n = len(x) + len(h) - 1
    N = 1 << (n - 1).bit_length()
    y = np.fft.irfft(np.fft.rfft(x, N) * np.fft.rfft(h, N), N)[: len(x)]
    return y


def ep_note(m, dur, vel=1.0):
    """FM elektrikli piyano."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = hz(m)
    index = 1.6 * np.exp(-t * 4.5) + 0.25
    mod = np.sin(2 * np.pi * f * t) * index
    car = np.sin(2 * np.pi * f * t + mod)
    tine = np.sin(2 * np.pi * f * 4 * t) * np.exp(-t * 18) * 0.12
    env = np.exp(-t * 1.6) * adsr(n, 0.004, 0.1, 1.0, 0.25)
    trem = 1 + 0.08 * np.sin(2 * np.pi * 4.2 * t)
    return (car + tine) * env * trem * vel


def bell(m, dur=2.4):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = hz(m)
    s = (np.sin(2 * np.pi * f * t) + 0.45 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t * 2.5)
         + 0.2 * np.sin(2 * np.pi * f * 5.4 * t) * np.exp(-t * 5))
    return s * np.exp(-t * 1.9) * adsr(n, 0.003, 0.05, 1, 0.3)


def main(seconds, out, seed=7, hit=None):
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    dry = np.zeros((n, 2))
    send = np.zeros((n, 2))  # yankıya giden

    def add(sig, start, gain=1.0, pan=0.0, rev=0.3):
        i = int(start * SR)
        if i >= n or i + len(sig) <= 0:
            return
        if i < 0:
            sig = sig[-i:]
            i = 0
        sig = sig[: n - i]
        l, r = gain * (1 - max(0, pan)), gain * (1 + min(0, pan))
        dry[i:i + len(sig), 0] += sig * l
        dry[i:i + len(sig), 1] += sig * r
        send[i:i + len(sig), 0] += sig * l * rev
        send[i:i + len(sig), 1] += sig * r * rev

    bars = int(np.ceil(seconds / BAR)) + 1
    for b in range(bars):
        start = b * BAR
        if start >= seconds:
            break
        ch = CHORDS[b % 4]
        root = ROOTS[b % 4]
        # Pad: çok yumuşak, yavaş açılan.
        ln = int((BAR + 1.2) * SR)
        tt = np.arange(ln) / SR
        pad = np.zeros(ln)
        for m in ch:
            for det in (-0.08, 0.07):
                f = hz(m + det)
                pad += np.sin(2 * np.pi * f * tt + rng.random() * 6) + 0.25 * np.sin(4 * np.pi * f * tt)
        pad *= adsr(ln, 1.2, 0.5, 0.85, 1.2) * 0.035
        add(pad, start - 0.3, pan=-0.3, rev=0.6)
        add(pad[::-1][::-1] * 0.9, start - 0.28, pan=0.3, rev=0.6)
        # EP: 1. vuruşta akor, 2.5 ve 4'te yumuşak tekrar.
        for beat, vel in ((0, 1.0), (1.5, 0.55), (3, 0.7)):
            for k, m in enumerate(ch):
                add(ep_note(m, BEAT * 2.2, vel) * 0.055, start + beat * BEAT + k * 0.012,
                    pan=(-0.2 + 0.13 * k), rev=0.35)
        # Bas: uzun, yumuşak kök.
        if b >= 1:
            ln = int(BAR * SR)
            tt = np.arange(ln) / SR
            bass = np.sin(2 * np.pi * hz(root) * tt) * adsr(ln, 0.05, 0.4, 0.6, 0.6)
            add(bass * 0.12, start, rev=0.05)
        # Çan melodisi (ikinci döngüden itibaren, her iki döngüde bir).
        if b >= 2 and (b // 4) % 2 == 0:
            for mb, beat, m in MELODY:
                if mb == b % 4:
                    add(bell(m) * 0.05, start + beat * BEAT, pan=0.35 if m % 2 else -0.35, rev=0.7)
        # Shaker: çok hafif sekizlikler.
        if b >= 2:
            for k in range(8):
                ln = int(0.09 * SR)
                tt = np.arange(ln) / SR
                noise = rng.standard_normal(ln)
                sh = (noise - onepole_lp(noise, 5000)) * np.exp(-tt * 45) * (1.0 if k % 2 else 0.6)
                add(sh * 0.012, start + k * BEAT / 2, pan=0.4, rev=0.15)

    if hit is not None:
        # Yükselen esinti + çan + derin "bum" (yumuşak).
        ln = int(1.6 * SR)
        noise = rng.standard_normal(ln)
        sw = onepole_lp(noise, 2500) * np.linspace(0, 1, ln) ** 2.5
        add(sw * 0.05, hit - 1.6, rev=0.5)
        for k, m in enumerate((84, 88, 91, 96)):
            add(bell(m, 3.0) * 0.045, hit + k * 0.06, pan=-0.4 + 0.27 * k, rev=0.8)
        ln = int(1.5 * SR)
        tt = np.arange(ln) / SR
        boom = np.sin(2 * np.pi * (38 + 30 * np.exp(-tt * 6)) * tt) * np.exp(-tt * 2.2)
        add(boom * 0.25, hit, rev=0.2)

    ir_l, ir_r = reverb_ir()
    wet = np.stack([fft_convolve(send[:, 0], ir_l), fft_convolve(send[:, 1], ir_r)], axis=1)
    mix = dry + wet * 0.9
    mix = np.tanh(mix * 1.3) / 1.3
    fade = np.ones(n)
    fo = int(3.0 * SR)
    fade[-fo:] = np.linspace(1, 0, fo) ** 1.6
    fi = int(1.2 * SR)
    fade[:fi] = np.linspace(0, 1, fi) ** 1.5
    mix *= fade[:, None]
    mix /= np.max(np.abs(mix)) + 1e-9
    mix *= 0.42  # arka plan: ortalama ≈ -20 dB
    data = (mix * 32767).astype('<i2')
    with wave.open(out, 'wb') as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f'{out}: {seconds:.1f} sn')


if __name__ == '__main__':
    main(float(sys.argv[1]), sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 7,
         float(sys.argv[4]) if len(sys.argv) > 4 else None)
