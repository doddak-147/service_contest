import shutil
import subprocess
from pathlib import Path

import pytest

POWERSHELL = shutil.which("powershell.exe")
pytestmark = pytest.mark.skipif(
    POWERSHELL is None, reason="Windows PowerShell required"
)


def fixture_script(tmp_path: Path) -> tuple[Path, Path, Path]:
    root = tmp_path / "fixture-repo"
    scripts = root / "scripts"
    android = root / "apps" / "mobile" / "android"
    scripts.mkdir(parents=True)
    android.mkdir(parents=True)
    script = scripts / "backup-signing.ps1"
    shutil.copyfile(Path(__file__).resolve().parents[1] / script.name, script)
    store = tmp_path / "fictional-keystore.p12"
    store.write_bytes(b"FICTIONAL TEST FILE - NOT A KEY")
    properties = android / "key.properties"
    properties.write_text(f"storeFile={store.as_posix()}\nstorePassword=fictional\n")
    return script, properties, store


def run_script(script: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [
            POWERSHELL,
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(script),
            *args,
        ],
        capture_output=True,
        text=True,
        check=False,
    )


def test_backup_copies_and_verifies_both_fictional_files(tmp_path: Path) -> None:
    script, properties, store = fixture_script(tmp_path)
    destination = tmp_path / "backup"
    result = run_script(script, "-Destination", str(destination))
    assert result.returncode == 0, result.stderr
    folders = list(destination.iterdir())
    assert len(folders) == 1
    assert (folders[0] / properties.name).read_bytes() == properties.read_bytes()
    assert (folders[0] / store.name).read_bytes() == store.read_bytes()
    assert "fictional" not in result.stdout


def test_backup_rejects_repository_destination(tmp_path: Path) -> None:
    script, _, _ = fixture_script(tmp_path)
    destination = script.parent.parent / "output" / "backup"
    result = run_script(script, "-Destination", str(destination))
    assert result.returncode != 0
    assert not destination.exists()


def test_verify_only_preserves_files_without_copying(tmp_path: Path) -> None:
    script, properties, store = fixture_script(tmp_path)
    before = (properties.read_bytes(), store.read_bytes())
    result = run_script(script, "-VerifyOnly")
    assert result.returncode == 0
    assert (properties.read_bytes(), store.read_bytes()) == before
    assert "No backup was created" in result.stdout
