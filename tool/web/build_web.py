"""Web sitesini tek klasörde toplar: tanıtım sayfası + panel + gizli demo.

    mentoria.com.tr/              site/ (tanıtım sayfası, yasal metinler)
    mentoria.com.tr/app/          Flutter web, gerçek Supabase (giriş yapılan)
    mentoria.com.tr/demo/         rol seçimi (site/demo/, bağlantı verilmez)
    mentoria.com.tr/demo/panel/   Flutter web, DEMO=true (örnek veri)

Kullanım (proje kökünden; yol ASCII olmalı, NOTLAR "APK derleme yolu"):

    python tool/web/build_web.py            # derle + topla -> build/site
    python tool/web/build_web.py --no-flutter   # yalnızca siteyi yeniden topla
    python tool/web/build_web.py --serve    # topla ve http://localhost:8790

Supabase anahtarları env.json'dan ya da SUPABASE_URL /
SUPABASE_PUBLISHABLE_KEY ortam değişkenlerinden okunur (CI). Yayın
Cloudflare Pages'e (.github/workflows/deploy-web.yml); `_redirects` panel
yollarını index.html'e çevirir, `_headers` güvenlik başlıklarını ekler.
"""

from __future__ import annotations

import argparse
import html
import http.server
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
SITE = ROOT / "site"
OUT = ROOT / "build" / "site"
LEGAL = ROOT / "assets" / "legal"

SITE_URL = os.environ.get("SITE_URL", "https://mentoria.com.tr").rstrip("/")
APP_BASE = "/app/"
DEMO_BASE = "/demo/panel/"

# Uygulamanın üst düzey yolları (lib/core/router/app_router.dart). Sunucu
# bunları ve altlarını index.html'e çevirir; Flutter dosyalarıyla (assets/,
# canvaskit/, main.dart.js ...) çakışmazlar. test/web_test.dart router'daki
# her yolun burada olduğunu denetler.
APP_ROUTES = [
    "intro",
    "setup",
    "login",
    "signup",
    "join",
    "t",
    "hesap-sil",
    "reset-password",
    "platform",
    "student",
    "coach",
    "admin",
    "parent",
]

# Yasal metinler: assets/legal (uygulamadakiyle aynı metin) -> /<yol>/
LEGAL_PAGES = {
    "gizlilik": ("gizlilik.md", "Gizlilik Politikası"),
    "aydinlatma": ("aydinlatma.md", "KVKK Aydınlatma Metni"),
    "kullanim-kosullari": ("kullanim_kosullari.md", "Kullanım Koşulları"),
}


# --------------------------------------------------------------- Flutter


def _flutter() -> str:
    exe = shutil.which("flutter") or shutil.which("flutter.bat")
    if not exe:
        sys.exit("flutter bulunamadı (PATH)")
    return exe


# Web bildirimi (isteğe bağlı): Firebase web uygulamasının ayarları. Hepsi
# tarayıcıya giden herkese açık değerler. Yoksa web bildirimi kapalı kalır.
FIREBASE_KEYS = ("FIREBASE_WEB_API_KEY", "FIREBASE_WEB_APP_ID",
                 "FIREBASE_PROJECT_ID", "FIREBASE_SENDER_ID",
                 "FIREBASE_VAPID_KEY")
FIREBASE_DEFAULTS = {"FIREBASE_PROJECT_ID": "mentoria-4939f",
                     "FIREBASE_SENDER_ID": "1075014627516"}
# firebase_core_web'in desteklediği Firebase JS sürümü (servis işçisi aynı).
FIREBASE_JS = "13.0.0"


def _env() -> dict:
    env = {}
    env_file = ROOT / "env.json"
    if env_file.exists():
        env = json.loads(env_file.read_text(encoding="utf-8"))
    for key in ("SUPABASE_URL", "SUPABASE_PUBLISHABLE_KEY", *FIREBASE_KEYS):
        if os.environ.get(key):
            env[key] = os.environ[key]
    return env


