from fastapi.testclient import TestClient

from app.main import create_app
from app.shared.config import Settings


def test_full_user_flow_keeps_calculations_and_explanation_consistent() -> None:
    app = create_app(
        Settings(
            app_env="test",
            cors_origins=(),
            stock_data_provider="fake",
        )
    )
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

    with TestClient(app) as client:
        assert client.get("/health").status_code == 200
        financial = client.post(
            "/api/v1/financial-health/analyze", json=profile
        )
        search = client.get("/api/v1/instruments/search?q=005930")
        market = client.get(
            "/api/v1/market-risk/KRX/005930"
            "?start_date=2025-01-01&end_date=2025-12-31"
        )
        instrument = search.json()[0]
        combined = client.post(
            "/api/v1/combined-analyses",
            json={
                "financial_profile": profile,
                "instrument": instrument,
                "period_start": "2025-01-01",
                "period_end": "2025-12-31",
            },
        )
        report = combined.json()
        impact = report["mdd_impact"]
        explanation_payload = {
            "scenario_key": impact["scenario_key"],
            "assumed_return_rate": impact["assumed_return_rate"],
            "investment_loss_krw": impact["investment_loss_krw"],
            "loss_to_equity_ratio": impact["loss_to_equity_ratio"],
            "loss_to_emergency_fund_ratio": impact[
                "loss_to_emergency_fund_ratio"
            ],
            "loss_to_monthly_fixed_expenses": impact[
                "loss_to_monthly_fixed_expenses"
            ],
            "net_investment_equity_krw": impact[
                "net_investment_equity_krw"
            ],
            "estimated_monthly_interest_krw": impact[
                "estimated_monthly_interest_krw"
            ],
            "market_max_drawdown_rate": report["market_risk"][
                "max_drawdown_rate"
            ],
            "warnings": report["warnings"],
        }
        explanation = client.post(
            "/api/v1/explanations", json=explanation_payload
        )

    assert financial.status_code == 200
    assert search.status_code == 200
    assert market.status_code == 200
    assert combined.status_code == 200
    assert explanation.status_code == 200
    assert impact["assumed_return_rate"] == report["market_risk"][
        "max_drawdown_rate"
    ]
    assert report["scenarios"][-1] == impact
    assert explanation.json()["source"] == "template"
    assert f"{impact['investment_loss_krw']:,}원" in explanation.json()[
        "summary"
    ]
