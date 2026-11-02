"""Count possible sensitive log entries without displaying log or secret values."""

import re
import subprocess
from collections.abc import Iterable
from pathlib import Path

SENSITIVE_FIELDS = re.compile(
    r"authorization|bearer\s+\S+|apikey=|monthly_income_krw|"
    r"monthly_expenses_krw|emergency_fund_krw|financial_profile",
    re.IGNORECASE,
)


def read_secret_values(environment_text: str) -> list[str]:
    values: set[str] = set()
    for raw in environment_text.splitlines():
        line = raw.strip()
        if line.startswith("#") or "=" not in line:
            continue
        name, value = line.split("=", 1)
        name = name.removeprefix("export ").strip()
        if not name.endswith(("_API_KEY", "_TOKEN", "_SECRET")):
            continue
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]
        if len(value) >= 12:
            values.add(value)
    return sorted(values)


def count_matches(lines: Iterable[str], secrets: list[str]) -> tuple[int, int, int]:
    total = secret_lines = field_lines = 0
    for line in lines:
        total += 1
        secret_lines += int(any(secret in line for secret in secrets))
        field_lines += int(bool(SENSITIVE_FIELDS.search(line)))
    return total, secret_lines, field_lines


def main() -> int:
    try:
        environment_text = Path("/etc/service-contest.env").read_text()
    except (OSError, UnicodeError):
        print(
            "ERROR: Cannot read the server environment file. Run on the server as root."
        )
        return 1
    secrets = read_secret_values(environment_text)
    if not secrets:
        print("ERROR: No API secret values found; the audit is incomplete.")
        return 1
    try:
        with subprocess.Popen(
            [
                "journalctl",
                "-u",
                "service-contest-api.service",
                "--since",
                "2026-09-26",
                "--no-pager",
                "--quiet",
                "-o",
                "cat",
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            errors="replace",
        ) as process:
            assert process.stdout is not None
            total, secret_lines, field_lines = count_matches(process.stdout, secrets)
            if process.wait() != 0:
                print("ERROR: Cannot read service logs; the audit is incomplete.")
                return 1
    except OSError:
        print("ERROR: journalctl could not run; the audit is incomplete.")
        return 1
    print(f"journal_lines={total}")
    print(f"secret_values_checked={len(secrets)}")
    print(f"secret_lines={secret_lines}")
    print(f"sensitive_field_lines={field_lines}")
    if total == 0:
        print("WARNING: No retained service log lines found; the audit is incomplete.")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
