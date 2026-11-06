#!/usr/bin/env bash
# Creates the Google Play upload key and prints the values for the GitHub
# repository secrets. Run once on your own computer (needs a JDK for keytool).
# Keep the .jks file and passwords somewhere safe; never commit them.
set -euo pipefail
KEYSTORE=${1:-goabacus-upload.jks}
ALIAS=upload
read -r -s -p "Choose a keystore password (6+ chars): " PASS; echo
keytool -genkeypair -v -keystore "$KEYSTORE" -storetype JKS -keyalg RSA -keysize 2048 \
  -validity 10000 -alias "$ALIAS" -storepass "$PASS" -keypass "$PASS" \
  -dname "CN=GoAbacUs"
echo
echo "Add these secrets in GitHub: Settings > Secrets and variables > Actions"
echo "  ANDROID_KEY_ALIAS         = $ALIAS"
echo "  ANDROID_KEYSTORE_PASSWORD = (the password you typed)"
echo "  ANDROID_KEY_PASSWORD      = (the same password)"
echo "  ANDROID_KEYSTORE_BASE64   = contents of ${KEYSTORE}.base64 (written now)"
base64 -w0 "$KEYSTORE" > "${KEYSTORE}.base64" 2>/dev/null || base64 -i "$KEYSTORE" -o "${KEYSTORE}.base64"
