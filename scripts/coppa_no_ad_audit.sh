#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

FAILED=0

echo "[COPPA no-ads audit] Checking dependency graph..."
BANNED_DEP_REGEX='google-analytics|gtag|mixpanel|segment|amplitude|hotjar|facebook-pixel|adsense|admob|doubleclick|taboola|outbrain'
if rg -n --glob "package*.json" -i "\"($BANNED_DEP_REGEX)\"" . >/tmp/coppa_no_ads_dep_hits.txt; then
  echo "Found prohibited ad/behavioral tracking dependencies:"
  cat /tmp/coppa_no_ads_dep_hits.txt
  FAILED=1
else
  echo "No prohibited ad/tracker dependencies detected."
fi

echo "[COPPA no-ads audit] Checking code patterns..."
PATTERN_REGEX='googletagmanager\.com|doubleclick\.net|adsbygoogle|adservice\.google\.com|fbq\(|gtag\(|mixpanel|amplitude|getAds|showAds|behavioral\s*profil'
if rg -n -i \
  --glob '!node_modules/**' \
  --glob '!.next/**' \
  --glob '!public/workbox-*.js' \
  --glob '!scripts/coppa_no_ad_audit.sh' \
  --glob '!apps/empire_flutter/app/web/package-lock.json' \
  "$PATTERN_REGEX" \
  app src functions public \
  >/tmp/coppa_no_ads_code_hits.txt; then
  echo "Found prohibited ad/tracker code patterns:"
  cat /tmp/coppa_no_ads_code_hits.txt
  FAILED=1
else
  echo "No prohibited ad/tracker code patterns detected."
fi

rm -f /tmp/coppa_no_ads_dep_hits.txt /tmp/coppa_no_ads_code_hits.txt

if [[ "$FAILED" -ne 0 ]]; then
  echo "[COPPA no-ads audit] FAILED"
  exit 1
fi

echo "[COPPA no-ads audit] PASSED"
