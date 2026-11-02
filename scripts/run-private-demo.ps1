param([string]$DeviceId, [switch]$CheckOnly)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'android-tools.ps1')
$taskTools = Get-RiskLensAndroidTools
$phoneId = Get-RiskLensAndroidDevice -Adb $taskTools.Adb -DeviceId $DeviceId
if ($CheckOnly) {
    Write-Host 'Flutter, Android tools and the authorized phone are ready.'
    return
}
try {
    $health = Invoke-RestMethod 'http://127.0.0.1:8000/health' -TimeoutSec 5
    if ($health.status -ne 'ok') { throw 'Unexpected health response.' }
} catch {
    throw 'Start scripts/start-local-api.ps1 in the first PC terminal and leave it running.'
}
& $taskTools.Adb -s $phoneId reverse tcp:8000 tcp:8000
if ($LASTEXITCODE -ne 0) { throw 'USB port forwarding failed.' }
$mobileRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'apps\mobile'
Push-Location $mobileRoot
try {
    & $taskTools.Flutter run -d $phoneId --dart-define=API_BASE_URL=http://127.0.0.1:8000
    if ($LASTEXITCODE -ne 0) { throw 'The private demo app failed to start.' }
} finally {
    Pop-Location
    & $taskTools.Adb -s $phoneId reverse --remove tcp:8000 | Out-Null
}
