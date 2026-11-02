"""Root-only, reversible deployment using the existing server's Python environment.

No credentials are read by this script. systemd loads the existing server-only
environment file. A transient service validates the release before switching.
"""

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import tarfile
import time
from pathlib import Path, PurePosixPath
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

ROOT = Path("/opt/service-contest")
SERVICE = "service-contest-api.service"
PYTHON = ROOT / ".venv/bin/python"
DROP_IN = Path("/etc/systemd/system") / (SERVICE + ".d/90-risk-lens-release.conf")
ENV_FILE = "/etc/service-contest.env"


def command(*args: str) -> str:
    result = subprocess.run(args, capture_output=True, text=True, check=False)
    if result.returncode:
        # Do not relay environment values or service logs to the client.
        raise RuntimeError("Command failed: " + args[0])
    return result.stdout.strip()


def validate_archive(
    archive: Path, expected_hash: str
) -> tuple[dict, dict[str, bytes]]:
    if hashlib.sha256(archive.read_bytes()).hexdigest() != expected_hash:
        raise ValueError("Package checksum mismatch")
    contents = {}
    with tarfile.open(archive, "r:gz") as package:
        for member in package.getmembers():
            name = member.name
            parts = PurePosixPath(name).parts
            if (
                not member.isfile()
                or name in contents
                or "\\" in name
                or ".." in parts
                or PurePosixPath(name).is_absolute()
                or name != PurePosixPath(name).as_posix()
                or member.size > 2_000_000
                or not (
                    name in {"requirements.txt", "release.json"}
                    or (name.startswith("app/") and name.endswith(".py"))
                )
            ):
                raise ValueError("Unsafe or unexpected archive member")
            source = package.extractfile(member)
            if source is None:
                raise ValueError("Missing archive member")
            contents[name] = source.read()
    manifest = json.loads(contents["release.json"])
    if not re.fullmatch(r"api-1\.2\.0-[a-f0-9]{12}", manifest["release_id"]):
        raise ValueError("Invalid release identity")
    if (
        not re.fullmatch(r"[a-f0-9]{40}", manifest["source_commit"])
        or not manifest["release_id"].endswith(manifest["source_commit"][:12])
        or set(manifest["files"]) != set(contents) - {"release.json"}
        or "app/main.py" not in manifest["files"]
    ):
        raise ValueError("Invalid release manifest")
    for name, digest in manifest["files"].items():
        if hashlib.sha256(contents[name]).hexdigest() != digest:
            raise ValueError("Source checksum mismatch")
    return manifest, contents


def request_json(base: str, path: str, payload: dict | None = None) -> tuple[int, dict]:
    data = None if payload is None else json.dumps(payload).encode()
    request = Request(
        base + path,
        data=data,
        headers={"Content-Type": "application/json"},
    )
    try:
        with urlopen(request, timeout=60) as response:
            return response.status, json.load(response)
    except HTTPError as error:
        return error.code, json.load(error)


def wait_for_health(base: str) -> None:
    for _ in range(30):
        try:
            status, body = request_json(base, "/health")
            if status == 200 and body.get("status") == "ok":
                return
        except (URLError, TimeoutError, OSError, ValueError):
            pass
        time.sleep(1)
    raise RuntimeError("Health check failed")


def smoke_test(base: str, *, quiz: bool = True) -> dict:
    """Only synthetic, non-provider inputs. Compare actual arithmetic, not just 200."""
    profile = {
        "monthly_income_krw": 3_000_000,
        "monthly_fixed_expenses_krw": 1_500_000,
        "emergency_fund_krw": 5_000_000,
        "existing_loan_balance_krw": 10_000_000,
        "monthly_debt_payment_krw": 400_000,
        "planned_investment_krw": 10_000_000,
        "equity_amount_krw": 6_000_000,
        "borrowed_amount_krw": 4_000_000,
        "annual_loan_rate": 0.06,
    }
    status, financial = request_json(base, "/api/v1/financial-health/analyze", profile)
    if status != 200 or financial["estimated_monthly_interest_krw"] != 20_000:
        raise RuntimeError("Financial health smoke check failed")
    status, cash = request_json(
        base,
        "/api/v1/stress-tests/cash-flow",
        {
            "financial_profile": profile,
            "months": 6,
            "income_change_rate": -0.2,
            "expense_change_rate": 0.1,
            "loan_rate_change": 0.02,
        },
    )
    if (
        status != 200
        or cash["baseline"]["ending_cash_balance_krw"] != 11_480_000
        or cash["shocked"]["ending_cash_balance_krw"] != 6_939_998
        or cash["shocked"]["total_interest_krw"] != 160_002
    ):
        raise RuntimeError("Cash flow arithmetic smoke check failed")
    status, stress = request_json(
        base,
        "/api/v1/stress-tests/analyze",
        {
            "financial_profile": profile,
            "historical_mdd_rate": None,
            "custom_return_rate": -0.175,
        },
    )
    if status != 200 or not any(
        row["investment_loss_krw"] == 1_750_000 for row in stress
    ):
        raise RuntimeError("Existing stress test smoke check failed")
    status, market = request_json(base, "/api/v1/instruments/search?q=AAPL")
    if status != 503 or market["error"]["code"] != "MARKET_DATA_UNAVAILABLE":
        raise RuntimeError("Market provider must stay disabled")
    result = {"health": "ok", "cash_flow": "ok", "stock_provider": "disabled"}
    if quiz:
        status, questions = request_json(
            base, "/api/v1/risk-learning/quizzes", {"seed": 42}
        )
        if (
            status != 200
            or len(questions["questions"]) != 5
            or len({q["topic"] for q in questions["questions"]}) != 5
            or not all(
                0 <= q["correct_index"] < len(q["options"])
                for q in questions["questions"]
            )
        ):
            raise RuntimeError("Quiz smoke check failed")
        result["quiz_source"] = questions["source"]
        result["quiz_fallback_reason"] = questions.get("fallback_reason")
    return result


