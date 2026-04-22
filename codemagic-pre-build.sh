#!/bin/bash
# Pre-build script per Codemagic: rimuovi google_mobile_ads dal build iOS.
# Il SDK nativo Google-Mobile-Ads-SDK causa crash SIGSEGV su iOS.
# AdMob resta in pubspec.yaml e funziona normalmente su Android.
#
# Configurazione Codemagic:
#   Workflow → Build triggers → Pre-build script:
#   ./codemagic-pre-build.sh

set -e

# 1. Strip da .flutter-plugins (formato key=value)
PLUGINS_FILE=".flutter-plugins"
if [ -f "$PLUGINS_FILE" ]; then
  sed -i.bak '/google_mobile_ads/d' "$PLUGINS_FILE"
  rm -f "${PLUGINS_FILE}.bak"
  echo "[pre-build] Stripped google_mobile_ads from $PLUGINS_FILE"
fi

# 2. Strip da .flutter-plugins-dependencies (formato JSON)
DEPS_FILE=".flutter-plugins-dependencies"
if [ -f "$DEPS_FILE" ]; then
  python3 -c "
import json, sys
with open('$DEPS_FILE', 'r') as f:
    data = json.load(f)
for platform in list(data.get('plugins', {}).keys()):
    plugins = data['plugins'][platform]
    data['plugins'][platform] = [p for p in plugins if p.get('name') != 'google_mobile_ads']
with open('$DEPS_FILE', 'w') as f:
    json.dump(data, f)
" 2>/dev/null || true
  echo "[pre-build] Stripped google_mobile_ads from $DEPS_FILE"
fi

echo "[pre-build] Done — google_mobile_ads removed from iOS build"
