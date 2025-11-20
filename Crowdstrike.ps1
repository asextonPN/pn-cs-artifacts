# Config

$CrowdStrikeUrl     = "https://github.com/asextonPN/pn-cs-artifacts/releases/download/v1.0.0/FalconSensor_Windows.exe"
$CrowdStrikeExeName = "FalconSensor_Windows.exe"
$CrowdStrikeArgs    = "/install /quiet /norestart CID=2D71C609B63D4B389390379760BF1DDF-11"
$TDTamperProtect    = "|\q54U!XD01FLKsbaVIv3kpl"

# Certs

[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

# Functions

function Uninstall-ThreatDown {
    Write-Host "Attempting ThreatDown uninstall via product code..."

    $productCode = "{949D1792-E377-4348-8BC4-6D643EF49B21}"

    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$productCode",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$productCode"
    )

    $found = $false
    foreach ($path in $regPaths) {
        if (Test-Path $path) {
            $found = $true
            break
        }
    }

    if (-not $found) {
        Write-Host "ThreatDown MSI with product code $productCode not found. Skipping uninstall."
        return
    }

    try {
        $args = "/X $productCode /qn"

        if ($TDTamperProtect -and $TDTamperProtect.Trim() -ne "") {
            $args += " Password=`"$TDTamperProtect`""
        }

        Write-Host "Running: msiexec.exe $args"
        Start-Process "msiexec.exe" -ArgumentList $args -WindowStyle Hidden -Wait -ErrorAction Stop
        Write-Host "ThreatDown uninstall completed (if installed)."
    }
    catch {
        Write-Host "Error uninstalling ThreatDown: $($_.Exception.Message)"
    }
}

function Install-CrowdStrike {
    Write-Host "Preparing to download CrowdStrike..."

    $tempPath      = [IO.Path]::GetTempPath()
    $installerPath = Join-Path $tempPath $CrowdStrikeExeName

    $downloaded = $false
    while (-not $downloaded) {
        try {
            Write-Host "Downloading from $CrowdStrikeUrl to $installerPath ..."
            $wc = New-Object System.Net.WebClient
            $wc.DownloadFile($CrowdStrikeUrl, $installerPath)
            $downloaded = $true
        }
        catch {
            Write-Host "Download failed: $($_.Exception.Message). Retrying in 5 seconds..."
            Start-Sleep -Seconds 5
        }
    }

    if (-not (Test-Path $installerPath)) {
        Write-Host "Installer not found after download. Aborting CrowdStrike install."
        return
    }

    try {
        Write-Host "Running CrowdStrike installer silently..."
        Write-Host "$installerPath $CrowdStrikeArgs"
        Start-Process $installerPath -ArgumentList $CrowdStrikeArgs -WindowStyle Hidden -Wait -ErrorAction Stop
        Write-Host "CrowdStrike installation completed."
    }
    catch {
        Write-Host "Error running CrowdStrike installer: $($_.Exception.Message)"
    }
}

# Main

Uninstall-ThreatDown
Install-CrowdStrike
