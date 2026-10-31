import contextlib
import io
import runpy
from pathlib import Path
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / "audit-server-logs.py"
MODULE = runpy.run_path(str(SCRIPT))


def test_secret_parser_ignores_comments_and_non_secret_settings() -> None:
    values = MODULE["read_secret_values"](
        "# LLM_API_KEY=comment-secret-value\n"
        "APP_ENV=production\n"
        'LLM_API_KEY="fictional-secret-value"\n'
        "export TWELVE_DATA_API_KEY=fictional-stock-key\n"
        "EMPTY_API_KEY=\n"
    )
    assert values == ["fictional-secret-value", "fictional-stock-key"]


def test_counts_find_unlabelled_secret_and_financial_fields_without_output() -> None:
    output = io.StringIO()
    with contextlib.redirect_stdout(output):
        result = MODULE["count_matches"](
            [
                "GET /health 200\n",
                "unlabelled fictional-secret-value\n",
                'payload={"monthly_income_krw": 1234567}\n',
                "Authorization: Bearer fictional-secret-value\n",
            ],
            ["fictional-secret-value"],
        )
    assert result == (4, 2, 2)
    assert output.getvalue() == ""


def test_main_does_not_print_sensitive_environment_read_error() -> None:
    output = io.StringIO()
    with (
        patch.object(Path, "read_text", side_effect=OSError("fictional-secret-value")),
        contextlib.redirect_stdout(output),
    ):
        result = MODULE["main"]()
    assert result == 1
    assert "fictional-secret-value" not in output.getvalue()
    assert "ERROR:" in output.getvalue()


def test_main_prints_only_counts_when_secret_is_found() -> None:
    output = io.StringIO()
    with (
        patch.object(
            Path, "read_text", return_value="LLM_API_KEY=fictional-secret-value"
        ),
        patch("subprocess.Popen") as popen,
        contextlib.redirect_stdout(output),
    ):
        process = popen.return_value.__enter__.return_value
        process.stdout = iter(["unlabelled fictional-secret-value\n"])
        process.wait.return_value = 0
        result = MODULE["main"]()
    assert result == 0
    assert output.getvalue() == (
        "journal_lines=1\nsecret_values_checked=1\n"
        "secret_lines=1\nsensitive_field_lines=0\n"
    )
