#!/usr/bin/env bash
# Prepares code signing on a GitHub Actions macOS runner.
#
# Supports two setups (both from encrypted repository secrets, never committed):
#   A) Manual signing: a distribution certificate (.p12, base64) + its password + a provisioning
#      profile (.mobileprovision, base64). Team ID, bundle ID and export method are read from the
#      profile itself.
#   B) Automatic (cloud) signing: an App Store Connect API key (key ID, issuer ID, .p8 contents)
#      plus your Apple Team ID. Xcode creates/updates certificates and profiles itself.
#
# Writes Config/Signing.generated.xcconfig and build/ExportOptions.plist, and exports
# SIGNING_MODE, EXPORT_METHOD, BUNDLE_ID, XCODE_AUTH_ARGS to $GITHUB_ENV.
set -euo pipefail

mkdir -p build
RUNNER_TEMP="${RUNNER_TEMP:-$(mktemp -d)}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"

have() { [ -n "${!1:-}" ]; }
yesno() { if have "$1"; then echo "found"; else echo "missing"; fi; }

echo "Signing inputs (values are never printed):"
echo "  Distribution certificate (.p12):  $(yesno CERT_P12_BASE64)"
echo "  Certificate password:             $(yesno CERT_PASSWORD)"
echo "  Provisioning profile:             $(yesno PROFILE_BASE64)"
echo "  App Store Connect API key ID:     $(yesno ASC_KEY_ID)"
echo "  App Store Connect issuer ID:      $(yesno ASC_ISSUER_ID)"
echo "  App Store Connect API key (.p8):  $(yesno ASC_KEY)"
echo "  Apple Team ID:                    $(yesno TEAM_ID)"
echo "  Bundle ID override:               $(yesno BUNDLE_ID_SECRET)"

decode_b64() {
  # Accept base64 with or without line breaks.
  printf '%s' "$1" | tr -d '\r\n ' | base64 --decode
}

AUTH_ARGS=""
# Trim stray whitespace/newlines that often sneak into pasted secrets.
ASC_KEY_ID="$(printf '%s' "${ASC_KEY_ID:-}" | tr -d '[:space:]')"
ASC_ISSUER_ID="$(printf '%s' "${ASC_ISSUER_ID:-}" | tr -d '[:space:]')"
TEAM_ID="$(printf '%s' "${TEAM_ID:-}" | tr -d '[:space:]')"
if have ASC_KEY_ID && have ASC_ISSUER_ID && have ASC_KEY; then
  KEY_DIR="$HOME/.appstoreconnect/private_keys"
  mkdir -p "$KEY_DIR"
  KEY_PATH="$KEY_DIR/AuthKey_${ASC_KEY_ID}.p8"
  # Rebuild a clean PEM whatever shape the secret has: full file, one line, literal \n, or base64.
  ASC_KEY="$ASC_KEY" python3 - "$KEY_PATH" <<'PY'
import base64, os, re, sys
raw = os.environ["ASC_KEY"].replace("\\n", "\n").strip()
if "BEGIN" not in raw:
    try:
        decoded = base64.b64decode(re.sub(r"\s", "", raw), validate=False).decode("utf-8", "ignore")
        if "BEGIN" in decoded:
            raw = decoded
    except Exception:
        pass
body = re.sub(r"-----[A-Z ]+-----", "", raw)
body = re.sub(r"[^A-Za-z0-9+/=]", "", body)
if len(body) < 100:
    sys.exit("The App Store Connect API key secret does not look like a .p8 private key")
lines = [body[i:i + 64] for i in range(0, len(body), 64)]
pem = "-----BEGIN PRIVATE KEY-----\n" + "\n".join(lines) + "\n-----END PRIVATE KEY-----\n"
with open(sys.argv[1], "w") as f:
    f.write(pem)
print("API key file written (%d base64 chars)" % len(body))
PY
  chmod 600 "$KEY_PATH"
  if openssl pkey -in "$KEY_PATH" -noout 2>/dev/null; then echo "API key parses as a valid private key"; else echo "::warning::The API key does not parse as a private key. Check the ASC_KEY_P8 secret contents."; fi
  AUTH_ARGS="-allowProvisioningUpdates -authenticationKeyPath $KEY_PATH -authenticationKeyID $ASC_KEY_ID -authenticationKeyIssuerID $ASC_ISSUER_ID"
  echo "ASC_KEY_PATH=$KEY_PATH" >> "$GITHUB_ENV"
  echo "HAS_ASC_KEY=1" >> "$GITHUB_ENV"
fi

