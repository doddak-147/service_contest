import shutil
import subprocess
from pathlib import Path

import pytest

POWERSHELL = shutil.which("powershell.exe")
pytestmark = pytest.mark.skipif(
    POWERSHELL is None, reason="Windows PowerShell required"
)


def test_secret_prompt_retries_busy_clipboard_and_supports_direct_paste(
    tmp_path: Path,
) -> None:
    script = Path(__file__).resolve().parents[1] / "start-local-api.ps1"
    # Load only the key input function; never launch the server or read real keys.
    fixture = tmp_path / "input-fixture.ps1"
    fixture.write_text(
        r"""
param([string]$Source)
$ErrorActionPreference = 'Stop'
$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    $Source, [ref]$tokens, [ref]$errors)
if ($errors) { throw 'Parse error' }
$function = $ast.Find({ param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Read-RiskLensApiKey'
}, $true)
Invoke-Expression $function.Extent.Text
$script:reads = 0
$PasteKeys = $false
function Read-Host { param($Prompt, [switch]$AsSecureString); return $null }
function Start-Sleep { param($Milliseconds) }
function Set-Clipboard { param($Value) }
function Get-Clipboard {
    param([switch]$Raw)
    $script:reads++
    if ($script:reads -lt 3) { throw 'Clipboard busy' }
    return ('z' * 32)
}
$value = Read-RiskLensApiKey 'Fictional'
if ($script:reads -ne 3 -or $value.Length -ne 32) { throw 'Retry failed' }
$PasteKeys = $true
function Read-Host {
    param($Prompt, [switch]$AsSecureString)
    return ConvertTo-SecureString ('y' * 32) -AsPlainText -Force
}
$value = Read-RiskLensApiKey 'Fictional'
if ($script:reads -ne 3 -or $value.Length -ne 32) { throw 'Paste input failed' }
Write-Output 'PASS'
""",
        encoding="utf-8",
    )
    result = subprocess.run(
        [
            POWERSHELL,
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(fixture),
            "-Source",
            str(script),
        ],
        capture_output=True,
        text=True,
        timeout=20,
    )
    assert result.returncode == 0, result.stderr
    assert result.stdout.strip() == "PASS"
