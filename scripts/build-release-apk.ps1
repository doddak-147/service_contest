param(
    [string]$ApiBaseUrl = 'https://service-contest-2026-api.duckdns.org'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$mobileRoot = Join-Path $repositoryRoot 'apps\mobile'
$propertiesPath = Join-Path $mobileRoot 'android\key.properties'
if (-not (Test-Path -LiteralPath $propertiesPath)) {
    throw 'android/key.properties is missing. Restore the local release signing files before building.'
}
if (-not $ApiBaseUrl.StartsWith('https://', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Release API_BASE_URL must use HTTPS.'
}

Push-Location $mobileRoot
try {
    & flutter build apk --release "--dart-define=API_BASE_URL=$ApiBaseUrl"
    if ($LASTEXITCODE -ne 0) { throw 'Flutter release build failed.' }
} finally {
    Pop-Location
}

$apkPath = Join-Path $mobileRoot 'build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path -LiteralPath $apkPath)) { throw 'Release APK was not produced.' }

$sdkRoot = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA 'Android\sdk' }
$signer = Get-ChildItem -LiteralPath (Join-Path $sdkRoot 'build-tools') -Directory |
    Sort-Object { [Version]$_.Name } -Descending |
    ForEach-Object { Join-Path $_.FullName 'apksigner.bat' } |
    Where-Object { Test-Path -LiteralPath $_ } |
    Select-Object -First 1
if (-not $signer) { throw 'Android apksigner was not found.' }
$originalJavaHome = $env:JAVA_HOME
if (-not $env:JAVA_HOME) {
    $env:JAVA_HOME = Join-Path $env:ProgramFiles 'Android\Android Studio\jbr'
}
try {
    & $signer verify --verbose --print-certs $apkPath
    if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed.' }
} finally {
    $env:JAVA_HOME = $originalJavaHome
}

$outputDirectory = Join-Path $repositoryRoot 'output\apk'
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$outputPath = Join-Path $outputDirectory 'RiskLens-Android-1.0.0.apk'
Copy-Item -LiteralPath $apkPath -Destination $outputPath -Force
Get-FileHash -LiteralPath $outputPath -Algorithm SHA256 | Select-Object Path, Hash
