#!/bin/bash

# Config

CS_INSTALLER_URL="https://github.com/asextonPN/pn-cs-artifacts/releases/download/v1.0.0/FalconSensorMacOS.MaverickGyr.pkg"
CS_INSTALLER_PATH="/tmp/FalconSensorMacOS.MaverickGyr.pkg"
CS_CID="2D71C609B63D4B389390379760BF1DDF-11"

PLIST_DIR="/Library/CS"
PLIST_PATH="$PLIST_DIR/falcon.plist"

MB_TEAM_ID="GVZRY6KDKR"
MB_EXTS=(
  "com.malwarebytes.edr.helper.ext"
  "com.malwarebytes.dns-proxy.ext"
  "com.malwarebytes.ncep.engine.sys.ext"
)

if [ "$(uname -s)" != "Darwin" ]; then
  echo "Not macOS, exiting."
  exit 0
fi

# Functions

echo "[1/5] Removing Malwarebytes / ThreatDown system extensions (if present)..."

for ext in "${MB_EXTS[@]}"; do
  echo " - Trying to uninstall $ext..."
  systemextensionsctl uninstall "$MB_TEAM_ID" "$ext" 2>/dev/null || true
done

echo "[2/5] Running vendor uninstall scripts (if present)..."

if [ -f "/Library/Application Support/Malwarebytes/MBEndpointAgent/uninstall.sh" ]; then
  echo " - Malwarebytes Endpoint Agent uninstall.sh"
  chmod +x "/Library/Application Support/Malwarebytes/MBEndpointAgent/uninstall.sh"
  "/Library/Application Support/Malwarebytes/MBEndpointAgent/uninstall.sh" --quiet || true
fi

if [ -f "/Library/Application Support/THREATDOWN/EndpointAgent/uninstall.sh" ]; then
  echo " - ThreatDown Endpoint Agent uninstall.sh"
  chmod +x "/Library/Application Support/THREATDOWN/EndpointAgent/uninstall.sh"
  "/Library/Application Support/THREATDOWN/EndpointAgent/uninstall.sh" --quiet || true
fi

echo " - Removing leftover Malwarebytes / ThreatDown files..."

rm -rf "/Library/Application Support/Malwarebytes" 2>/dev/null || true
rm -rf "/Library/Application Support/THREATDOWN" 2>/dev/null || true
rm -rf /Library/Extensions/Malwarebytes* 2>/dev/null || true
rm -rf /Applications/Malwarebytes* 2>/dev/null || true
rm -rf /Applications/ThreatDown* 2>/dev/null || true

echo "ThreatDown / Malwarebytes removal step complete (best effort)."

echo "[3/5] Cleaning any existing Falcon install..."

if [ -x "/Applications/Falcon.app/Contents/Resources/falconctl" ]; then
  echo " - Found falconctl; attempting uninstall..."
  /Applications/Falcon.app/Contents/Resources/falconctl uninstall -t 2>/dev/null || true
fi

rm -rf /Applications/Falcon.app 2>/dev/null || true
rm -rf /Library/CS 2>/dev/null || true

echo "[4/5] Writing CrowdStrike CID plist..."

mkdir -p "$PLIST_DIR"

cat <<EOF > "$PLIST_PATH"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>aid</key>
    <string>$CS_CID</string>
</dict>
</plist>
EOF

chmod 644 "$PLIST_PATH"
echo " - Plist created at $PLIST_PATH"
echo " - Contents:"
cat "$PLIST_PATH"

echo "[5/5] Downloading CrowdStrike installer..."
curl -L "$CS_INSTALLER_URL" -o "$CS_INSTALLER_PATH"

if [ $? -ne 0 ] || [ ! -f "$CS_INSTALLER_PATH" ]; then
  echo "ERROR: Failed to download CrowdStrike installer."
  exit 1
fi

echo "Download OK: $CS_INSTALLER_PATH"
echo "Installing CrowdStrike Falcon Sensor..."

installer -pkg "$CS_INSTALLER_PATH" -target /
INSTALL_RC=$?

if [ $INSTALL_RC -ne 0 ]; then
  echo "ERROR: CrowdStrike installer exited with code $INSTALL_RC"
  exit $INSTALL_RC
fi

echo "CrowdStrike pkg install reported success."

if [ -x "/Applications/Falcon.app/Contents/Resources/falconctl" ]; then
  echo "Loading Falcon sensor..."
  /Applications/Falcon.app/Contents/Resources/falconctl load 2>/dev/null || true

  echo
  echo "=== Falcon sensor info ==="
  /Applications/Falcon.app/Contents/Resources/falconctl info 2>/dev/null || echo "falconctl info not available yet."
  echo
  echo "=== Falcon sensor stats ==="
  /Applications/Falcon.app/Contents/Resources/falconctl stats 2>/dev/null || echo "falconctl stats not available yet."
else
  echo "WARNING: falconctl not found after install."
fi

echo "Done. Reboot may be required."