def firebase_config() -> dict | None:
    env = {**FIREBASE_DEFAULTS, **_env()}
    if not (env.get("FIREBASE_WEB_API_KEY") and env.get("FIREBASE_WEB_APP_ID")):
        return None
    return env


def _supabase_defines() -> list[str]:
    env = _env()
    for key in ("SUPABASE_URL", "SUPABASE_PUBLISHABLE_KEY"):
        if not env.get(key):
            sys.exit(f"{key} yok: env.json ya da ortam değişkeni gerekli")
    defines = [f"--dart-define={k}={env[k]}" for k in
               ("SUPABASE_URL", "SUPABASE_PUBLISHABLE_KEY")]
    fb = firebase_config()
    if fb:
        defines += [f"--dart-define={k}={fb[k]}" for k in FIREBASE_KEYS
                    if fb.get(k)]
    else:
        print("Firebase web ayarı yok: web bildirimi kapalı derleniyor")
    return defines


def build_flutter() -> None:
    flutter = _flutter()
    # --wasm: destekleyen tarayıcıda (Chrome/Edge/Firefox, yeni Safari)
    # skwasm çizer, kaydırma çok daha akıcı; desteklemeyende flutter.js
    # kendiliğinden JS + CanvasKit sürümünü yükler (NOTLAR §70).
    common = ["build", "web", "--release", "--wasm"]
    subprocess.run(
        # --source-maps: hata kaydındaki (client_errors) okunaksız satırları
        # çözmek için; harita dosyaları yayına girmez (bkz. assemble).
        [flutter, *common, "--source-maps", "--base-href", APP_BASE,
         "-o", "build/web_app",
         *_supabase_defines(),
         f"--dart-define=APP_LINK_BASE={SITE_URL}{APP_BASE.rstrip('/')}"],
        cwd=ROOT, check=True)
    subprocess.run(
        [flutter, *common, "--base-href", DEMO_BASE, "-o", "build/web_demo",
         "--dart-define=DEMO=true"],
        cwd=ROOT, check=True)


# --------------------------------------------------------------- Markdown


def _inline(text: str) -> str:
    text = html.escape(text, quote=False)
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"(?<!\*)\*(?!\s)(.+?)(?<!\s)\*(?!\*)", r"<em>\1</em>", text)
    text = re.sub(r"`(.+?)`", r"<code>\1</code>", text)
    text = re.sub(r"\[([^\]]+)\]\((https?://[^)\s]+|/[^)\s]*)\)",
                  r'<a href="\2">\1</a>', text)
    return text


def markdown_to_html(md: str) -> str:
    """assets/legal metinleri için yeterli küçük Markdown çevirici:
    başlık, paragraf, madde/sıra listesi, tablo, kalın/eğik, kod, bağlantı."""
    out: list[str] = []
    para: list[str] = []
    lines = md.replace("\r\n", "\n").split("\n")
    i = 0

    def flush() -> None:
        if para:
            out.append("<p>" + _inline(" ".join(para)) + "</p>")
            para.clear()

    while i < len(lines):
        line = lines[i]
        s = line.strip()
        if not s:
            flush()
            i += 1
            continue
        m = re.match(r"^(#{1,4})\s+(.*)$", s)
        if m:
            flush()
            level = len(m.group(1))
            out.append(f"<h{level}>{_inline(m.group(2))}</h{level}>")
            i += 1
            continue
        if s.startswith("|"):
            flush()
            rows = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                rows.append(lines[i].strip())
                i += 1
            cells = [[c.strip() for c in r.strip("|").split("|")] for r in rows]
            body = [r for r in cells if not all(re.fullmatch(r":?-{2,}:?", c)
                                                 for c in r)]
            out.append('<div class="table"><table>')
            for n, row in enumerate(body):
                tag = "th" if n == 0 else "td"
                out.append("<tr>" + "".join(
                    f"<{tag}>{_inline(c)}</{tag}>" for c in row) + "</tr>")
            out.append("</table></div>")
            continue
        lm = re.match(r"^(\s*)([-*]|\d+[.)])\s+(.*)$", line)
        if lm:
            flush()
            ordered = lm.group(2)[0].isdigit()
            tag = "ol" if ordered else "ul"
            out.append(f"<{tag}>")
            item: list[str] = []
            while i < len(lines):
                cur = lines[i]
                cm = re.match(r"^(\s*)([-*]|\d+[.)])\s+(.*)$", cur)
                if cm:
                    if item:
                        out.append("<li>" + _inline(" ".join(item)) + "</li>")
                    item = [cm.group(3)]
                elif cur.strip() and cur.startswith((" ", "\t")):
                    item.append(cur.strip())
                else:
                    break
                i += 1
            if item:
                out.append("<li>" + _inline(" ".join(item)) + "</li>")
            out.append(f"</{tag}>")
            continue
        if s.startswith(">"):
            flush()
            out.append("<blockquote>" + _inline(s.lstrip("> ")) + "</blockquote>")
            i += 1
            continue
        para.append(s)
        i += 1
    flush()
    return "\n".join(out)


