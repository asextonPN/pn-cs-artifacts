#!/bin/bash

# Config

CS_INSTALLER_URL="https://github.com/asextonPN/pn-cs-artifacts/releases/download/v1.0.0/FalconSensorMacOS.MaverickGyr.pkg"
CS_INSTALLER_PATH="/tmp/FalconSensorMacOS.MaverickGyr.pkg"
CS_CID="2D71C609B63D4B389390379760BF1DDF-11"

PLIST_DIR="/Library/CS"
PLIST_PATH="$PLIST_DIR/falcon.plist"

# Functions

echo "[1/3] Checking for ThreatDown / Malwarebytes EDR..."

if [ -f "/Library/Application Support/Malwarebytes/MBEndpointAgent/uninstall.sh" ]; then
    echo "Uninstalling Malwarebytes Endpoint Agent..."
    chmod +x "/Library/Application Support/Malwarebytes/MBEndpointAgent/uninstall.sh"
    "/Library/Application Support/Malwarebytes/MBEndpointAgent/uninstall.sh" --quiet
fi

if [ -f "/Library/Application Support/THREATDOWN/EndpointAgent/uninstall.sh" ]; then
    echo "Uninstalling ThreatDown Endpoint Agent..."
    chmod +x "/Library/Application Support/THREATDOWN/EndpointAgent/uninstall.sh"
    "/Library/Application Support/THREATDOWN/EndpointAgent/uninstall.sh" --quiet
fi

echo "ThreatDown uninstall complete (if installed)."

echo "[2/3] Writing CrowdStrike CID plist..."

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
echo "Plist created at $PLIST_PATH"

echo "[3/3] Downloading CrowdStrike installer..."
curl -L "$CS_INSTALLER_URL" -o "$CS_INSTALLER_PATH"

if [ $? -ne 0 ] || [ ! -f "$CS_INSTALLER_PATH" ]; then
    echo "ERROR: Failed to download CrowdStrike installer."
    exit 1
fi

echo "Download OK: $CS_INSTALLER_PATH"

echo "Installing CrowdStrike Falcon Sensor..."
installer -pkg "$CS_INSTALLER_PATH" -target /

if [ $? -eq 0 ]; then
    echo "CrowdStrike installation successful."
else
    echo "ERROR: CrowdStrike installation failed."
    exit 1
fi

echo "Done"
