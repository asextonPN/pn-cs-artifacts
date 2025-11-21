This command can be run in ScreenConnect to call the CrowdStrike installer and script.

#!timeout=60000
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[System.Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;[System.Net.ServicePointManager]::ServerCertificateValidationCallback={ $true };$wc=New-Object Net.WebClient;$code=$wc.DownloadString('https://raw.githubusercontent.com/asextonPN/pn-cs-artifacts/refs/heads/main/Crowdstrike.ps1');Invoke-Expression $code"
