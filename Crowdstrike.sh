#!/bin/bash

# Config

CS_INSTALLER_URL="https://github.com/asextonPN/pn-cs-artifacts/releases/download/v1.0.0/FalconSensorMac.pkg"
CS_INSTALLER_PATH="/tmp/FalconSensorMac.pkg"
CS_CID="2D71C609B63D4B389390379760BF1DDF-11"

# Functions

echo "[1/3] Checking for ThreatDown / Malwarebytes EDR..."

if [ -f "/Library/Application Support/Malwarebytes/MBEndpointAgent/uninstall.sh" ]; then
    echo "Found Malwarebytes Endpoint Agent. Uninstalling..."
    chmod +x "/Library/Application Support/Malwarebytes/MBEndpointAgent/uninstall.sh"
    "/Library/Application Support/Malwarebytes/MBEndpointAgent/uninstall.sh" --quiet
fi

if [ -f "/Library/Application Support/THREATDOWN/EndpointAgent/uninstall.sh" ]; then
    echo "Found ThreatDown Endpoint Agent. Uninstalling..."
    chmod +x "/Library/Application Support/THREATDOWN/EndpointAgent/uninstall.sh"
    "/Library/Application Support/THREATDOWN/EndpointAgent/uninstall.sh" --quiet
fi

echo "ThreatDown uninstall complete (if installed)."

echo "[2/3] Downloading CrowdStrike installer..."

curl -L "$CS_INSTALLER_URL" -o "$CS_INSTALLER_PATH"
if [ $? -ne 0 ] || [ ! -f "$CS_INSTALLER_PATH" ]; then
    echo "ERROR: Failed to download CrowdStrike installer."
    exit 1
fi

echo "Download OK: $CS_INSTALLER_PATH"

echo "[3/3] Installing CrowdStrike Falcon Sensor..."

sudo installer -pkg "$CS_INSTALLER_PATH" -target / \
    CID="$CS_CID"

if [ $? -eq 0 ]; then
    echo "CrowdStrike installation completed successfully."
else
    echo "ERROR: CrowdStrike installation failed."
    exit 1
fi

echo "Done"
