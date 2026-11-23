#!/usr/bin/env python3
"""Yayın sonrası duman testi (NOTLAR §107): canlı siteyi dışarıdan, zararsız GET isteğiyle denetler.

Kullanım:
    python tool/web/smoke_test.py                       # https://mentoria.com.tr
    python tool/web/smoke_test.py https://xyz.pages.dev # önizleme adresi

Çıkış kodu 0: hepsi geçti, 1: en az biri başarısız. Yalnızca standart kütüphane; yük bindirmez
(her adres bir kez istenir).
"""
import re
import sys
import urllib.error
import urllib.request

# Windows konsolu (cp1252) Türkçe karakterlerde çökmesin.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

BASE = (sys.argv[1] if len(sys.argv) > 1 else "https://mentoria.com.tr").rstrip("/")
failures = 0


def get(path, method="GET"):
    req = urllib.request.Request(BASE + path, method=method,
                                 headers={"User-Agent": "mentoria-smoke/1"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, r.headers, r.read() if method == "GET" else b""
    except urllib.error.HTTPError as e:
        return e.code, e.headers, b""


def check(ok, name, info=""):
    global failures
    if not ok:
        failures += 1
    print(("  PASS " if ok else "  FAIL ") + name + (f"  [{info}]" if info and not ok else ""))


print(f"Duman testi: {BASE}")

# Ana sayfa: açılıyor, sıkı CSP var.
st, h, body = get("/")
check(st == 200, "ana sayfa 200", st)
csp = h.get("Content-Security-Policy", "")
check("script-src 'self'" in csp and "frame-ancestors 'none'" in csp, "ana sayfada CSP", csp[:80])
check("unsafe-inline" not in re.sub(r"style-src-attr 'unsafe-inline'", "", csp), "ana sayfa CSP'sinde unsafe-inline yok (stil özniteliği hariç)")
check(b"<script>" not in body.lower().replace(b"<script src", b""), "ana sayfada satır içi script yok")

# Paneller: açılıyor, panel CSP'si wasm için eval içermiyor, kendi sunucudan CanvasKit.
for path in ("/app/", "/demo/panel/"):
    st, h, body = get(path)
    check(st == 200, f"{path} 200", st)
    csp = h.get("Content-Security-Policy", "")
    check("'wasm-unsafe-eval'" in csp and "'unsafe-eval'" not in csp.replace("'wasm-unsafe-eval'", ""),
          f"{path} CSP: wasm-unsafe-eval var, unsafe-eval yok", csp[:80])
    check("frame-ancestors 'none'" in csp and "object-src 'none'" in csp, f"{path} CSP: frame ve object kapalı")
    check(b"gstatic.com/flutter-canvaskit" not in body, f"{path} CanvasKit Google CDN'inden istenmiyor")

st, h, boot = get("/app/flutter_bootstrap.js")
# Önyükleyici kodunda Google adresi varsayılan olarak durur; asıl ölçüt yapılandırmadaki
# useLocalCanvasKit bayrağı (derleme --no-web-resources-cdn ile alındı).
check(st == 200 and b'"useLocalCanvasKit":true' in boot, "/app önyükleyici CanvasKit'i kendi sunucudan yükler", st)
st, _, _ = get("/app/canvaskit/skwasm.wasm", "HEAD")
check(st == 200, "CanvasKit (skwasm.wasm) kendi sunucudan geliyor", st)

# Sızıntı: kaynak haritası, .env, .git.
for path in ("/app/main.dart.js.map", "/.env", "/.git/config", "/app/.env", "/env.json"):
    st, _, body = get(path)
    # SPA yönlendirmesi 200 + index.html dönebilir; asıl ölçüt gövdede sır / harita olmaması.
    leaked = st == 200 and (b'"sources"' in body[:2000] or b"SUPABASE" in body[:2000] or b"[core]" in body[:200])
    check(not leaked, f"{path} sızdırmıyor", st)

# security.txt.
st, h, body = get("/.well-known/security.txt")
check(st == 200 and b"Contact:" in body and b"Expires:" in body, "security.txt geçerli", st)
m = re.search(rb"Expires:\s*(\d{4})-(\d{2})-(\d{2})", body)
if m:
    import datetime
    exp = datetime.date(int(m.group(1)), int(m.group(2)), int(m.group(3)))
    check((exp - datetime.date.today()).days > 14, "security.txt süresi 14 günden fazla var", exp)

# Güvenlik başlıkları (tüm sayfalarda).
st, h, _ = get("/")
check("max-age" in h.get("Strict-Transport-Security", ""), "HSTS var")
check(h.get("X-Content-Type-Options", "").lower() == "nosniff", "nosniff var")

print("\nHEPSİ GEÇTİ" if failures == 0 else f"\n{failures} KONTROL BAŞARISIZ")
sys.exit(1 if failures else 0)
