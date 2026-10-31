param([switch]$PublicOnly)

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$python = Join-Path $repositoryRoot '.venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $python)) {
    throw 'Local Python virtual environment is missing.'
}

$previousKey = $env:TWELVE_DATA_API_KEY
try {
    if (-not $PublicOnly) {
        $secureKey = Read-Host 'Paste ONLY the Twelve Data API key, then press Enter' -AsSecureString
        $privateKey = [System.Net.NetworkCredential]::new('', $secureKey).Password.Trim()
        if ($privateKey -notmatch '^[A-Fa-f0-9]{32}$') {
            throw 'The key format is invalid. Copy only the 32-character key, without commands or labels.'
        }
        $env:TWELVE_DATA_API_KEY = $privateKey
        Remove-Variable secureKey, privateKey
    } else {
        Remove-Item Env:\TWELVE_DATA_API_KEY -ErrorAction SilentlyContinue
    }

    & $python (Join-Path $repositoryRoot 'scripts\validate-market-data.py')
    if ($LASTEXITCODE -ne 0) { throw 'Market data validation failed.' }
} finally {
    if ($null -eq $previousKey) {
        Remove-Item Env:\TWELVE_DATA_API_KEY -ErrorAction SilentlyContinue
    } else {
        $env:TWELVE_DATA_API_KEY = $previousKey
    }
}
