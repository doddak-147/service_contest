"""Local-only market data spot check; never saves provider responses."""

import asyncio
import csv
import math
import os
import statistics
import sys
from datetime import date
from decimal import Decimal
from io import StringIO
from pathlib import Path

import httpx

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "apps" / "api"))

from app.features.market_risk.calculation import calculate_market_risk
from app.integrations.stock_api.twelve import TwelveStockPriceAdapter


async def main() -> None:
    start, end = date(2020, 8, 27), date(2020, 9, 2)
    async with httpx.AsyncClient(timeout=15) as client:
        raw = (
            await client.get(
                "https://api.twelvedata.com/time_series",
                params={
                    "symbol": "AAPL",
                    "interval": "1day",
                    "start_date": start.isoformat(),
                    "end_date": f"{end.isoformat()}T23:59:59",
                    "adjust": "splits",
                    "apikey": "demo",
                },
            )
        ).json()
        assert raw["status"] == "ok"
        closes = {
            date.fromisoformat(row["datetime"]): Decimal(row["close"])
            for row in raw["values"]
        }
        # https://www.sec.gov/Archives/edgar/data/1053092/000095010320017274/dp135904_424b2-k1586.htm
        # https://www.sec.gov/Archives/edgar/data/1666268/000095010320017171/dp135844_fwp-ps4872msfl.htm
        # https://investor.apple.com/investor-relations/faq/default.aspx
        # The SEC filings give the pre/post-split closes; Apple confirms 4:1.
        assert abs(closes[date(2020, 8, 28)] - Decimal("499.23") / 4) < Decimal("0.001")
        assert abs(closes[date(2020, 8, 31)] - Decimal("129.04")) < Decimal("0.001")
        assert abs(closes[date(2020, 8, 31)] / closes[date(2020, 8, 28)] - 1) < Decimal(
            "0.2"
        )
        print("PASS: split-adjusted USD closes match independent SEC filings")

        adapter = TwelveStockPriceAdapter("demo", client=client)
        source, instrument, points = await adapter.get_price_history(
            "NASDAQ", "AAPL", start, end
        )
        assert len(points) == len(closes)
        fx_csv = (
            await client.get(
                "https://data-api.ecb.europa.eu/service/data/EXR/D.USD+KRW.EUR.SP00.A",
                params={
                    "startPeriod": "2020-08-20",
                    "endPeriod": end.isoformat(),
                    "format": "csvdata",
                },
            )
        ).text
        eur_rates: dict[date, dict[str, Decimal]] = {}
        for row in csv.DictReader(StringIO(fx_csv)):
            if row["CURRENCY"] in {"USD", "KRW"} and row["OBS_STATUS"] == "A":
                day = date.fromisoformat(row["TIME_PERIOD"])
                eur_rates.setdefault(day, {})[row["CURRENCY"]] = Decimal(
                    row["OBS_VALUE"]
                )
        for point in points:
            fx_day = max(day for day in eur_rates if day <= point.date)
            usd_per_eur = eur_rates[fx_day]["USD"]
            krw_per_eur = eur_rates[fx_day]["KRW"]
            expected_krw = closes[point.date] * krw_per_eur / usd_per_eur
            assert point.fx_date == fx_day
            assert abs(point.adjusted_close - expected_krw) < Decimal("0.000001")
        calc = calculate_market_risk(instrument, points, start, end, source)
        prices = [point.adjusted_close for point in points]
        independent_return = prices[-1] / prices[0] - 1
        independent_drawdown = min(
            (price / max(prices[: index + 1])) - 1 for index, price in enumerate(prices)
        )
        daily_returns = [
            float(prices[index] / prices[index - 1] - 1)
            for index in range(1, len(prices))
        ]
        independent_volatility = statistics.stdev(daily_returns) * math.sqrt(252)
        assert abs(calc.period_return_rate - independent_return) < Decimal("0.000001")
        assert abs(calc.max_drawdown_rate - independent_drawdown) < Decimal("0.000001")
        assert (
            abs(float(calc.annualized_volatility) - independent_volatility) < 0.000001
        )
        assert calc.fx_rate_as_of is not None
        assert all(
            point.fx_date is not None and point.fx_date <= point.date
            for point in points
        )
        print(
            "PASS: KRW return, MDD, volatility and FX date agree with independent arithmetic"
        )

        private_key = os.environ.get("TWELVE_DATA_API_KEY", "").strip()
        if private_key:
            amazon_raw = (
                await client.get(
                    "https://api.twelvedata.com/time_series",
                    params={
                        "symbol": "AMZN",
                        "interval": "1day",
                        "start_date": "2022-06-02",
                        "end_date": "2022-06-07T23:59:59",
                        "adjust": "splits",
                    },
                    headers={"Authorization": f"apikey {private_key}"},
                )
            ).json()
            assert amazon_raw["status"] == "ok"
            amazon_closes = {
                date.fromisoformat(row["datetime"]): Decimal(row["close"])
                for row in amazon_raw["values"]
            }
            # https://www.sec.gov/comments/s7-30-22/s73022-20163328-333796.pdf
            # https://www.sec.gov/Archives/edgar/data/1665650/000182912622013265/jpm_424b2.htm
            # https://ir.aboutamazon.com/faqs/default.aspx
            # The pre-split SEC-comment figure is rounded to whole dollars.
            assert abs(amazon_closes[date(2022, 6, 3)] - Decimal(2447) / 20) < Decimal(
                "0.03"
            )
            assert abs(amazon_closes[date(2022, 6, 6)] - Decimal("124.79")) < Decimal(
                "0.001"
            )
            assert abs(
                amazon_closes[date(2022, 6, 6)] / amazon_closes[date(2022, 6, 3)] - 1
            ) < Decimal("0.2")
            print(
                "PASS: second stock (AMZN) split-adjusted closes match independent filings"
            )
        else:
            print(
                "SKIP: second stock requires private API key in this shell's environment"
            )


asyncio.run(main())
