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
        Read-Host 'Copy ONLY the Twelve Data key to the clipboard now, then press Enter without pasting' -AsSecureString | Out-Null
        $privateKey = (Get-Clipboard -Raw).Trim()
        if ($privateKey -notmatch '^[A-Fa-f0-9]{32}$') {
            throw 'The clipboard does not contain a 32-character API key. Copy only the key after this prompt appears.'
        }
        $env:TWELVE_DATA_API_KEY = $privateKey
        try { Set-Clipboard -Value '' -ErrorAction Stop } catch { }
        Remove-Variable privateKey
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
