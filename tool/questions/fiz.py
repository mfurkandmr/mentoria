"""TYT Fizik: formül şablonları (g = 10 m/s² alınır)."""
from common import fmt_num, make, num_distractors

T = 'TYT_FIZ'


def _opts(r, v, extra=()):
    return [fmt_num(x) for x in list(extra) + num_distractors(r, v, max(2, v // 4 + 1))]


def hiz(r):
    v, t = r.randint(2, 30), r.randint(2, 20)
    x = v * t
    return make(r, 'Hareket', f'Sabit hızla giden bir araç {t} saniyede {x} metre yol alıyor. Aracın hızı kaç m/s\'dir?',
                v, _opts(r, v, [x * t, x + t]), f'v = x / t = {x} / {t} = {v} m/s.')


def yol(r):
    v, t = r.randint(2, 25), r.randint(2, 15)
    x = v * t
    return make(r, 'Hareket', f'{v} m/s sabit hızla hareket eden bir cisim {t} saniyede kaç metre yol alır?',
                x, _opts(r, x, [v + t]), f'x = v · t = {v} · {t} = {x} m.')


def kmh(r):
    v = r.choice([18, 36, 54, 72, 90, 108, 126, 144])
    s = v * 10 // 36
    return make(r, 'Hareket', f'{v} km/h hız kaç m/s\'dir?',
                s, _opts(r, s, [v * 36 // 10, v // 10]), f'km/h → m/s için 3,6\'ya bölünür: {v} / 3,6 = {s}.')


def ivme(r):
    a, t = r.randint(1, 8), r.randint(2, 10)
    v0 = r.randint(0, 20)
    v = v0 + a * t
    return make(r, 'Hareket', f'{v0} m/s hızla giden bir araç {t} saniyede hızını düzgün olarak {v} m/s\'ye çıkarıyor. İvmesi kaç m/s²\'dir?',
                a, _opts(r, a, [v // t if t else 1, v - v0]), f'a = Δv / t = ({v} − {v0}) / {t} = {a} m/s².')


def kuvvet(r):
    m, a = r.randint(2, 20), r.randint(1, 8)
    f = m * a
    return make(r, 'Kuvvet ve hareket', f'{m} kg kütleli bir cisme {a} m/s² ivme kazandırmak için kaç N net kuvvet gerekir?',
                f, _opts(r, f, [m + a]), f'F = m · a = {m} · {a} = {f} N.')


def agirlik(r):
    m = r.randint(2, 90)
    return make(r, 'Kuvvet ve hareket', f'Kütlesi {m} kg olan bir cismin Dünya\'daki ağırlığı kaç N\'dur? (g = 10 m/s²)',
                m * 10, _opts(r, m * 10, [m, m + 10]), f'G = m · g = {m} · 10 = {m * 10} N.')


def is_(r):
    f, x = r.randint(2, 50), r.randint(2, 20)
    return make(r, 'İş, güç ve enerji', f'Bir cisme hareket yönünde {f} N\'luk kuvvet uygulanarak {x} m yol aldırılıyor. Yapılan iş kaç J\'dür?',
                f * x, _opts(r, f * x, [f + x]), f'W = F · x = {f} · {x} = {f * x} J.')


def guc(r):
    p, t = r.randint(2, 60) * 10, r.randint(2, 20)
    w = p * t
    return make(r, 'İş, güç ve enerji', f'{t} saniyede {w} J iş yapan bir motorun gücü kaç W\'tır?',
                p, _opts(r, p, [w * t]), f'P = W / t = {w} / {t} = {p} W.')


def kinetik(r):
    m, v = r.choice([2, 4, 6, 8, 10]), r.randint(1, 10)
    e = m * v * v // 2
    return make(r, 'İş, güç ve enerji', f'{m} kg kütleli bir cisim {v} m/s hızla hareket ediyor. Kinetik enerjisi kaç J\'dür?',
                e, _opts(r, e, [m * v, m * v * v]), f'Ek = ½ · m · v² = ½ · {m} · {v}² = {e} J.')


def potansiyel(r):
    m, h = r.randint(1, 20), r.randint(2, 30)
    e = m * 10 * h
    return make(r, 'İş, güç ve enerji', f'{m} kg kütleli bir cisim yerden {h} m yükseğe çıkarılıyor. Cismin yere göre potansiyel enerjisi kaç J olur? (g = 10 m/s²)',
                e, _opts(r, e, [m * h, m + h]), f'Ep = m · g · h = {m} · 10 · {h} = {e} J.')


def basinc(r):
    a = r.choice([2, 4, 5, 10, 20, 25, 50])
    p = r.randint(2, 40) * 10
    f = p * a
    return make(r, 'Basınç', f'{f} N ağırlığındaki bir cisim yere {a} m²\'lik yüzeyle temas ediyor. Yere yaptığı basınç kaç Pa\'dır?',
                p, _opts(r, p, [f * a]), f'P = F / A = {f} / {a} = {p} Pa.')


def sivi_basinc(r):
    d = r.choice([800, 1000, 1200, 13600])
    h = r.randint(1, 10)
    p = d * 10 * h
    return make(r, 'Basınç', f'Yoğunluğu {d} kg/m³ olan bir sıvının {h} m derinliğindeki sıvı basıncı kaç Pa\'dır? (g = 10 m/s²)',
                p, _opts(r, p, [d * h, d * 10]), f'P = h · d · g = {h} · {d} · 10 = {p} Pa.')


def ozkutle(r):
    d = r.choice([2, 3, 4, 5, 8, 10, 11])
    v = r.randint(2, 30)
    m = d * v
    return make(r, 'Madde ve özellikleri', f'Kütlesi {m} g, hacmi {v} cm³ olan bir maddenin özkütlesi kaç g/cm³\'tür?',
                d, _opts(r, d, [m * v]), f'd = m / V = {m} / {v} = {d} g/cm³.')


def karisim(r):
    d1, d2 = r.sample([1, 2, 3, 4, 5, 6], 2)
    if (d1 + d2) % 2:
        return None
    return make(r, 'Madde ve özellikleri', f'Özkütleleri {d1} g/cm³ ve {d2} g/cm³ olan iki sıvıdan eşit hacimler karıştırılıyor. Karışımın özkütlesi kaç g/cm³\'tür?',
                (d1 + d2) // 2, _opts(r, (d1 + d2) // 2, [d1 + d2]), f'Eşit hacimde ortalama alınır: ({d1} + {d2}) / 2 = {(d1 + d2) // 2}.')


def ohm(r):
    i, rr = r.randint(1, 10), r.randint(2, 20)
    v = i * rr
    return make(r, 'Elektrik', f'{rr} Ω\'luk bir direncin uçları arasındaki gerilim {v} V\'tur. Dirençten geçen akım kaç A\'dir?',
                i, _opts(r, i, [v * rr]), f'I = V / R = {v} / {rr} = {i} A.')


def seri(r):
    rs = [r.randint(2, 20) for _ in range(r.randint(2, 3))]
    s = sum(rs)
    return make(r, 'Elektrik', f'{", ".join(str(x) for x in rs[:-1])} ve {rs[-1]} Ω\'luk dirençler seri bağlanıyor. Eşdeğer direnç kaç Ω\'dur?',
                s, _opts(r, s), f'Seri bağlamada dirençler toplanır: {s} Ω.')


def paralel(r):
    pairs = [(a, b) for a in range(2, 31) for b in range(a, 61) if (a * b) % (a + b) == 0]
    a, b = r.choice(pairs)
    p = a * b // (a + b)
    return make(r, 'Elektrik', f'{a} Ω ve {b} Ω\'luk iki direnç paralel bağlanıyor. Eşdeğer direnç kaç Ω\'dur?',
                p, _opts(r, p, [a + b]), f'R = (R₁·R₂)/(R₁+R₂) = {a * b}/{a + b} = {p} Ω.')


def isi(r):
    m = r.randint(1, 10) * 100
    c = r.choice([1, 2, 4])
    dt = r.randint(2, 50)
    q = m * c * dt
    return make(r, 'Isı ve sıcaklık', f'{m} g kütleli, öz ısısı {c} cal/g°C olan bir maddenin sıcaklığını {dt} °C artırmak için kaç kalori ısı gerekir?',
                q, _opts(r, q, [m * dt, m * c]), f'Q = m · c · ΔT = {m} · {c} · {dt} = {q} cal.')


def dalga(r):
    f, lam = r.randint(2, 50), r.randint(1, 20)
    v = f * lam
    return make(r, 'Dalgalar', f'Frekansı {f} Hz, dalga boyu {lam} m olan bir dalganın yayılma hızı kaç m/s\'dir?',
                v, _opts(r, v, [f + lam]), f'v = λ · f = {lam} · {f} = {v} m/s.')


def periyot(r):
    t = r.choice([2, 4, 5, 10, 20, 25, 50])
    # T = 1/f; f = 1/T saniye cinsinden kesirli olur: frekansı Hz verelim
    f = t
    return make(r, 'Dalgalar', f'Frekansı {f} Hz olan bir dalganın periyodu kaç saniyedir?',
                f'1/{f}', [f'{f}', f'1/{f * 2}', f'{f * 2}', f'1/{f + 1}', '1'], f'T = 1 / f = 1/{f} s.')


def momentum(r):
    m, v = r.randint(2, 20), r.randint(2, 15)
    return make(r, 'Momentum', f'{m} kg kütleli bir cisim {v} m/s hızla hareket ediyor. Momentumu kaç kg·m/s\'dir?',
                m * v, _opts(r, m * v, [m + v]), f'p = m · v = {m} · {v} = {m * v}.')


def serbest_dusme(r):
    t = r.randint(1, 6)
    h = 5 * t * t
    return make(r, 'Serbest düşme', f'Serbest bırakılan bir cisim yere {t} saniyede düşüyor. Bırakıldığı yükseklik kaç m\'dir? (g = 10 m/s², sürtünme yok)',
                h, _opts(r, h, [10 * t, 10 * t * t]), f'h = ½ · g · t² = 5 · {t}² = {h} m.')


def kaldirma(r):
    v = r.randint(1, 20) * 100
    d = r.choice([800, 1000, 1200])
    # V cm³ → m³ ; Fk = V · d · g
    fk = v * d * 10 // 1000000
    if fk == 0 or v * d * 10 % 1000000:
        return None
    return make(r, 'Kaldırma kuvveti', f'Hacmi {v} cm³ olan bir cisim yoğunluğu {d} kg/m³ olan sıvıya tamamen batırılıyor. Cisme etki eden kaldırma kuvveti kaç N\'dur? (g = 10 m/s²)',
                fk, _opts(r, fk, [fk * 10]), f'Fk = V · d · g = {v}·10⁻⁶ · {d} · 10 = {fk} N.')


def yay(r):
    k, x = r.randint(2, 50) * 10, r.choice([1, 2, 5, 10, 20])
    # x cm → m
    f = k * x // 100
    if k * x % 100:
        return None
    return make(r, 'Kuvvet ve hareket', f'Yay sabiti {k} N/m olan bir yay {x} cm uzatılıyor. Yaydaki kuvvet kaç N\'dur?',
                f, _opts(r, f, [k * x]), f'x = {x} cm = {fmt_num(x / 100)} m; F = k · x = {k} · {fmt_num(x / 100)} = {f} N.')


def kaldirac(r):
    f1, d1 = r.randint(2, 30) * 10, r.randint(1, 5)
    d2 = r.randint(1, 5)
    if d1 == d2 or (f1 * d1) % d2:
        return None
    f2 = f1 * d1 // d2
    return make(r, 'Basit makineler', f'Bir kaldıraçta destekten {d1} m uzaktaki {f1} N\'luk yük, destekten {d2} m uzaktan uygulanan kuvvetle dengeleniyor. Uygulanan kuvvet kaç N\'dur?',
                f2, _opts(r, f2, [f1, f1 * d2 // d1 if (f1 * d2) % d1 == 0 else f1 + 10]), f'F₁ · d₁ = F₂ · d₂ → {f1} · {d1} = F · {d2} → F = {f2} N.')


def elektrik_enerji(r):
    p = r.choice([100, 200, 500, 1000, 1500, 2000])
    t = r.randint(1, 10)
    e = p * t // 1000 if p * t % 1000 == 0 else None
    if e is None:
        return None
    return make(r, 'Elektrik', f'{p} W gücündeki bir ısıtıcı {t} saat çalışırsa kaç kWh elektrik enerjisi harcar?',
                e, _opts(r, e, [p * t]), f'E = P · t = {fmt_num(p / 1000)} kW · {t} h = {e} kWh.')


GENERATORS = [(f, 1) for f in [
    hiz, yol, kmh, ivme, kuvvet, agirlik, is_, guc, kinetik, potansiyel, basinc, sivi_basinc,
    ozkutle, karisim, ohm, seri, paralel, isi, dalga, periyot, momentum, serbest_dusme, kaldirma,
    yay, kaldirac, elektrik_enerji,
]]
