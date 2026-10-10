"""Check that the ECB public reference-rate feed is reachable and recent."""

import asyncio
from datetime import UTC, datetime, timedelta

from app.integrations.stock_api.ecb_fx import EcbFxAdapter


async def main() -> None:
    today = datetime.now(UTC).date()
    rates = await EcbFxAdapter().get_usd_krw(today - timedelta(days=14), today)
    latest = max(rates)
    if latest < today - timedelta(days=7):
        raise SystemExit(f"ECB FX reference rates are stale: {latest}")
    print(f"ECB USD/KRW reference source available; latest date: {latest}")


if __name__ == "__main__":
    asyncio.run(main())