def service_override(release: Path) -> str:
    return (
        "[Service]\n"
        f"WorkingDirectory={release}\n"
        "ExecStart=\n"
        "ExecStart=/usr/bin/env APP_ENV=production STOCK_DATA_PROVIDER=disabled "
        f"{PYTHON} -m uvicorn app.main:app --host 127.0.0.1 --port 8000\n"
    )


def restore_override(backup: Path) -> None:
    previous = backup / "previous.conf"
    if previous.exists():
        shutil.copyfile(previous, DROP_IN)
    elif (backup / "no-previous-override").exists():
        DROP_IN.unlink(missing_ok=True)
    else:
        raise RuntimeError("Rollback metadata is missing")
    command("systemctl", "daemon-reload")
    command("systemctl", "restart", SERVICE)
    wait_for_health("http://127.0.0.1:8000")


def deploy(archive: Path, digest: str) -> None:
    manifest, contents = validate_archive(archive, digest)
    release_id = manifest["release_id"]
    release = ROOT / "releases" / release_id
    backup = ROOT / "deploy-backups" / release_id
    if release.exists() or backup.exists():
        raise RuntimeError("Release already exists; preserve it and use a new release")
    if (
        command("systemctl", "show", SERVICE, "-p", "User", "--value")
        != "service-contest"
    ):
        raise RuntimeError("Unexpected service account")
    if not Path(ENV_FILE).is_file():
        raise RuntimeError("Existing server environment file is missing")
    command("nginx", "-t")
    command(str(PYTHON), "-c", "import fastapi,pydantic,httpx,uvicorn,zoneinfo")
    release.mkdir(parents=True, mode=0o755)
    for name, data in contents.items():
        destination = release / name
        destination.parent.mkdir(parents=True, exist_ok=True, mode=0o755)
        destination.write_bytes(data)
        destination.chmod(0o644)
    command(str(PYTHON), "-m", "compileall", "-q", str(release / "app"))
    stage = "risk-lens-stage-" + release_id
    switched = False
    try:
        command(
            "systemd-run",
            "--quiet",
            "--unit=" + stage,
            "--property=User=service-contest",
            "--property=Group=service-contest",
            "--property=WorkingDirectory=" + str(release),
            "--property=EnvironmentFile=" + ENV_FILE,
            "/usr/bin/env",
            "APP_ENV=production",
            "STOCK_DATA_PROVIDER=disabled",
            str(PYTHON),
            "-m",
            "uvicorn",
            "app.main:app",
            "--host",
            "127.0.0.1",
            "--port",
            "18000",
            "--no-access-log",
        )
        wait_for_health("http://127.0.0.1:18000")
        stage_result = smoke_test("http://127.0.0.1:18000")
        print("PASS: staged release " + json.dumps(stage_result), flush=True)
        backup.mkdir(parents=True, mode=0o700)
        if DROP_IN.exists():
            shutil.copyfile(DROP_IN, backup / "previous.conf")
        else:
            (backup / "no-previous-override").touch()
        # Preserve originals; only our specific service drop-in is replaced.
        DROP_IN.parent.mkdir(parents=True, exist_ok=True)
        temporary = DROP_IN.with_suffix(".pending")
        temporary.write_text(service_override(release), encoding="utf-8")
        temporary.chmod(0o644)
        temporary.replace(DROP_IN)
        switched = True
        command("systemctl", "daemon-reload")
        command("systemctl", "restart", SERVICE)
        wait_for_health("http://127.0.0.1:8000")
        live_result = smoke_test("http://127.0.0.1:8000")
        print("PASS: live release " + json.dumps(live_result), flush=True)
        print("PASS: release_id=" + release_id, flush=True)
        print(
            "Rollback: python3 "
            + str(Path(__file__).resolve())
            + " --rollback "
            + release_id,
            flush=True,
        )
    except Exception:
        if switched:
            restore_override(backup)
            print(
                "PASS: previous service restored after deployment failure", flush=True
            )
        raise
    finally:
        subprocess.run(["systemctl", "stop", stage], capture_output=True, check=False)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--archive", type=Path)
    parser.add_argument("--sha256")
    parser.add_argument("--rollback")
    args = parser.parse_args()
    if os.name != "posix" or os.geteuid() != 0:
        parser.error("Run on the Ubuntu server as root")
    try:
        if args.rollback:
            if not re.fullmatch(r"api-1\.2\.0-[a-f0-9]{12}", args.rollback):
                raise ValueError("Invalid rollback release")
            expected = service_override(ROOT / "releases" / args.rollback)
            if not DROP_IN.exists() or DROP_IN.read_text() != expected:
                raise RuntimeError(
                    "Current override differs; do not undo another release"
                )
            restore_override(ROOT / "deploy-backups" / args.rollback)
            print("PASS: previous service restored")
        else:
            if not args.archive or not re.fullmatch(r"[a-f0-9]{64}", args.sha256 or ""):
                parser.error("--archive and --sha256 are required")
            deploy(args.archive, args.sha256)
    except (RuntimeError, ValueError, KeyError, OSError, tarfile.TarError) as error:
        # No raw provider responses, environments or journal output.
        print("FAIL: " + str(error))
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
