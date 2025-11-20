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

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Checks

if [ "$(uname -s)" != "Darwin" ]; then
  log "Not macOS, exiting."
  exit 0
fi

if [ "$(id -u)" -ne 0 ]; then
  log "ERROR: This script must be run as root (uid 0)."
  exit 1
fi

# Remove ThreatDown

log "[1/6] Removing Malwarebytes / ThreatDown system extensions..."

if command -v systemextensionsctl >/dev/null 2>&1; then
  for ext in "${MB_EXTS[@]}"; do
    log " - Trying: systemextensionsctl uninstall $MB_TEAM_ID $ext"
    if output=$(systemextensionsctl uninstall "$MB_TEAM_ID" "$ext" 2>&1); then
      log "   -> uninstall command completed (reboot may be required)."
      [ -n "$output" ] && log "   -> output: $output"
    else
      rc=$?
      log "   -> uninstall command FAILED (exit $rc)."
      [ -n "$output" ] && log "   -> output: $output"
    fi
  done

  log " - Current systemextensionsctl list entries containing 'Malwarebytes' or 'THREATDOWN':"
  systemextensionsctl list 2>/dev/null | grep -Ei "malwarebytes|threatdown" || log "   -> none found in list output."
else
  log "WARNING: systemextensionsctl not found; cannot manage system extensions on this macOS version."
fi

# Uninstall Scripts

log "[2/6] Running Malwarebytes / ThreatDown vendor uninstall scripts..."

if [ -f "/Library/Application Support/Malwarebytes/MBEndpointAgent/uninstall.sh" ]; then
  log " - Running Malwarebytes Endpoint Agent uninstall.sh"
  chmod +x "/Library/Application Support/Malwarebytes/MBEndpointAgent/uninstall.sh" || true
  "/Library/Application Support/Malwarebytes/MBEndpointAgent/uninstall.sh" --quiet || log "   -> uninstall.sh returned non-zero (continuing)."
fi

if [ -f "/Library/Application Support/THREATDOWN/EndpointAgent/uninstall.sh" ]; then
  log " - Running ThreatDown Endpoint Agent uninstall.sh"
  chmod +x "/Library/Application Support/THREATDOWN/EndpointAgent/uninstall.sh" || true
  "/Library/Application Support/THREATDOWN/EndpointAgent/uninstall.sh" --quiet || log "   -> uninstall.sh returned non-zero (continuing)."
fi

log " - Removing leftover Malwarebytes / ThreatDown files..."
rm -rf "/Library/Application Support/Malwarebytes" 2>/dev/null || true
rm -rf "/Library/Application Support/THREATDOWN" 2>/dev/null || true
rm -rf /Library/Extensions/Malwarebytes* 2>/dev/null || true
rm -rf /Applications/Malwarebytes* 2>/dev/null || true
rm -rf /Applications/ThreatDown* 2>/dev/null || true

log "ThreatDown / Malwarebytes removal step complete (best effort; reboot may still be required for extensions to fully unload)."

# Clean CrowdStrike

log "[3/6] Cleaning any existing Falcon install..."

FALCONCTL_OLD=""
if [ -x "/Applications/Falcon.app/Contents/Resources/falconctl" ]; then
  FALCONCTL_OLD="/Applications/Falcon.app/Contents/Resources/falconctl"
elif [ -x "/Library/CS/falconctl" ]; then
  FALCONCTL_OLD="/Library/CS/falconctl"
fi

if [ -n "$FALCONCTL_OLD" ]; then
  log " - Found existing falconctl at $FALCONCTL_OLD; attempting uninstall..."
  "$FALCONCTL_OLD" uninstall 2>&1 || log "   -> falconctl uninstall returned non-zero (continuing)."
fi

rm -rf /Applications/Falcon.app 2>/dev/null || true
rm -rf /Library/CS 2>/dev/null || true

# CID plist

log "[4/6] Writing CrowdStrike CID plist..."

mkdir -p "$PLIST_DIR" 2>/dev/null || {
  log "ERROR: Failed to create $PLIST_DIR"
  exit 1
}

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

