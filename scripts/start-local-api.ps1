# Run from the repository root. Keys are not written to files or command history.
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath '.\.venv\Scripts\python.exe')) {
    throw 'Run this script from the repository root. Python venv was not found.'
}

$listener = Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue
if ($listener) {
    throw 'Port 8000 is in use. Stop the existing API with Ctrl+C and retry.'
}

try {
    $null = Read-Host 'Copy ONLY the Twelve Data key, then press Enter' -AsSecureString
    $env:TWELVE_DATA_API_KEY = ([string](Get-Clipboard -Raw)).Trim()
    if ($env:TWELVE_DATA_API_KEY -notmatch '^[A-Za-z0-9]{24,64}$') {
        throw 'Twelve Data key format is invalid. Copy only the key, not a command or URL.'
    }

    $null = Read-Host 'Copy ONLY the OpenAI API key, then press Enter' -AsSecureString
    $env:LLM_API_KEY = ([string](Get-Clipboard -Raw)).Trim()
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
