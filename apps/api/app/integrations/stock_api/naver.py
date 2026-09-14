from __future__ import annotations

import xml.etree.ElementTree as ET
from datetime import date
from decimal import Decimal
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    import httpx
else:
    try:
        import httpx
    except ImportError:
        httpx = None

from app.integrations.stock_api.base import (
    Instrument,
    InstrumentNotFoundError,
    MarketDataUnavailableError,
    PricePoint,
    StockPriceAdapter,
)

# Curated list of major KRX listed companies
KRX_POPULAR_INSTRUMENTS: list[Instrument] = [
    Instrument(symbol="005930", market="KRX", name="삼성전자", currency="KRW"),
    Instrument(symbol="000660", market="KRX", name="SK하이닉스", currency="KRW"),
    Instrument(symbol="373220", market="KRX", name="LG에너지솔루션", currency="KRW"),
    Instrument(symbol="207940", market="KRX", name="삼성바이오로직스", currency="KRW"),
    Instrument(symbol="005380", market="KRX", name="현대차", currency="KRW"),
    Instrument(symbol="000270", market="KRX", name="기아", currency="KRW"),
    Instrument(symbol="068270", market="KRX", name="셀트리온", currency="KRW"),
    Instrument(symbol="005490", market="KRX", name="POSCO홀딩스", currency="KRW"),
    Instrument(symbol="035420", market="KRX", name="NAVER", currency="KRW"),
    Instrument(symbol="035720", market="KRX", name="카카오", currency="KRW"),
    Instrument(symbol="006400", market="KRX", name="삼성SDI", currency="KRW"),
    Instrument(symbol="051910", market="KRX", name="LG화학", currency="KRW"),
    Instrument(symbol="012330", market="KRX", name="현대모비스", currency="KRW"),
    Instrument(symbol="055550", market="KRX", name="신한지주", currency="KRW"),
    Instrument(symbol="105560", market="KRX", name="KB금융", currency="KRW"),
    Instrument(symbol="028260", market="KRX", name="삼성물산", currency="KRW"),
    Instrument(symbol="247540", market="KRX", name="에코프로비엠", currency="KRW"),
    Instrument(symbol="086520", market="KRX", name="에코프로", currency="KRW"),
    Instrument(symbol="196170", market="KRX", name="알테오젠", currency="KRW"),
    Instrument(symbol="028300", market="KRX", name="HLB", currency="KRW"),
    Instrument(symbol="036570", market="KRX", name="엔씨소프트", currency="KRW"),
    Instrument(symbol="259960", market="KRX", name="크래프톤", currency="KRW"),
    Instrument(symbol="011200", market="KRX", name="HMM", currency="KRW"),
    Instrument(symbol="015760", market="KRX", name="한국전력", currency="KRW"),
    Instrument(symbol="034020", market="KRX", name="두산에너빌리티", currency="KRW"),
    Instrument(symbol="323410", market="KRX", name="카카오뱅크", currency="KRW"),
    Instrument(symbol="042660", market="KRX", name="한화오션", currency="KRW"),
    Instrument(symbol="329180", market="KRX", name="HD현대중공업", currency="KRW"),
    Instrument(symbol="003670", market="KRX", name="포스코퓨처엠", currency="KRW"),
    Instrument(symbol="033780", market="KRX", name="KT&G", currency="KRW"),
    Instrument(symbol="000810", market="KRX", name="삼성화재", currency="KRW"),
    Instrument(symbol="017670", market="KRX", name="SK텔레콤", currency="KRW"),
    Instrument(symbol="086790", market="KRX", name="하나금융지주", currency="KRW"),
    Instrument(symbol="138040", market="KRX", name="메리츠금융지주", currency="KRW"),
    Instrument(symbol="032830", market="KRX", name="삼성생명", currency="KRW"),
    Instrument(symbol="010130", market="KRX", name="고려아연", currency="KRW"),
    Instrument(symbol="066570", market="KRX", name="LG전자", currency="KRW"),
    Instrument(symbol="096770", market="KRX", name="SK이노베이션", currency="KRW"),
    Instrument(symbol="030200", market="KRX", name="KT", currency="KRW"),
    Instrument(symbol="316140", market="KRX", name="우리금융지주", currency="KRW"),
    Instrument(symbol="047810", market="KRX", name="한국항공우주", currency="KRW"),
    Instrument(
        symbol="012450", market="KRX", name="한화에어로스페이스", currency="KRW"
    ),
    Instrument(symbol="003230", market="KRX", name="삼양식품", currency="KRW"),
    Instrument(symbol="058470", market="KRX", name="리노공업", currency="KRW"),
    Instrument(symbol="277810", market="KRX", name="레인보우로보틱스", currency="KRW"),
    Instrument(symbol="214150", market="KRX", name="클래시스", currency="KRW"),
    Instrument(symbol="035900", market="KRX", name="JYP Ent.", currency="KRW"),
    Instrument(symbol="041510", market="KRX", name="에스엠", currency="KRW"),
    Instrument(symbol="352820", market="KRX", name="하이브", currency="KRW"),
]