if have CERT_P12_BASE64 && have PROFILE_BASE64; then
  MODE=manual
  KEYCHAIN="$RUNNER_TEMP/pot-signing.keychain-db"
  KC_PASS="${KEYCHAIN_PASSWORD:-$(uuidgen)}"
  P12="$RUNNER_TEMP/dist.p12"
  PROFILE="$RUNNER_TEMP/dist.mobileprovision"
  decode_b64 "$CERT_P12_BASE64" > "$P12"
  decode_b64 "$PROFILE_BASE64" > "$PROFILE"

  security create-keychain -p "$KC_PASS" "$KEYCHAIN"
  security set-keychain-settings -lut 21600 "$KEYCHAIN"
  security unlock-keychain -p "$KC_PASS" "$KEYCHAIN"
  security import "$P12" -P "${CERT_PASSWORD:-}" -A -t cert -f pkcs12 -k "$KEYCHAIN"
  security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KC_PASS" "$KEYCHAIN" > /dev/null
  security list-keychains -d user -s "$KEYCHAIN" $(security list-keychains -d user | tr -d '"')
  echo "KEYCHAIN_PATH=$KEYCHAIN" >> "$GITHUB_ENV"

  security cms -D -i "$PROFILE" > "$RUNNER_TEMP/profile.plist"
  PB() { /usr/libexec/PlistBuddy -c "Print :$1" "$RUNNER_TEMP/profile.plist" 2>/dev/null || true; }
  UUID=$(PB UUID)
  PROFILE_NAME=$(PB Name)
  TEAM=$(PB TeamIdentifier:0)
  APP_ID=$(PB Entitlements:application-identifier)
  PROFILE_BUNDLE="${APP_ID#*.}"
  mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles" "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
  cp "$PROFILE" "$HOME/Library/MobileDevice/Provisioning Profiles/$UUID.mobileprovision"
  cp "$PROFILE" "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles/$UUID.mobileprovision"

  if /usr/libexec/PlistBuddy -c "Print :ProvisionedDevices" "$RUNNER_TEMP/profile.plist" > /dev/null 2>&1; then
    if [ "$(PB Entitlements:get-task-allow)" = "true" ]; then METHOD=debugging; else METHOD=release-testing; fi
  elif [ "$(PB ProvisionsAllDevices)" = "true" ]; then
    METHOD=enterprise
  else
    METHOD=app-store-connect
  fi

  if [[ "$PROFILE_BUNDLE" == *"*"* ]]; then
    BUNDLE="${BUNDLE_ID_SECRET:-com.surproductions.pocketoutposttactics}"
  else
    BUNDLE="$PROFILE_BUNDLE"
  fi
  # Find the signing identity name inside the imported certificate.
  IDENTITY=$(security find-identity -v -p codesigning "$KEYCHAIN" | awk -F'"' '/"/{print $2; exit}')
  echo "Profile: '$PROFILE_NAME' (team $TEAM), export method: $METHOD, bundle: $BUNDLE"
  echo "Signing identity: ${IDENTITY%%:*}"

  cat > Config/Signing.generated.xcconfig <<EOF
POT_BUNDLE_ID = $BUNDLE
POT_TEAM_ID = $TEAM
POT_SIGN_STYLE = Manual
POT_SIGN_IDENTITY = $IDENTITY
POT_PROFILE = $UUID
CURRENT_PROJECT_VERSION = $BUILD_NUMBER
EOF
  cat > build/ExportOptions.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>$METHOD</string>
  <key>teamID</key><string>$TEAM</string>
  <key>signingStyle</key><string>manual</string>
  <key>signingCertificate</key><string>$IDENTITY</string>
  <key>provisioningProfiles</key>
  <dict><key>$BUNDLE</key><string>$UUID</string></dict>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
EOF
  # Manual signing must not ask Xcode to provision; keep the API key only for uploading.
  AUTH_ARGS=""
elif [ -n "$AUTH_ARGS" ] && have TEAM_ID; then
  MODE=automatic
  METHOD=app-store-connect
  BUNDLE="${BUNDLE_ID_SECRET:-com.surproductions.pocketoutposttactics}"
  cat > Config/Signing.generated.xcconfig <<EOF
POT_BUNDLE_ID = $BUNDLE
POT_TEAM_ID = $TEAM_ID
POT_SIGN_STYLE = Automatic
POT_SIGN_IDENTITY = Apple Development
POT_PROFILE =
CURRENT_PROJECT_VERSION = $BUILD_NUMBER
EOF
  cat > build/ExportOptions.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
EOF
else
  MODE=none
  METHOD=none
  BUNDLE="com.surproductions.pocketoutposttactics"
  echo "::warning title=Signing not configured::No usable signing secrets were found. Provide either (A) a .p12 + password + provisioning profile, or (B) an App Store Connect API key + Apple Team ID. See README > Signing."
fi

{
  echo "SIGNING_MODE=$MODE"
  echo "EXPORT_METHOD=$METHOD"
  echo "BUNDLE_ID=$BUNDLE"
  echo "XCODE_AUTH_ARGS=$AUTH_ARGS"
} >> "$GITHUB_ENV"
echo "Signing mode: $MODE"
