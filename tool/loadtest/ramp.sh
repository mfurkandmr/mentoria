#!/usr/bin/env bash
# Kademeli yük: her kademe ayrı k6 çalıştırması, öncesinde/sonrasında DB
# sayaçları. Kullanım: bash ramp.sh "10 20 40 80 160" 90s
set -u
cd "$(dirname "$0")"
ANON=$(grep "^LT_ANON_KEY=" .env.local | cut -d= -f2)
STEPS=${1:-"10 20 40 80 160"}
DUR=${2:-90s}
node tokens.mjs >/dev/null
# Sunucu sağlıklı mı (veritabanına uğramayan istek 1 sn altında)?
healthy() {
  for i in $(seq 1 30); do
    t=$(curl -s -o /dev/null -m 10 -w "%{http_code} %{time_total}" -H "apikey: $ANON"       https://iruiyvfndxhkuiwbekuf.supabase.co/auth/v1/health)
    case "$t" in 200\ 0.*) return 0 ;; esac
    sleep 10
  done
  echo "sunucu toparlanmadı: $t"; exit 1
}
for r in $STEPS; do
  healthy
  sleep 30
  healthy
  node pgstats.mjs reset >/dev/null
  k6 run --quiet -e ANON_KEY="$ANON" -e STEPS="$r" -e STEP="$DUR" -e TAG="step$r" mix.js >/dev/null 2>&1
  node pgstats.mjs json "step$r" >/dev/null
  echo "kademe $r bitti"
  sleep 20
done