chmod 644 "$PLIST_PATH" 2>/dev/null || log "WARNING: Failed to chmod 644 on $PLIST_PATH (continuing)."

if [ ! -f "$PLIST_PATH" ]; then
  log "ERROR: Plist file $PLIST_PATH was not created."
  ls -ld "$PLIST_DIR" 2>/dev/null || true
  exit 1
fi

if command -v plutil >/dev/null 2>&1; then
  if ! plutil -lint "$PLIST_PATH" >/dev/null 2>&1; then
    log "ERROR: $PLIST_PATH is not a valid plist:"
    cat "$PLIST_PATH" 2>/dev/null || true
    exit 1
  fi
else
  log "WARNING: plutil not found; skipping plist validation."
fi

log " - Plist created at $PLIST_PATH"
log " - Plist contents:"
cat "$PLIST_PATH" 2>/dev/null || log "WARNING: Could not read back $PLIST_PATH even though it exists."

# CrowdStrike

log "[5/6] Downloading CrowdStrike installer from GitHub..."

curl -fL --retry 3 --retry-delay 5 "$CS_INSTALLER_URL" -o "$CS_INSTALLER_PATH"
CURL_RC=$?

if [ $CURL_RC -ne 0 ] || [ ! -f "$CS_INSTALLER_PATH" ]; then
  log "ERROR: Failed to download CrowdStrike installer (curl exit $CURL_RC)."
  ls -l "$CS_INSTALLER_PATH" 2>/dev/null || true
  exit 1
fi

log "Download OK: $CS_INSTALLER_PATH"
log "Installing CrowdStrike Falcon Sensor pkg..."

installer -pkg "$CS_INSTALLER_PATH" -target /
INSTALL_RC=$?

if [ $INSTALL_RC -ne 0 ]; then
  log "ERROR: CrowdStrike installer exited with code $INSTALL_RC"
  exit $INSTALL_RC
fi

log "CrowdStrike pkg install reported success."

# License

log "[6/6] Licensing and loading Falcon sensor..."

FALCONCTL=""
if [ -x "/Applications/Falcon.app/Contents/Resources/falconctl" ]; then
  FALCONCTL="/Applications/Falcon.app/Contents/Resources/falconctl"
elif [ -x "/Library/CS/falconctl" ]; then
  FALCONCTL="/Library/CS/falconctl"
fi

if [ -z "$FALCONCTL" ]; then
  log "ERROR: falconctl not found after install."
  ls -R "/Applications/Falcon.app" 2>/dev/null || true
  ls -R "/Library/CS" 2>/dev/null || true
  exit 1
fi

log " - Using falconctl at: $FALCONCTL"

log " - Applying license (CID)..."
if output=$("$FALCONCTL" license "$CS_CID" 2>&1); then
  log "   -> license command reported success."
  [ -n "$output" ] && log "   -> output: $output"
else
  rc=$?
  log "ERROR: falconctl license failed (exit $rc)."
  [ -n "$output" ] && log "   -> output: $output"
fi

log " - Reloading Falcon sensor..."
"$FALCONCTL" unload 2>/dev/null || true
"$FALCONCTL" load 2>/dev/null || true

log
log "Falcon sensor info"
"$FALCONCTL" info 2>&1 || log "falconctl info not available yet."
log
log "Falcon sensor stats"
"$FALCONCTL" stats 2>&1 || log "falconctl stats not available yet."

log
log "Final checks"
if [ -f "$PLIST_PATH" ]; then
  log "Plist still present at $PLIST_PATH:"
  cat "$PLIST_PATH" 2>/dev/null || true
else
  log "WARNING: $PLIST_PATH is missing after install and license steps."
fi

if command -v systemextensionsctl >/dev/null 2>&1; then
  log "Current CrowdStrike / Malwarebytes system extensions:"
  systemextensionsctl list 2>/dev/null | grep -Ei "crowdstrike|falcon|malwarebytes|threatdown" || log "   -> no matching entries."
fi

log "Done."
