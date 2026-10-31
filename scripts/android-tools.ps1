function Get-RiskLensAndroidTools {
    $taskRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $localSettings = @{}
    $localProperties = Join-Path $taskRoot 'apps\mobile\android\local.properties'
    if (Test-Path -LiteralPath $localProperties) {
        foreach ($line in Get-Content -LiteralPath $localProperties) {
            if ($line -match '^(flutter.sdk|sdk.dir)=(.+)$') {
                $localSettings[$Matches[1]] = $Matches[2].Replace('\\', '\')
            }
        }
    }
    $flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
    $flutterPath = if ($flutterCommand) { $flutterCommand.Source } else { $null }
    if (-not $flutterPath -and $localSettings.ContainsKey('flutter.sdk')) {
        $flutterPath = Join-Path $localSettings['flutter.sdk'] 'bin\flutter.bat'
    }
    $sdkRoot = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } elseif ($localSettings.ContainsKey('sdk.dir')) {
        $localSettings['sdk.dir']
    } else { Join-Path $env:LOCALAPPDATA 'Android\sdk' }
    $adbPath = Join-Path $sdkRoot 'platform-tools\adb.exe'
    if (-not $flutterPath -or -not (Test-Path -LiteralPath $flutterPath)) {
        throw 'Flutter was not found. Restore Flutter or android/local.properties.'
    }
    if (-not (Test-Path -LiteralPath $adbPath)) { throw 'Android platform-tools were not found.' }
    [pscustomobject]@{ Flutter = $flutterPath; Adb = $adbPath; SdkRoot = $sdkRoot }
}

function Get-RiskLensAndroidDevice {
    param([string]$Adb, [string]$DeviceId)
    $deviceLines = & $Adb devices
    if ($LASTEXITCODE -ne 0) { throw 'ADB device detection failed.' }
    $ready = @($deviceLines | ForEach-Object {
        if ($_ -match '^(\S+)\s+device\s*$') { $Matches[1] }
    })
    if ($DeviceId) {
        if ($DeviceId -notin $ready) { throw 'The selected phone is not authorized or connected.' }
        return $DeviceId
    }
    if ($ready.Count -ne 1) {
        throw 'Connect and authorize one phone, or specify -DeviceId.'
    }
    return $ready[0]
}
