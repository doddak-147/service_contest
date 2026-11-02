param([switch]$PasteKeys)

# Run from the repository root. Keys are not written to files or command history.
$ErrorActionPreference = 'Stop'

function Read-RiskLensApiKey {
    param([string]$Provider)
    if ($PasteKeys) {
        $secureKey = Read-Host "Paste ONLY the $Provider key, then press Enter" -AsSecureString
        try {
            return [System.Net.NetworkCredential]::new('', $secureKey).Password.Trim()
        } finally {
            $secureKey.Dispose()
            try { Set-Clipboard -Value '' -ErrorAction Stop } catch { }
        }
    }
    $null = Read-Host "Copy ONLY the $Provider key to the clipboard now; press Enter WITHOUT pasting" -AsSecureString
    for ($attempt = 0; $attempt -lt 10; $attempt++) {
        try {
            $value = ([string](Get-Clipboard -Raw -ErrorAction Stop)).Trim()
            try { Set-Clipboard -Value '' -ErrorAction Stop } catch { }
            return $value
        } catch {
            if ($attempt -eq 9) {
                throw 'The clipboard is busy. Run .\scripts\start-local-api.ps1 -PasteKeys and paste each key at its hidden prompt.'
            }
            Start-Sleep -Milliseconds 200
        }
    }
}

if (-not (Test-Path -LiteralPath '.\.venv\Scripts\python.exe')) {
    throw 'Run this script from the repository root. Python venv was not found.'
}

$listener = Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue
if ($listener) {
    throw 'Port 8000 is in use. Stop the existing API with Ctrl+C and retry.'
}

try {
    $env:TWELVE_DATA_API_KEY = Read-RiskLensApiKey 'Twelve Data'
    if ($env:TWELVE_DATA_API_KEY -notmatch '^[A-Za-z0-9]{24,64}$') {
        throw 'Twelve Data key format is invalid. Copy only the key, not a command or URL.'
    }

    $env:LLM_API_KEY = Read-RiskLensApiKey 'OpenAI'
    if ($env:LLM_API_KEY -notmatch '^sk-[A-Za-z0-9_-]{16,}$') {
        throw 'OpenAI key format is invalid. Copy only the key, not a command or URL.'
    }

    $env:APP_ENV = 'development'
    $env:STOCK_DATA_PROVIDER = 'twelve'
    $env:LLM_PROVIDER = 'openai_compatible'
    $env:LLM_API_URL = 'https://api.openai.com/v1/chat/completions'
    $env:LLM_MODEL = 'gpt-4o-mini'

    Write-Host 'Starting the local API with market data and AI explanation. Keys will not be printed.'
    & .\.venv\Scripts\python.exe -m uvicorn app.main:app --app-dir apps/api --reload --host 127.0.0.1 --port 8000
}
finally {
    Remove-Item Env:TWELVE_DATA_API_KEY -ErrorAction SilentlyContinue
    Remove-Item Env:LLM_API_KEY -ErrorAction SilentlyContinue
}