class NaverStockPriceAdapter(StockPriceAdapter):
    def __init__(
        self,
        client: httpx.AsyncClient | None = None,
        instruments: list[Instrument] | None = None,
    ) -> None:
        self._client = client
        self._instruments = list(instruments or KRX_POPULAR_INSTRUMENTS)

    async def search_instruments(self, query: str) -> list[Instrument]:
        normalized = query.strip().upper()
        if not normalized:
            return []
        return [
            inst
            for inst in self._instruments
            if normalized in inst.name.upper()
            or normalized in inst.symbol.upper()
        ]

    async def get_price_history(
        self,
        market: str,
        symbol: str,
        start_date: date,
        end_date: date,
    ) -> tuple[str, Instrument, list[PricePoint]]:
        matched = next(
            (
                inst
                for inst in self._instruments
                if inst.market.upper() == market.upper()
                and inst.symbol.upper() == symbol.upper()
            ),
            None,
        )
        if matched is None:
            # Check if symbol looks like a 6-digit KRX stock code
            if len(symbol) == 6 and symbol.isdigit() and market.upper() == "KRX":
                matched = Instrument(
                    symbol=symbol,
                    market="KRX",
                    name=f"종목({symbol})",
                    currency="KRW",
                )
            else:
                raise InstrumentNotFoundError(market, symbol)

        today = date.today()
        days_span = max((today - start_date).days + 60, 30)
        # Trading days are roughly 5/7 of calendar days
        estimated_count = min(max(int(days_span * 0.75), 30), 4000)

        url = (
            f"https://fchart.stock.naver.com/sise.nhn?"
            f"symbol={symbol}&timeframe=day&count={estimated_count}&requestType=0"
        )

        if httpx is None:
            raise MarketDataUnavailableError("httpx 패키지가 설치되어 있지 않습니다.")

        try:
            if self._client:
                response = await self._client.get(url, timeout=8.0)
            else:
                async with httpx.AsyncClient(timeout=8.0) as client:
                    response = await client.get(url)

            if response.status_code != 200:
                raise MarketDataUnavailableError(
                    f"네이버 금융 API 응답 오류 (HTTP {response.status_code})"
                )

            xml_bytes = response.content
            # Naver returns EUC-KR encoded XML
            try:
                xml_text = xml_bytes.decode("euc-kr")
            except UnicodeDecodeError:
                xml_text = xml_bytes.decode("utf-8", errors="replace")

            root = ET.fromstring(xml_text)
            chartdata = root.find("chartdata")
            if chartdata is None:
                return "naver_finance", matched, []

            points: list[PricePoint] = []
            for item in chartdata.findall("item"):
                data_attr = item.get("data")
                if not data_attr:
                    continue
                parts = data_attr.split("|")
                if len(parts) < 5:
                    continue
                d_str = parts[0].strip()
                close_str = parts[4].strip()
                if len(d_str) != 8 or not d_str.isdigit():
                    continue

                d = date(int(d_str[:4]), int(d_str[4:6]), int(d_str[6:8]))
                if start_date <= d <= end_date:
                    points.append(
                        PricePoint(date=d, adjusted_close=Decimal(close_str))
                    )

            points.sort(key=lambda pt: pt.date)
            return "naver_finance", matched, points

        except MarketDataUnavailableError:
            raise
        except Exception as exc:
            if httpx is not None and isinstance(exc, httpx.HTTPError):
                raise MarketDataUnavailableError(
                    f"시세 데이터 서버와 통신할 수 없습니다: {exc}"
                ) from exc
            if isinstance(exc, ET.ParseError):
                raise MarketDataUnavailableError(
                    f"시세 데이터 파싱에 실패했습니다: {exc}"
                ) from exc
            raise MarketDataUnavailableError(str(exc)) from exc