# --------------------------------------------------------------- Toplama


def _redirects() -> str:
    lines = ["# tool/web/build_web.py üretir; elle düzenlemeyin.",
             "# Panel yolları (Flutter, adres çubuğunda '#' yok) index.html'e."]
    for base in (APP_BASE, DEMO_BASE):
        for r in APP_ROUTES:
            lines.append(f"{base}{r}  {base}index.html  200")
        for r in APP_ROUTES:
            lines.append(f"{base}{r}/*  {base}index.html  200")
    return "\n".join(lines) + "\n"


def service_worker(fb: dict) -> str:
    """Sitenin kökündeki FCM servis işçisi: sayfa kapalıyken gelen bildirimi
    gösterir; dokununca send-push'un verdiği adresi (webpush.fcm_options.link)
    açar. Firebase JS kendi kapsamını kullanır, sayfa isteklerine karışmaz."""
    cfg = {
        "apiKey": fb["FIREBASE_WEB_API_KEY"],
        "appId": fb["FIREBASE_WEB_APP_ID"],
        "projectId": fb["FIREBASE_PROJECT_ID"],
        "messagingSenderId": fb["FIREBASE_SENDER_ID"],
    }
    base = f"https://www.gstatic.com/firebasejs/{FIREBASE_JS}"
    lines = [
        "// tool/web/build_web.py üretir; elle düzenlemeyin.",
        f"importScripts('{base}/firebase-app-compat.js');",
        f"importScripts('{base}/firebase-messaging-compat.js');",
        f"firebase.initializeApp({json.dumps(cfg)});",
        "firebase.messaging();",
    ]
    return "".join(line + "\n" for line in lines)


HEADERS = """# tool/web/build_web.py üretir; elle düzenlemeyin.
/*
  X-Content-Type-Options: nosniff
  Referrer-Policy: strict-origin-when-cross-origin
  X-Frame-Options: DENY
  Permissions-Policy: geolocation=(), microphone=(), payment=(), usb=()
  Strict-Transport-Security: max-age=31536000

/app/*
  X-Robots-Tag: noindex, nofollow

/demo/*
  X-Robots-Tag: noindex, nofollow

/firebase-messaging-sw.js
  Cache-Control: no-cache
"""


