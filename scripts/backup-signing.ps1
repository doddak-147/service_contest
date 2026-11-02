param([string]$Destination, [switch]$VerifyOnly)

$ErrorActionPreference = 'Stop'
$taskRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$properties = Join-Path $taskRoot 'apps\mobile\android\key.properties'
if (-not (Test-Path -LiteralPath $properties)) { throw 'The local signing settings are missing.' }
$storePath = $null
foreach ($line in Get-Content -LiteralPath $properties) {
    if ($line -match '^storeFile=(.+)$') { $storePath = $Matches[1].Replace('\\', '\') }
}
if (-not $storePath -or -not (Test-Path -LiteralPath $storePath)) {
    throw 'The local signing keystore is missing.'
}
if ($VerifyOnly) {
    Write-Host 'Both local signing files are present. No backup was created.'
    return
}
if (-not $Destination) { throw 'Specify an external or encrypted folder using -Destination.' }
$destinationRoot = [System.IO.Path]::GetFullPath($Destination)
if ($destinationRoot.TrimEnd('\') -eq $taskRoot -or
    $destinationRoot.StartsWith($taskRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Signing backups must be outside the repository.'
}
$probePath = $destinationRoot
while ($probePath) {
    if (Test-Path -LiteralPath $probePath) {
        $probeItem = Get-Item -LiteralPath $probePath -Force
        if ($probeItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            throw 'Choose a direct backup folder without symbolic links or junctions.'
        }
    }
    $probePath = Split-Path $probePath -Parent
}
$backupName = 'RiskLens-signing-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
$backupPath = Join-Path $destinationRoot $backupName
$null = [System.IO.Directory]::CreateDirectory($backupPath)
foreach ($source in @($properties, $storePath)) {
    $target = Join-Path $backupPath (Split-Path $source -Leaf)
    Copy-Item -LiteralPath $source -Destination $target -ErrorAction Stop
    if ((Get-FileHash -LiteralPath $source).Hash -ne (Get-FileHash -LiteralPath $target).Hash) {
        throw 'Backup verification failed. Preserve the originals and inspect the destination.'
    }
}
Write-Host 'Both signing files were copied and verified.'
Write-Host $backupPath
