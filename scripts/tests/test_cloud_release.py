import hashlib
import io
import json
import runpy
import tarfile
from pathlib import Path
from unittest.mock import Mock, patch

import pytest

ROOT = Path(__file__).resolve().parents[2]
MODULE = runpy.run_path(str(ROOT / "deploy/cloud/apply-release.py"))
PREPARE = runpy.run_path(str(ROOT / "scripts/prepare-cloud-release.py"))


def archive_fixture(tmp_path: Path, extra: tarfile.TarInfo | None = None) -> Path:
    data = b"# fictional source\n"
    manifest = {
        "release_id": "api-1.2.0-" + "a" * 12,
        "source_commit": "a" * 40,
        "files": {"app/main.py": hashlib.sha256(data).hexdigest()},
    }
    archive = tmp_path / "release.tar.gz"
    with tarfile.open(archive, "w:gz") as package:
        for name, content in {
            "app/main.py": data,
            "release.json": json.dumps(manifest).encode(),
        }.items():
            info = tarfile.TarInfo(name)
            info.size = len(content)
            package.addfile(info, io.BytesIO(content))
        if extra is not None:
            package.addfile(extra, io.BytesIO(b""))
    return archive


def test_only_manifest_verified_sources_can_be_deployed(tmp_path: Path) -> None:
    archive = archive_fixture(tmp_path)
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    manifest, files = MODULE["validate_archive"](archive, digest)
    assert manifest["source_commit"] == "a" * 40
    assert set(files) == {"app/main.py", "release.json"}
    with pytest.raises(ValueError, match="checksum"):
        MODULE["validate_archive"](archive, "0" * 64)


@pytest.mark.parametrize(
    "name", ["../escape.py", "/tmp/x.py", "app/.env", "app/main.py"]
)
def test_archive_rejects_traversal_secrets_and_duplicate_members(
    tmp_path: Path, name: str
) -> None:
    archive = archive_fixture(tmp_path, tarfile.TarInfo(name))
    with pytest.raises(ValueError, match="Unsafe"):
        MODULE["validate_archive"](
            archive, hashlib.sha256(archive.read_bytes()).hexdigest()
        )


def test_archive_rejects_symlink(tmp_path: Path) -> None:
    extra = tarfile.TarInfo("app/link.py")
    extra.type = tarfile.SYMTYPE
    extra.linkname = "/etc/service-contest.env"
    archive = archive_fixture(tmp_path, extra)
    with pytest.raises(ValueError, match="Unsafe"):
        MODULE["validate_archive"](
            archive, hashlib.sha256(archive.read_bytes()).hexdigest()
        )


def test_preparation_excludes_untracked_secrets_and_local_environments(
    tmp_path: Path,
) -> None:
    source = tmp_path / "apps/api/app/main.py"
    source.parent.mkdir(parents=True)
    source.write_text("# fictional\n")
    (source.parent / ".env").write_text("FAKE_SECRET=do-not-package")
    (source.parent / "__pycache__").mkdir()
    with patch(
        "subprocess.check_output", side_effect=["b" * 40, "apps/api/app/main.py"]
    ):
        archive = PREPARE["prepare_release"](tmp_path)
    manifest, files = MODULE["validate_archive"](
        archive, hashlib.sha256(archive.read_bytes()).hexdigest()
    )
    assert set(files) == {"app/main.py", "release.json"}
    assert manifest["source_commit"] == "b" * 40


def test_rollback_restores_exact_previous_override_before_restart(
    tmp_path: Path,
) -> None:
    rollback = MODULE["restore_override"]
    drop_in = tmp_path / "release.conf"
    drop_in.write_text("new")
    backup = tmp_path / "backup"
    backup.mkdir()
    (backup / "previous.conf").write_text("original")
    runner = Mock()
    health = Mock()
    with patch.dict(
        rollback.__globals__, DROP_IN=drop_in, command=runner, wait_for_health=health
    ):
        rollback(backup)
    assert drop_in.read_text() == "original"
    assert runner.call_args_list[-1].args == (
        "systemctl",
        "restart",
        "service-contest-api.service",
    )
    health.assert_called_once_with("http://127.0.0.1:8000")


def test_override_forces_production_provider_off_after_environment_file() -> None:
    text = MODULE["service_override"](Path("/opt/service-contest/releases/fictional"))
    assert (
        "ExecStart=\nExecStart=/usr/bin/env APP_ENV=production "
        "STOCK_DATA_PROVIDER=disabled "
        in text
    )
    assert "--host 127.0.0.1 --port 8000" in text
    assert "API_KEY" not in text


def test_live_check_failure_restores_previous_service(tmp_path: Path) -> None:
    deploy = MODULE["deploy"]
    drop_in = tmp_path / "systemd/release.conf"
    env_file = tmp_path / "server-only.env"
    env_file.write_text("# no credentials in this fixture")
    restore = Mock()
    runner = Mock(return_value="service-contest")
    with (
        patch.dict(
            deploy.__globals__,
            ROOT=tmp_path / "installation",
            DROP_IN=drop_in,
            ENV_FILE=str(env_file),
            command=runner,
            validate_archive=Mock(
                return_value=(
                    {"release_id": "api-1.2.0-" + "a" * 12},
                    {"app/main.py": b"# test"},
                )
            ),
            wait_for_health=Mock(),
            smoke_test=Mock(side_effect=[{}, RuntimeError("failed live check")]),
            restore_override=restore,
        ),
        patch("subprocess.run"),
        pytest.raises(RuntimeError, match="failed live check"),
    ):
        deploy(tmp_path / "ignored.tar.gz", "a" * 64)
    restore.assert_called_once_with(
        tmp_path / "installation/deploy-backups" / ("api-1.2.0-" + "a" * 12)
    )


def test_smoke_checks_real_application_and_detects_arithmetic_mismatch(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.syspath_prepend(str(ROOT / "apps/api"))
    from app.main import create_app
    from app.shared.config import Settings
    from fastapi.testclient import TestClient

    app = create_app(Settings(app_env="production", cors_origins=()))
    smoke = MODULE["smoke_test"]
    with TestClient(app) as client:

        def request(base: str, path: str, payload: dict | None = None) -> tuple:
            response = (
                client.get(path) if payload is None else client.post(path, json=payload)
            )
            return response.status_code, response.json()

        with patch.dict(smoke.__globals__, request_json=request):
            result = smoke("http://fictional")
        assert result["quiz_source"] == "template"
        assert result["stock_provider"] == "disabled"

        def incorrect_cash(base: str, path: str, payload: dict | None = None) -> tuple:
            status, body = request(base, path, payload)
            if path.endswith("/cash-flow"):
                body["shocked"]["ending_cash_balance_krw"] += 1
            return status, body

        with (
            patch.dict(smoke.__globals__, request_json=incorrect_cash),
            pytest.raises(RuntimeError, match="arithmetic"),
        ):
            smoke("http://fictional")
