param([switch]$PrepareOnly)

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$python = Join-Path $repositoryRoot '.venv\Scripts\python.exe'
$packageDirectory = Join-Path $repositoryRoot 'tmp\cloud-release'
& $python (Join-Path $PSScriptRoot 'prepare-cloud-release.py')
if ($LASTEXITCODE -ne 0) { throw 'Release preparation failed.' }
$info = Get-Content -LiteralPath (Join-Path $packageDirectory 'package-info.json') -Raw | ConvertFrom-Json
if ($info.sha256 -notmatch '^[a-f0-9]{64}$') { throw 'Invalid package hash.' }
Write-Host ('Prepared release: ' + $info.release_id)
Write-Host ('SHA256: ' + $info.sha256)
if ($PrepareOnly) { return }

# OpenSSH prompts in the user's terminal. Passwords are never arguments or files.
$remoteDirectory = '/tmp/risk-lens-' + $info.sha256.Substring(0, 16)
& ssh -o ConnectTimeout=10 root@211.233.194.16 "umask 077; mkdir -p '$remoteDirectory'"
if ($LASTEXITCODE -ne 0) { throw 'SSH connection failed. No service was changed.' }
& scp (Join-Path $packageDirectory 'risk-lens-api.tar.gz') (Join-Path $repositoryRoot 'deploy\cloud\apply-release.py') "root@211.233.194.16:$remoteDirectory/"
if ($LASTEXITCODE -ne 0) { throw 'Upload failed. No service was changed.' }
& ssh -t -o ConnectTimeout=10 root@211.233.194.16 "python3 '$remoteDirectory/apply-release.py' --archive '$remoteDirectory/risk-lens-api.tar.gz' --sha256 '$($info.sha256)'"
if ($LASTEXITCODE -ne 0) { throw 'Deployment did not finish. Send only the final FAIL/PASS output.' }
Write-Host 'Cloud deployment finished. Keep the printed rollback command.'