def assemble() -> None:
    if OUT.exists():
        shutil.rmtree(OUT)
    shutil.copytree(SITE, OUT, ignore=shutil.ignore_patterns("_legal.html"))
    for src, dst in (("build/web_app", "app"), ("build/web_demo", "demo/panel")):
        path = ROOT / src
        if not (path / "index.html").exists():
            sys.exit(f"{src} yok: önce --no-flutter olmadan çalıştırın")
        shutil.copytree(path, OUT / dst, dirs_exist_ok=True,
                        ignore=shutil.ignore_patterns("*.map"))
    # Kaynak haritaları yayına değil build/web_sourcemaps'e (CI'da artifact):
    # tool/web/symbolize.mjs hata yığınını bunlarla çözer.
    maps = ROOT / "build" / "web_sourcemaps"
    if maps.exists():
        shutil.rmtree(maps)
    for m in (ROOT / "build" / "web_app").glob("*.map"):
        maps.mkdir(parents=True, exist_ok=True)
        shutil.copy(m, maps / m.name)

    template = (SITE / "_legal.html").read_text(encoding="utf-8")
    for slug, (md_name, title) in LEGAL_PAGES.items():
        md = (LEGAL / md_name).read_text(encoding="utf-8")
        md = re.sub(r"^# .*\n", "", md, count=1)  # başlık şablonda
        page = (template.replace("{{title}}", html.escape(title))
                .replace("{{content}}", markdown_to_html(md)))
        (OUT / slug).mkdir(parents=True, exist_ok=True)
        (OUT / slug / "index.html").write_text(page, encoding="utf-8")

    # Sitenin yazı tipi: uygulamayla gelen Poppins (Google'a istek gitmez, KVKK).
    fonts = OUT / "fonts"
    fonts.mkdir(exist_ok=True)
    for w in ("Regular", "Medium", "SemiBold", "Bold"):
        shutil.copy(ROOT / "assets" / "google_fonts" / f"Poppins-{w}.ttf", fonts)
    shutil.copy(ROOT / "assets" / "brand" / "bizz.svg", OUT / "img" / "bizz.svg")
    shutil.copy(ROOT / "web" / "favicon.png", OUT / "favicon.png")
    shutil.copy(ROOT / "web" / "icons" / "Icon-192.png", OUT / "img" / "icon.png")

    fb = firebase_config()
    if fb:
        (OUT / "firebase-messaging-sw.js").write_text(
            service_worker(fb), encoding="utf-8")

    (OUT / "_redirects").write_text(_redirects(), encoding="utf-8")
    (OUT / "_headers").write_text(HEADERS, encoding="utf-8")
    pages = ["/", *[f"/{s}/" for s in LEGAL_PAGES]]
    (OUT / "sitemap.xml").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
        + "".join(f"  <url><loc>{SITE_URL}{p}</loc></url>\n" for p in pages)
        + "</urlset>\n", encoding="utf-8")
    print(f"site hazır: {OUT}")


# --------------------------------------------------------------- Önizleme


def serve(port: int) -> None:
    """Cloudflare Pages gibi davranan yerel sunucu: dosya varsa onu, yoksa
    _redirects kuralını, o da yoksa 404.html'i verir."""
    rules = []
    for line in (OUT / "_redirects").read_text(encoding="utf-8").splitlines():
        if line.strip() and not line.startswith("#"):
            src, dst, _ = line.split()
            rules.append((src, dst))

    class Handler(http.server.SimpleHTTPRequestHandler):
        # Windows kayıt defteri .mjs'i text/plain verebiliyor; tarayıcı da
        # modülü reddediyor (wasm sürümü açılmıyor). Cloudflare doğru verir.
        extensions_map = {
            **http.server.SimpleHTTPRequestHandler.extensions_map,
            ".mjs": "text/javascript",
            ".js": "text/javascript",
            ".wasm": "application/wasm",
        }

        def __init__(self, *a, **kw):
            super().__init__(*a, directory=str(OUT), **kw)

        def send_head(self):
            path = self.path.split("?", 1)[0]
            target = OUT / path.lstrip("/")
            if not (target.is_file() or (target / "index.html").is_file()):
                for src, dst in rules:
                    if src.endswith("/*"):
                        hit = path.startswith(src[:-1])
                    else:
                        hit = path == src
                    if hit:
                        self.path = dst
                        break
                else:
                    self.path = "/404.html"
            return super().send_head()

    print(f"http://localhost:{port}/  (durdurmak için Ctrl+C)")
    http.server.ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()


def main() -> None:
    # Windows konsolu (cp1252) Türkçe harfleri basamıyor.
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--no-flutter", action="store_true",
                    help="Flutter derlemesini atla (build/web_app, web_demo var)")
    ap.add_argument("--serve", action="store_true", help="yerel önizleme")
    ap.add_argument("--port", type=int, default=8790)
    args = ap.parse_args()
    if not args.no_flutter:
        build_flutter()
    assemble()
    if args.serve:
        serve(args.port)


if __name__ == "__main__":
    main()
