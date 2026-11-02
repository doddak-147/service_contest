param(
    [string]$Archive,
    [string]$ExpectedSha256,
    [switch]$VerifyOnly
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$properties = Join-Path $repositoryRoot 'apps\mobile\android\key.properties'
if (-not (Test-Path -LiteralPath $properties -PathType Leaf)) {
    throw 'The local signing settings are missing.'
}
$storePath = $null
foreach ($line in Get-Content -LiteralPath $properties) {
    if ($line -match '^storeFile=(.+)$') { $storePath = $Matches[1].Replace('\\', '\') }
}
if (-not $storePath -or -not (Test-Path -LiteralPath $storePath -PathType Leaf)) {
    throw 'The local signing keystore is missing.'
}
$sevenZip = Join-Path $env:LOCALAPPDATA 'Programs\7-Zip\7z.exe'
if (-not (Test-Path -LiteralPath $sevenZip)) {
    $sevenZip = Join-Path $env:ProgramFiles '7-Zip\7z.exe'
}
if (-not (Test-Path -LiteralPath $sevenZip)) { throw 'Install standard 7-Zip first.' }
$backupRoot = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'RiskLensBackups'
if (-not $Archive) {
    if ($VerifyOnly) { throw 'Specify the downloaded archive using -Archive.' }
    $backupName = 'RiskLens-signing-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8) + '.7z'
    $Archive = Join-Path $backupRoot $backupName
}
$Archive = [System.IO.Path]::GetFullPath($Archive)
if ($Archive -eq $repositoryRoot -or $Archive.StartsWith($repositoryRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The encrypted archive must be outside the repository.'
}
$null = [System.IO.Directory]::CreateDirectory($backupRoot)
if (-not $VerifyOnly) {
    if (Test-Path -LiteralPath $Archive) { throw 'Choose a new archive path; existing backups are preserved.' }
    if (-not (Test-Path -LiteralPath (Split-Path $Archive -Parent))) { throw 'The archive folder does not exist.' }
    Write-Host 'Choose a unique backup password. Enter it only at the 7-Zip prompt.'
    Write-Host 'Keep this password in your password manager; do not send it in chat.'
    & $sevenZip a -t7z -mhe=on -p $Archive $properties $storePath
    if ($LASTEXITCODE -ne 0) { throw 'Encrypted archive creation failed. Originals are unchanged.' }
}
if (-not (Test-Path -LiteralPath $Archive -PathType Leaf)) { throw 'The archive is missing.' }
$archiveHash = (Get-FileHash -LiteralPath $Archive -Algorithm SHA256).Hash
if ($ExpectedSha256 -and $archiveHash -ne $ExpectedSha256) {
    throw 'The downloaded archive hash differs. Do not replace the local backup.'
}
# A random incorrect password must not reveal even the filenames.
$probePassword = [Guid]::NewGuid().ToString('N')
$probeStart = New-Object System.Diagnostics.ProcessStartInfo
$probeStart.FileName = $sevenZip
$probeStart.Arguments = 'l -p' + $probePassword + ' "' + $Archive + '"'
$probeStart.UseShellExecute = $false
$probeStart.CreateNoWindow = $true
$probeStart.RedirectStandardOutput = $true
$probeStart.RedirectStandardError = $true
$probeProcess = [System.Diagnostics.Process]::Start($probeStart)
$null = $probeProcess.StandardOutput.ReadToEnd()
$null = $probeProcess.StandardError.ReadToEnd()
$probeProcess.WaitForExit()
$probeExitCode = $probeProcess.ExitCode
$probeProcess.Dispose()
if ($probeExitCode -eq 0) { throw 'Archive headers are readable without the correct password.' }
Write-Host 'PASS: archive filenames are encrypted.'

# Restore into an isolated, user-only folder, then compare bytes with originals.
# The password stays inside 7-Zip's interactive prompt, never a script argument.
$restoreDirectory = Join-Path $backupRoot ('restore-check-' + [Guid]::NewGuid().ToString('N'))
$null = [System.IO.Directory]::CreateDirectory($restoreDirectory)
$sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
& icacls.exe $restoreDirectory /inheritance:r /grant:r "*${sid}:(OI)(CI)F" '*S-1-5-18:(OI)(CI)F' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Could not restrict the temporary restore folder.' }
$expectedNames = @((Split-Path $properties -Leaf), (Split-Path $storePath -Leaf))
try {
    Write-Host 'Enter the same backup password to verify a real restore.'
    & $sevenZip x "-o$restoreDirectory" $Archive
    if ($LASTEXITCODE -ne 0) { throw 'Restore failed. Keep the original signing files.' }
    $restored = @(Get-ChildItem -LiteralPath $restoreDirectory -File)
    if ($restored.Count -ne 2 -or @(Get-ChildItem -LiteralPath $restoreDirectory -Directory).Count -ne 0) {
        throw 'Unexpected archive contents. Only the two signing files are expected.'
    }
    foreach ($source in @($properties, $storePath)) {
        $copy = Join-Path $restoreDirectory (Split-Path $source -Leaf)
        if (-not (Test-Path -LiteralPath $copy -PathType Leaf) -or
            (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $copy -Algorithm SHA256).Hash) {
            throw 'Restored signing files do not match the originals.'
        }
    }
    Write-Host 'PASS: both signing files restored and matched the originals.'
} finally {
    # Only these two exact temporary files can be deleted. Never recurse.
    $resolvedRestore = [System.IO.Path]::GetFullPath($restoreDirectory).TrimEnd('\')
    $resolvedBackup = [System.IO.Path]::GetFullPath($backupRoot).TrimEnd('\') + '\'
    if (-not $resolvedRestore.StartsWith($resolvedBackup, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Temporary restore path is outside the backup folder; cleanup stopped.'
    }
    foreach ($name in $expectedNames) {
        $copy = Join-Path $resolvedRestore $name
        if (Test-Path -LiteralPath $copy -PathType Leaf) { Remove-Item -LiteralPath $copy -Force }
    }
    if (@(Get-ChildItem -LiteralPath $resolvedRestore -Force).Count -eq 0) {
        [System.IO.Directory]::Delete($resolvedRestore, $false)
    } else {
        Write-Warning ('Inspect remaining temporary files at ' + $resolvedRestore)
    }
}
if (-not $VerifyOnly) {
    [System.IO.File]::WriteAllText($Archive + '.sha256', $archiveHash + [Environment]::NewLine)
}
Write-Host ('Archive: ' + $Archive)
Write-Host ('SHA256: ' + $archiveHash)
Write-Host 'Upload only the .7z archive to your private Google Drive. Do not upload plaintext signing files.'
