"""Tanıtım videoları için özgün (telifsiz) müzik: numpy ile sentez.

    python tool/promo/make_music.py <saniye> <çıktı.wav> [tohum]

112 BPM, Dm - Bb - F - C. Pad, pluck arpej, bas, kick, clap, hi-hat;
sidechain, giriş (davulsuz) ve sonda akorun sönmesi.
"""
import sys
import wave

import numpy as np

SR = 44100
BPM = 112
BEAT = 60 / BPM
BAR = 4 * BEAT

# Akorlar (MIDI): Dm, Bb, F, C
CHORDS = [
    [50, 53, 57, 62],
    [46, 50, 53, 58],
    [41, 45, 48, 53],
    [48, 52, 55, 60],
]
ROOTS = [38, 34, 41, 36]


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def env_adsr(n, a, d, s, r):
    a, d, r = int(a * SR), int(d * SR), int(r * SR)
    e = np.full(n, s, dtype=np.float64)
    a = min(a, n)
    e[:a] = np.linspace(0, 1, a, endpoint=False)
    dd = min(d, max(0, n - a))
    e[a:a + dd] = np.linspace(1, s, dd, endpoint=False)
    rr = min(r, n)
    e[n - rr:] *= np.linspace(1, 0, rr)
    return e


def lowpass(x, cutoff):
    # Tek kutuplu alçak geçiren (zamanla değişebilen kesim frekansı).
    cutoff = np.broadcast_to(cutoff, x.shape)
    a = 1 - np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a[i] * (x[i] - acc)
        y[i] = acc
    return y


def saw(f, t, rng):
    ph = rng.random()
    return 2 * ((f * t + ph) % 1.0) - 1


def main(seconds, out, seed=7):
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    t_all = np.arange(n) / SR
    L = np.zeros(n)
    R = np.zeros(n)
    bars = int(np.ceil(seconds / BAR))
    intro_bars = 2
    # Ortada 1 ölçü davulsuz nefes.
    break_bar = bars // 2 if bars > 8 else -1

    def add(sig, start, gain=1.0, pan=0.0):
        i = int(start * SR)
        if i >= n:
            return
        sig = sig[: n - i]
        L[i:i + len(sig)] += sig * gain * (1 - max(0, pan))
        R[i:i + len(sig)] += sig * gain * (1 + min(0, pan))

    side = np.ones(n)  # sidechain zarfı (kick'te düşer)

    for b in range(bars):
        start = b * BAR
        chord = CHORDS[b % 4]
        root = ROOTS[b % 4]
        drums = b >= intro_bars and b != break_bar and start < seconds - BAR

        # Pad: her nota için 3 dedune saw, yumuşak filtre.
        ln = int(BAR * SR) + int(0.6 * SR)
        tt = np.arange(ln) / SR
        pad = np.zeros(ln)
        for m in chord:
            for det in (-0.12, 0.0, 0.11):
                pad += saw(hz(m + det), tt, rng)
        open_ = min(1.0, (b + 1) / (intro_bars + 1))
        pad = lowpass(pad, 500 + 1600 * open_) * env_adsr(ln, 0.35, 0.3, 0.8, 0.6) * 0.045
        add(pad, start, pan=-0.25)
        add(np.concatenate([np.zeros(int(0.012 * SR)), pad])[:ln], start, pan=0.25)

        # Pluck arpej: 16'lık, akor notaları bir oktav yukarı.
        pattern = [0, 2, 1, 3, 2, 1, 3, 2, 0, 2, 1, 3, 2, 3, 1, 2]
        step = BEAT / 4
        for k, idx in enumerate(pattern):
            if b < 1 and k % 2:
                continue
            m = chord[idx] + 12
            dur = 0.32
            tn = np.arange(int(dur * SR)) / SR
            f = hz(m)
            tone = (np.sin(2 * np.pi * f * tn) + 0.35 * np.sin(4 * np.pi * f * tn)
                    + 0.12 * np.sin(6 * np.pi * f * tn)) * np.exp(-tn * 11)
            add(tone * 0.10, start + k * step, pan=0.45 if k % 2 else -0.45)

        if drums:
            # Bas: sekizlikler, kök nota (oktav sıçramalı).
            for k in range(8):
                m = root + (12 if k in (3, 7) else 0)
                dur = BEAT / 2 * 0.9
                tn = np.arange(int(dur * SR)) / SR
                f = hz(m)
                tone = np.tanh(2.2 * np.sin(2 * np.pi * f * tn)) * env_adsr(len(tn), 0.005, 0.08, 0.7, 0.04)
                add(tone * 0.16, start + k * BEAT / 2)
            for k in range(4):
                ts = start + k * BEAT
                # Kick
                tn = np.arange(int(0.42 * SR)) / SR
                fsw = 45 + 110 * np.exp(-tn * 30)
                kick = np.sin(2 * np.pi * np.cumsum(fsw) / SR) * np.exp(-tn * 7.5)
                add(kick * 0.55, ts)
                i0 = int(ts * SR)
                dl = int(0.28 * SR)
                side[i0:i0 + dl] = np.minimum(side[i0:i0 + dl], 0.35 + 0.65 * np.linspace(0, 1, len(side[i0:i0 + dl])) ** 1.5)
                # Clap: 2 ve 4.
                if k in (1, 3):
                    tn = np.arange(int(0.25 * SR)) / SR
                    noise = rng.standard_normal(len(tn))
                    clap = (noise - lowpass(noise, 900)) * np.exp(-tn * 18)
                    add(clap * 0.16, ts, pan=0.1)
                    add(clap * 0.08, ts + 0.012, pan=-0.2)
                # Hi-hat: ara vuruşlar.
                for off, g in ((0.5, 0.075), (0.25, 0.03), (0.75, 0.03)):
                    tn = np.arange(int(0.06 * SR)) / SR
                    noise = rng.standard_normal(len(tn))
                    hat = (noise - lowpass(noise, 6000)) * np.exp(-tn * 70)
                    add(hat * g, ts + off * BEAT, pan=0.3)

    # Giriş öncesi yükselen "swoosh" (davul girmeden).
    sw_len = int(BAR * 0.9 * SR)
    noise = rng.standard_normal(sw_len)
    swoosh = lowpass(noise, np.linspace(300, 7000, sw_len)) * np.linspace(0, 1, sw_len) ** 2
    add(swoosh * 0.07, intro_bars * BAR - BAR * 0.9)

    L *= side
    R *= side
    mix = np.stack([L, R], axis=1)
    mix = np.tanh(mix * 1.6) / 1.2
    # Son 2,5 sn sönüm, başta kısa giriş.
    fade = np.ones(n)
    fo = int(2.5 * SR)
    fade[-fo:] = np.linspace(1, 0, fo) ** 1.4
    fade[: int(0.05 * SR)] = np.linspace(0, 1, int(0.05 * SR))
    mix *= fade[:, None]
    mix /= np.max(np.abs(mix)) + 1e-9
    mix *= 0.89
    data = (mix * 32767).astype('<i2')
    with wave.open(out, 'wb') as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f'{out}: {seconds:.1f} sn')


if __name__ == '__main__':
    main(float(sys.argv[1]), sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 7)
