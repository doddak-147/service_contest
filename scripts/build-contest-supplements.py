"""Create reviewed contest PDFs from final video frames and local evidence.

Private source images and derived market figures stay in ignored local folders.
PDF-only libraries live under tmp/proposal-tools, outside application dependencies.
"""

from __future__ import annotations

import json
import sys
from html import escape
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tmp/proposal-tools"))
from pypdf import PdfReader, PdfWriter  # noqa: E402
from pypdf.generic import (  # noqa: E402
    ArrayObject,
    DictionaryObject,
    FloatObject,
    NameObject,
    TextStringObject,
)
from reportlab.lib import colors  # noqa: E402
from reportlab.lib.pagesizes import A4, landscape  # noqa: E402
from reportlab.lib.styles import ParagraphStyle  # noqa: E402
from reportlab.lib.utils import ImageReader  # noqa: E402
from reportlab.pdfbase import pdfmetrics  # noqa: E402
from reportlab.pdfbase.ttfonts import TTFont  # noqa: E402
from reportlab.pdfgen import canvas  # noqa: E402
from reportlab.platypus import Paragraph  # noqa: E402

BASE = ROOT / "tmp/submission"
OUT = ROOT / "output/pdf"
M = json.loads((BASE / "video-manifest.json").read_text(encoding="utf-8"))
INK = colors.HexColor("#143D46")
TEAL = colors.HexColor("#0D6675")
MUTED = colors.HexColor("#52656B")
PALE = colors.HexColor("#EDF5F5")
LINE = colors.HexColor("#D8E3E5")
RED = colors.HexColor("#AD382F")
FUTURE = (
    "향후에는 외부 데이터 표시가 허용되는 사업자 플랜으"
    "로 전환하고 필요한 데이터 이용 권한을 확보하여, "
    "실제 종목 분석을 포함한 공개 서비스로 확장하는 방"
    "안을 검토하고 있습니다. "
    "이러한 확장 가능성을 향후 서비스 운영 계획에 반영"
    "하고자 합니다."
)
OPERATING_NOTE = (
    "사업자 플랜 전환 시에도 거래소 조건·지역별 승인·"
    "외부 표시 권한을 확인합니다. "
    "데이터 재배포는 별도 계약 대상일 수 있습니다. "
    "가상 체험은 이후에도 교육과 오프라인 설명에 활용할 수 있습니다."
)
NOTICE = (
    "본 자료와 동봉된 비공개 시연 영상은 공모전 내부 "
    "심사 목적으로 제출합니다. "
    "데이터 제공자의 이용 허용 범위를 준수하기 위해 홈"
    "페이지 게시, 공개 다운로드 "
    "및 대외 홍보 자료에서는 제외해 주시기 바랍니다."
)
NOTICE2 = (
    "수상작 홍보 등 공개가 필요한 경우에는 함께 제출한"
    " 「리스크렌즈_공개용.pdf」"
    "와 공개용 시연 영상을 사용해 주십시오. "
    "공개용 자료는 실제 시세에서 유래하지 않은 가상 예"
    "시로 구성했습니다."
)


def mmss(sec: float) -> str:
    return f"{int(sec) // 60:02d}:{int(sec) % 60:02d}"


class Doc:
    def __init__(self, filename: str, kind: str, total: int):
        self.path = OUT / filename
        self.c = canvas.Canvas(str(self.path), pagesize=A4, pageCompression=1)
        self.c.setTitle("리스크 렌즈 | " + kind)
        self.c.setAuthor("리스크 렌즈 · 이도윤 · 장효재 · 이혁")
        self.c.setSubject("공모전 참고자료 · 2026-11-02 · Android 1.2.0")
        self.kind, self.total, self.n = kind, total, 0
        self.w, self.h = A4

    def text(
        self,
        x: float,
        top: float,
        text: str,
        width: float = 511,
        size: float = 11,
        bold: bool = False,
        color=INK,
    ) -> float:
        style = ParagraphStyle(
            "body",
            fontName="KRB" if bold else "KR",
            fontSize=size,
            leading=size * 1.52,
            textColor=color,
            wordWrap="CJK",
            splitLongWords=True,
        )
        para = Paragraph(text, style)
        _, height = para.wrap(width, 900)
        if top - height < 42:
            raise ValueError(f"Text exceeds page {self.n}: {text[:45]}")
        para.drawOn(self.c, x, top - height)
        return top - height

    def page(self, label: str, title: str, subtitle: str = "", wide: bool = False):
        if self.n:
            self.footer()
            self.c.showPage()
        self.n += 1
        self.w, self.h = landscape(A4) if wide else A4
        self.c.setPageSize((self.w, self.h))
        self.c.setFillColor(colors.white)
        self.c.rect(0, 0, self.w, self.h, stroke=0, fill=1)
        self.text(
            42, self.h - 30, f"RISK LENS   /   {label}", self.w - 84, 9, True, TEAL
        )
        self.text(42, self.h - 69, title, self.w - 84, 24, True)
        if subtitle:
            self.text(42, self.h - 111, subtitle, self.w - 84, 10, color=MUTED)
        self.c.setStrokeColor(LINE)
        self.c.line(42, self.h - 150, self.w - 42, self.h - 150)

    def footer(self):
        c = self.c
        c.setStrokeColor(LINE)
        c.line(42, 41, self.w - 42, 41)
        c.setFillColor(MUTED)
        c.setFont("KR", 8)
        c.drawString(42, 26, self.kind)
        c.drawRightString(
            self.w - 42, 26, f"2026.11.02  ·  {self.n:02d} / {self.total:02d}"
        )

    def box(self, x, top, width, height, title, body, fill=PALE, size=10.5):
        c = self.c
        c.setFillColor(fill)
        c.roundRect(x, top - height, width, height, 10, fill=1, stroke=0)
        y = self.text(x + 15, top - 14, title, width - 30, 13, True)
        while True:
            check = Paragraph(
                body,
                ParagraphStyle(
                    "fit",
                    fontName="KR",
                    fontSize=size,
                    leading=size * 1.52,
                    wordWrap="CJK",
                ),
            )
            _, measured = check.wrap(width - 30, 900)
            if y - 8 - measured >= top - height + 9:
                break
            size -= 0.2
            if size < 9.3:
                raise ValueError(f"Box overflow: {title}")
        self.text(x + 15, y - 8, body, width - 30, size, color=MUTED)

    def shot(self, kind, index, x, top, width=216, caption=True):
        chapter = M[kind]["chapters"][index - 1]
        path = ROOT / chapter["frame"]
        height = width * 1920 / 1080
        self.c.drawImage(
            ImageReader(str(path)), x, top - height, width, height, mask="auto"
        )
        if caption:
            self.text(
                x,
                top - height - 7,
                f"동봉 영상 {mmss(chapter['frame_at'])} 캡처",
                width,
                8.3,
                color=MUTED,
            )
        return top - height

    def table(self, x, top, widths, rows, size=10):
        y = top
        for i, row in enumerate(rows):
            style = ParagraphStyle(
                "cell",
                fontName="KRB" if i == 0 else "KR",
                fontSize=size,
                leading=size * 1.5,
                wordWrap="CJK",
                textColor=colors.white if i == 0 else INK,
            )
            items = [Paragraph(str(v), style) for v in row]
            height = (
                max(p.wrap(w - 20, 900)[1] for p, w in zip(items, widths, strict=True))
                + 20
            )
            self.c.setFillColor(INK if i == 0 else PALE if i % 2 else colors.white)
            self.c.rect(x, y - height, sum(widths), height, fill=1, stroke=0)
            xx = x
            for p, w in zip(items, widths, strict=True):
                _, h = p.wrap(w - 20, 900)
                p.drawOn(self.c, xx + 10, y - 10 - h)
                xx += w
            y -= height
        if y < 48:
            raise ValueError("Table overflow")
        return y

    def link(self, x, y, text, url, width=511):
        return self.text(
            x,
            y,
            f'<link href="{escape(url, quote=True)}" color="#0D6675">'
            f"<u>{escape(text)}</u></link>",
            width,
            9,
        )

    def save(self):
        self.footer()
        assert self.n == self.total
        self.c.save()
        print(self.path.relative_to(ROOT))


def video_page(d: Doc, kind: str):
    public = kind == "public"
    item = M[kind]
    d.page(
        "VIDEO GUIDE",
        "동봉 시연 영상으로 확인하세요",
        "PDF 화면은 아래 최종 영상에서 직접 추출했습니다.",
    )
    filename = Path(item["file"]).name
    d.box(
        42,
        667,
        511,
        130,
        "재생 안내",
        f"{escape(filename)}<br/>길이 {mmss(item['duration'])}"
        " · MP4 / H.264 · 1080 × 1920"
        " · 무음<br/>"
        "실기기 조작 장면을 발췌·편집했습니다. "
        "PDF와 같은 폴더에서 MP4를 여세요.<br/>"
        "PDF에도 영상 파일을 첨부했습니다. 첨부 미지원 뷰어는 동봉 MP4를 사용하세요.",
        size=10,
    )
    d.link(57, 523, "동봉 MP4 열기 (PDF 뷰어에서 허용하는 경우)", filename)
    rows = [["시작", "영상 장면"]] + [
        [mmss(ch["start"]), ch["title"]] for ch in item["chapters"]
    ]
    end = d.table(42, 489, [70, 441], rows, 10)
    if public:
        d.box(
            42,
            end - 20,
            511,
            93,
            "공개용 자료 안내",
            "종목·시세·환율·날짜·위험 지표는 실제 시세에서 유"
            "래하지 않은 가상 예시입니다."
            " 앱의 AI나 실제 주가 API를 사용하지 않는 오"
            "프라인 체험을 촬영했습니다.",
            size=10,
        )
    else:
        end = d.text(42, end - 18, NOTICE, 511, 9.8)
        d.text(42, end - 10, NOTICE2, 511, 9.8)


def public_pdf():
    d = Doc("리스크렌즈_공개용.pdf", "공개용 · 실제 시세와 독립된 가상 예시", 7)
    d.page(
        "PUBLIC / 01",
        "리스크 렌즈",
        "차입투자와 생활 충격을 확인하는 금융위험 예방 서비스",
    )
    d.text(42, 660, "손실률을,<br/>생활의 금액으로<br/>이해하도록.", 280, 30, True)
    d.text(
        42,
        497,
        "투자 전 재무 조건과 손실 가정을 바꿔 보며, 차입"
        "금이 남는 구조와 생활 현금의 변화를 확인합니다.",
        268,
        12,
    )
    d.shot("public", 1, 346, 665, 190)
    d.box(
        42,
        365,
        274,
        104,
        "이 자료의 모든 사례는 가상입니다",
        "실제 주가·환율·개인정보를 사용하지 않았습니다. 서"
        "비스 기능을 설명하기 위한 독립된 고정 예시입니다.",
        size=10.4,
    )
    d.table(
        42,
        231,
        [168, 171, 172],
        [
            ["01 재무 조건", "02 위험 가정", "03 생활 충격"],
            [
                "소득·지출·비상자금<br/>자기자본·차입금",
                "가상 가격 하락<br/>소득·지출·금리 변화",
                "손실과 남는 차입금<br/>월별 현금흐름 비교",
            ],
        ],
    )
    d.text(
        42, 116, "팀 리스크 렌즈   |   조장 이도윤 · 팀원 장효재 · 이혁", 511, 11, True
    )
    d.text(
        42,
        86,
        "투자 추천·매수/매도 판단·투자 가능 여부 판정·미"
        "래 가격 예측을 제공하지 않습니다.",
        511,
        9.5,
        color=MUTED,
    )

    d.page(
        "PUBLIC / 02",
        "같은 하락률도 부담은 다릅니다",
        "차입 원금은 가격 하락과 함께 줄어들지 않습니다. 아래는 완전 가상 사례입니다.",
    )
    d.shot("public", 5, 42, 670, 220)
    d.box(
        287,
        670,
        266,
        111,
        "투자금 1,000만 원",
        "자기자본 600만 원 + 차입금 400만 원<br/>주가 하락률 30%를 적용한 예시",
        size=11,
    )
    d.box(
        287,
        543,
        266,
        114,
        "투자금 손실 300만 원",
        "하락 후 투자 가치 700만 원<br/>차입 원금 "
        "400만 원은 유지<br/>남은 순투자지분 300만"
        " 원",
        size=11,
    )
    d.box(
        287,
        413,
        266,
        113,
        "자기자본 충격 50%",
        "300만 원 ÷ 자기자본 600만 원<br/>월 생활비 150만 원의 2개월분과 같은 금액",
        size=11,
    )
    d.text(42, 239, "왜 이 화면이 필요한가", 511, 15, True)
    d.text(
        42,
        207,
        "종목 손실률과 자신의 자금 구조를 함께 보여 주어,"
        " 손실의 크기를 자기자본·생활"
        "비와 연결해 이해하도록 돕습니다. 이 비교는 버틸 "
        "수 있는 기간이나 투자 적합성"
        "을 판정한 값이 아닙니다.",
        511,
        11,
    )
    d.text(
        42,
        135,
        "계산 원칙  |  손실 = 투자금 × 하락률 / 순"
        "투자지분 = 충격 후 투자 가치 - 차입 원금",
        511,
        9.5,
        color=MUTED,
    )

    d.page(
        "PUBLIC / 03",
        "생활 충격이 겹치면 현금은 어떻게 될까",
        "3·6·12개월 동안 같은 조건이 유지된다는 가정에서 비교합니다.",
    )
    d.shot("public", 3, 42, 670, 215)
    d.box(
        280,
        670,
        273,
        135,
        "가상 입력 조건",
        "시작 현금 500만 원 · 월 소득 300만 원<b"
        "r/>생활비 150만 원 · "
        "기존 월 상환 40만 원<br/>투자용 차입 400"
        "만 원 · 연 6%<br/>만"
        "기일시상환, 시뮬레이션 내 원금 만기 없음",
        size=10.5,
    )
    d.box(
        280,
        519,
        273,
        108,
        "생활 충격 가정",
        "소득 -20% · 생활비 +10% · 금리 +2%p"
        "<br/>월 순현금: 108만"
        " 원 → 323,333원<br/>월 투자 이자: 2"
        "0,000원 → 26,667원",
        size=10.5,
    )
    d.box(
        280,
        395,
        273,
        104,
        "평가손실과 현금은 구분",
        "주가·환율로 생기는 평가손실을 생활 현금에서 자동 "
        "차감하지 않습니다. 현금이 부"
        "족해져도 추가 대출을 자동 가정하지 않습니다.",
        size=10,
    )
    d.table(
        42,
        270,
        [105, 196, 210],
        [
            ["말일 현금", "현재 조건", "생활 충격 조건"],
            ["3개월", "8,240,000원", "5,969,999원"],
            ["6개월", "11,480,000원", "6,939,998원"],
            ["12개월", "17,960,000원", "8,879,996원"],
        ],
        10,
    )
    d.text(
        42,
        81,
        "월 이자는 원 단위 반올림 후 합산합니다. 기간이 "
        "길어져 월 이자 자체가 늘어나는 가정은 아닙니다.",
        511,
        9,
        color=MUTED,
    )

    d.page(
        "PUBLIC / 04",
        "과거 위험의 의미를 그래프로 설명합니다",
        "아래 종목·곡선·기준일·지표는 모두 가상이며 실제 시세를 변형한 값이 아닙니다.",
    )
    d.shot("public", 4, 42, 670, 228)
    d.box(
        292,
        670,
        261,
        116,
        "고점 → 저점 → 회복",
        "MDD는 관측 구간의 누적 최고점 대비 최대 하락률"
        "입니다. 회복일이 없으면 관측"
        " 종료일까지 회복하지 못한 것으로 구분합니다.",
        size=10.6,
    )
    d.box(
        292,
        538,
        261,
        115,
        "원화와 달러 기준을 함께",
        "원화 가치는 주가와 환율의 영향을 함께 받습니다. "
        "실제 분석은 분할 조정 USD"
        " 종가와 ECB 참고 환율을 결합합니다. 배당·환전"
        " 비용은 제외합니다.",
        size=10.6,
    )
    d.box(
        292,
        407,
        261,
        113,
        "해석의 한계를 함께 표시",
        "최근 3개월의 관측 위험은 전체 과거의 최악이나 미"
        "래 손실 확률을 뜻하지 않습니"
        "다. 원화 MDD에 환율 충격을 다시 중복 적용하지 않습니다.",
        size=10.5,
    )
    d.text(42, 228, "실제 데이터 기능은 별도 이용 범위에 맞춰 운영", 511, 14, True)
    d.text(
        42,
        195,
        "현재 공개 운영 API는 실제 종목 데이터 제공을 "
        "중지했습니다. 공개 체험은 네"
        "트워크·실제 시세·AI를 사용하지 않는 가상 사례로"
        " 기능을 설명합니다. 미국 주"
        "식·ETF 실제 분석은 비공개 심사 시연 환경에서 확인합니다.",
        511,
        11,
    )
    d.text(
        42,
        110,
        "가상 그래프는 라이선스 준수와 네트워크 없는 설명·체험을 함께 지원합니다.",
        511,
        10,
        color=MUTED,
    )

    d.page(
        "PUBLIC / 05",
        "알고 있는 위험을, 이해한 위험으로",
        "짧은 위험 이해 체험: 1회 5문제 · 정답/오답과 계산 근거 표시",
    )
    d.shot("public", 6, 54, 670, 220)
    d.shot("public", 7, 321, 670, 220)
    d.text(54, 246, "오답도 이유를 확인", 220, 13, True)
    d.text(321, 246, "정답도 계산으로 확인", 220, 13, True)
    d.text(
        54,
        215,
        "누적 이자, 하락과 회복, 환율 등 8개 주제에서 "
        "5문제를 구성합니다. 공개 영"
        "상은 독립 가상 문제 중 두 문제의 피드백을 보여 줍니다.",
        487,
        11,
    )
    d.text(
        54,
        137,
        "인터넷 없이도 준비된 가상 문제로 체험할 수 있습니다. "
        "서버에 연결하면 AI를 활용해 새로운 5문제 묶음을 "
        "구성할 수 있습니다. AI는 주제 선택과 안내 문구를 돕고, "
        "숫자·선택지·정답은 서버 코드가 결정합니다.",
        487,
        10.4,
        color=MUTED,
    )

    d.page(
        "PUBLIC / 06",
        "구현 범위와 확장 계획",
        "Android 앱 · 결정론적 금융 계산 · 공개 범위를 구분한 운영",
    )
    d.table(
        42,
        670,
        [128, 383],
        [
            ["현재 구현", "확인할 수 있는 행동"],
            ["개인 금융체력", "월 잉여현금·비상자금·투자용 차입 비율 확인"],
            ["고정 Stress Test", "직접 정한 주가·환율 충격과 회복 필요 상승률 비교"],
            ["현금흐름·생활 충격", "3·6·12개월 잔액과 소득·지출·금리 충격 비교"],
            ["가정 A/B 비교", "서로 다른 두 조건을 현재 앱 실행 중에만 비교"],
            ["위험 이해 체험", "5문제, 정답·오답 피드백과 계산 근거 확인"],
        ],
        10,
    )
    d.box(
        42,
        397,
        511,
        99,
        "설계와 개인정보",
        "Flutter Android → Naver Clou"
        "d의 Nginx / FastA"
        "PI. 로그인·서버 분석 이력 저장은 없습니다. 외"
        "부 키는 서버에만 두고, AI"
        "에는 검증된 최소 계산 결과만 전달합니다.",
        size=10.6,
    )
    d.text(42, 275, "현재 한계와 다음 단계", 511, 14, True)
    end = d.text(
        42,
        243,
        "Basic 이용 중 실제 종목 분석의 공개 제공은 "
        "제한됩니다. 국내 종목 실데이"
        "터는 지원하지 않으며, 한글 검색은 일부 별칭만 지"
        "원합니다. 사용자 이해도·예방"
        " 효과는 아직 정량 측정하지 않았습니다.",
        511,
        10.7,
    )
    end = d.text(42, end - 13, FUTURE, 511, 10.7)
    d.text(
        42,
        end - 11,
        OPERATING_NOTE,
        511,
        9.3,
        color=MUTED,
    )
    d.link(
        42,
        84,
        "데이터 이용 정책: Twelve Data 공식 안내 (2026-11-02 확인)",
        "https://support.twelvedata.c"
        "om/en/articles/5"
        "332349-commercial-and-person"
        "al-usage",
    )
    video_page(d, "public")
    d.save()


def private_pdf():
    d = Doc(
        "리스크렌즈_심사용_외부공개제외.pdf",
        "심사 내부용 · 홈페이지 게시·공개 다운로드 제외 요청",
        6,
    )
    d.page(
        "JUDGES ONLY / 01",
        "실제 종목 분석 구현 확인",
        "심사 보충 자료 · 동봉 비공개 시연 영상 · 외부 공개 제외 요청",
    )
    d.box(
        42,
        670,
        511,
        129,
        "공모전 내부 심사 목적으로 제출합니다",
        NOTICE + "<br/><br/>" + NOTICE2,
        size=10.2,
    )
    d.table(
        42,
        518,
        [140, 371],
        [
            ["시연 조건", "실제 촬영 범위"],
            ["앱·기기", "Android 1.2.0 · Samsung SM S906N 실기기"],
            ["개인 재무정보", "앱에 미리 채운 가상 재무 입력값을 사용"],
            ["종목 데이터", "실제 Twelve Data AAPL 분석 + ECB 참고 환율"],
            ["접속 환경", "PC 로컬 API와 USB 연결 · 공개 운영 API 차단 유지"],
            ["설명 방식", "이 촬영은 AI 미설정 상태의 검증된 기본 설명 사용"],
            ["영상에서 제외", "원시 API 응답·인증정보·다운로드 가능한 시세 데이터"],
        ],
        10,
    )
    d.text(42, 194, "자료를 나눈 이유", 511, 14, True)
    d.text(
        42,
        161,
        "제공자 답변에 따르면 비공개 심사 시연과 공개 다운"
        "로드 자료의 이용 범위가 다릅"
        "니다. 공개가 필요한 경우에는 가상 사례로 구성한 "
        "공개용 PDF와 공개용 영상을"
        " 사용해 주십시오. 메일 캡처와 원문 발췌는 별도 "
        "내부용 안내서에 첨부했습니다.",
        511,
        10.5,
    )

    d.page(
        "JUDGES ONLY / 02",
        "출처·관측 기간·기준일을 함께 확인",
        "실제 분석값은 이 비공개 자료 안에서만 제시합니다.",
    )
    d.shot("private", 2, 42, 670, 226)
    d.shot("private", 3, 313, 670, 226)
    d.text(42, 231, "화면에서 확인하는 항목", 511, 14, True)
    d.text(
        42,
        198,
        "선택한 종목, 통화, 관측 기간과 일수, 데이터 출"
        "처, 기간 수익률·연환산 변동"
        "성·MDD를 표시합니다. 고점·저점·회복일은 조회한"
        " 구간 안에서만 해석합니다.",
        511,
        11,
    )
    d.text(
        42,
        126,
        "수익률·MDD·변동성은 원화 가격 기준입니다. 단기"
        "간의 관측값은 미래 성과, 전"
        "체 과거의 최악 또는 실제 거래 수익률을 보장하지 않습니다.",
        511,
        10.4,
        color=MUTED,
    )

    d.page(
        "JUDGES ONLY / 03",
        "일별 가격 흐름과 환율 영향을 비교",
        "실제 종가 기반 차트 · 시작값 100 · 비공개 심사 시연",
    )
    d.shot("private", 4, 42, 670, 230)
    d.box(
        294,
        670,
        259,
        114,
        "첫 관측값을 100으로",
        "실제 일별 USD 종가와 원화 환산 가격을 "
        "각각 시작값 100으로 맞춰 그립니다. "
        "달러와 원화의 단위 차이를 제거해 "
        "같은 기간의 변화율을 비교합니다.",
        size=10.5,
    )
    d.box(
        294,
        540,
        259,
        113,
        "고점·저점·회복 구간",
        "음영은 원화 MDD의 고점에서 저점까지입니다. "
        "그래프를 누르면 해당 관측일의 비교값을 "
        "확인합니다. 거래가 없는 날짜의 새 가격을 "
        "만들어 넣지 않습니다.",
        size=10.5,
    )
    d.box(
        294,
        411,
        259,
        113,
        "출처와 해석의 한계",
        "분할 조정·배당 제외 종가와 ECB 참고 환율입니다. "
        "실제 환전 가격·수수료·배당 총수익률은 "
        "포함하지 않습니다. 과거 흐름을 미래 "
        "가격 예측으로 해석하지 않습니다.",
        size=10.5,
    )
    d.text(42, 224, "실제 종목 기능을 확인하는 비공개 자료", 511, 14, True)
    d.text(
        42,
        192,
        "이 차트와 영상은 공모전 내부 심사 목적으로만 "
        "제출합니다. 홈페이지 게시·공개 다운로드·홍보에는 "
        "실제 시세와 독립된 공개용 가상 자료를 사용해 주십시오.",
        511,
        11,
    )
    d.link(42, 115, "Data provided by Twelve Data", "https://twelvedata.com/")
    d.link(
        42,
        91,
        "FX reference: European Central Bank",
        "https://www.ecb.europa.eu/stats/policy_and_exchange_rates/"
        "euro_reference_exchange_rates/html/index.en.html",
    )
    d.page(
        "JUDGES ONLY / 04",
        "과거 위험을 생활의 금액에 연결",
        "과거 관측 MDD를 가상 투자금에 적용한 손실 가정"
        "입니다. 미래 손실 예측이 아닙니다.",
    )
    d.shot("private", 6, 42, 670, 228)
    d.box(
        294,
        670,
        259,
        125,
        "같은 투자금, 남는 차입금",
        "충격 전후 투자 가치와 유지되는 차입 원금을 같은 "
        "눈금으로 표시합니다. 평가손실"
        "과 차입 채무를 분리하여 남은 순투자지분을 보여 줍니다.",
        size=10.7,
    )
    d.box(
        294,
        529,
        259,
        121,
        "검증된 기본 설명",
        "이번 촬영에서는 로컬 AI 설정을 사용하지 않았습니"
        "다. 화면의 기본 설명은 계산"
        " 결과를 템플릿으로 설명한 것이며 실제 LLM 응답"
        "으로 표시하지 않습니다.",
        size=10.6,
    )
    d.box(
        294,
        392,
        259,
        125,
        "공개 기능과의 연결",
        "같은 재무 입력에서 월별 현금흐름과 생활 충격 비교"
        "로 이어집니다. 이 기능의 공"
        "개용 영상은 실제 시세와 독립된 가상 사례를 사용합니다.",
        size=10.7,
    )
    d.text(42, 217, "투자자산 평가손실은 생활비 지출과 다릅니다", 511, 14, True)
    d.text(
        42,
        184,
        "가격 하락으로 발생한 평가손실을 월 생활 현금에서 "
        "자동 공제하지 않습니다. 현금"
        "흐름은 소득·생활비·기존 대출 상환·투자용 대출 이"
        "자와 원금 상환 가정으로 별도"
        " 계산합니다.",
        511,
        11,
    )

    d.page(
        "JUDGES ONLY / 05",
        "계산 기준과 검증의 범위",
        "구현 사실, 데이터의 한계, 향후 공개 서비스 계획을 구분합니다.",
    )
    d.shot("private", 5, 42, 670, 205)
    d.box(
        269,
        670,
        284,
        142,
        "실제 과거 위험 계산",
        "Twelve Data의 분할 조정 일별 USD 종가"
        "에 ECB 참고 원/달러 환율"
        "을 결합합니다. 배당·거래 비용·실제 환전 비용은 "
        "제외합니다. 환율 기준일과 제"
        "공 범위를 표시합니다.",
        size=10.6,
    )
    d.box(
        269,
        512,
        284,
        130,
        "이미 실시한 검증",
        "분할 조정 종가와 독립 공시의 대조, 원화 수익률·"
        "MDD·변동성의 별도 산술 검"
        "산, 미국·ECB 휴일 경계와 이전 환율 기준일을 "
        "확인했습니다. 이번 영상은 A"
        "APL의 실기기 연결을 보여 줍니다.",
        size=10.3,
    )
    d.box(
        269,
        366,
        284,
        98,
        "검증에서 구분한 사항",
        "검색 결과가 나온 것과 모든 종목의 분석 성공은 다"
        "릅니다. 사용자 조사나 실제 "
        "금융 피해 감소 효과는 검증하지 않았습니다.",
        size=10.3,
    )
    d.text(42, 230, "향후 운영 계획", 511, 14, True)
    end = d.text(42, 198, FUTURE, 511, 10.5)
    d.text(
        42,
        end - 12,
        OPERATING_NOTE,
        511,
        9.3,
        color=MUTED,
    )
    video_page(d, "private")
    d.save()


def guide_pdf():
    d = Doc(
        "리스크렌즈_자료안내_심사내부용.pdf",
        "심사 내부용 · 메일 증빙 포함 · 외부 공개 제외 요청",
        6,
    )
    d.page(
        "MATERIALS GUIDE / 01",
        "공개 자료와 심사 자료를 나눈 이유",
        "데이터 제공자의 실제 답변과 제출 자료의 처리 요청을 정리했습니다.",
    )
    d.table(
        42,
        670,
        [126, 238, 147],
        [
            ["구분", "들어 있는 내용", "요청하는 사용 범위"],
            [
                "공개용 PDF·영상",
                "실제 시세에서 유래하지 않은 가상 수치·그래프·문제",
                "홈페이지 게시·공개 다운로드·홍보에 사용",
            ],
            [
                "심사용 PDF·영상",
                "실제 종목의 계산 결과·가격 차트·기준일",
                "공모전 내부 심사에만 사용",
            ],
            [
                "이 안내서",
                "문의 요지·답변 발췌·원본 메일 캡처",
                "이용 범위 확인을 위한 내부 검토",
            ],
        ],
        10,
    )
    d.box(
        42,
        416,
        511,
        112,
        "제공자가 답한 구분",
        "Basic 및 개인 플랜의 비공개 심사 영상은 일반"
        "적으로 내부/비공개 이용으로 "
        "보지만, 실제 데이터에서 계산된 결과를 담은 공개 "
        "다운로드 PDF는 외부 표시로"
        " 본다고 답했습니다. 출처 표시만으로 외부 표시 권"
        "한을 대신할 수 없습니다.",
        size=10.5,
    )
    d.text(42, 280, "문의 원문과 이번 시연의 관계", 511, 14, True)
    d.text(
        42,
        248,
        "문의 당시에는 가격 차트 미표시 계획을 설명했습니다. "
        "회신은 비공개 심사 영상과 공개 PDF를 구분했습니다. "
        "이번 보충 시연에는 비공개 기능 설명을 위해 "
        "실제 일별 종가 기반 차트를 포함했습니다. "
        "회신이 차트 항목까지 별도로 승인한 답변이라고 "
        "표현하지 않습니다.",
        511,
        10.8,
    )
    d.box(
        42,
        153,
        511,
        88,
        "주최 측에 대한 처리 요청",
        "비공개 표시는 주최 측에 전달하는 요청입니다. 이 "
        "표시만으로 공모전의 공표 조건"
        "이 변경되거나 비공개 처리가 확정되었다고 표현하지 않았습니다.",
        size=10.2,
    )

    d.page(
        "EMAIL EVIDENCE / 02",
        "보낸 문의 메일: 질문과 사용 범위",
        "사용자가 제공한 실제 캡처 기준 · 표시 시각 10월 11일 오전 3:53",
    )
    d.text(
        42, 670, "수신 대상 api / support · Risk Lens team 명의의 문의", 511, 12, True
    )
    d.text(
        42,
        636,
        "아래는 캡처에서 확인한 핵심 문장의 발췌입니다. 전"
        "체 캡처는 4~5쪽에 원본 해"
        "상도로 수록했습니다. 캡처에 표시되지 않은 전송 헤"
        "더나 메일 ID는 만들지 않았"
        "습니다.",
        511,
        10.5,
    )
    quotes = [
        (
            "Data displayed in the app",
            "The app would display the st"
            "ock name and sym"
            "bol, observation period, dat"
            "a source, and ca"
            "lculated results. It would n"
            "ot display raw d"
            "aily prices, price charts, o"
            "r API responses.",
        ),
        (
            "Private demonstration",
            "A recorded demonstration vid"
            "eo would be show"
            "n to the competition organiz"
            "ers and judges f"
            "or evaluation. We do not pla"
            "n to upload the "
            "video publicly or distribute"
            " the app to the "
            "judges or the public.",
        ),
        (
            "Public PDF if awarded",
            "Based on the organizer’s cur"
            "rent practice, t"
            "he presentation PDF of an aw"
            "ard-winning team"
            " may be posted on the compet"
            "ition website fo"
            "r anyone to view or download.",
        ),
        (
            "Fictional alternative",
            "If the screenshots cannot in"
            "clude results ca"
            "lculated from actual market "
            "data, would scre"
            "enshots using clearly labele"
            "d fictional valu"
            "es that are not derived from"
            " Twelve Data be "
            "acceptable?",
        ),
    ]
    y = 551
    for title, text in quotes:
        d.text(42, y, title, 511, 11.5, True)
        y = d.text(42, y - 28, escape(text), 511, 10.5) - 23
    d.text(
        42,
        104,
        "문의는 데이터 이용 조건을 확인하기 위한 것이며 공"
        "동개발·공식 후원·제휴 체결을 의미하지 않습니다.",
        511,
        9.8,
        color=MUTED,
    )

    d.page(
        "EMAIL EVIDENCE / 03",
        "받은 답변: 판단 기준과 원문 발췌",
        "Dooz from Twelve Data · 캡처 표시 2026.10.11 오전 3:54",
    )
    quotes = [
        (
            "Private demonstration video for judges",
            "This is typically considered"
            " internal or pri"
            "vate use, which is allowed u"
            "nder individual "
            "plans.",
            "비공개 심사 영상은 일반적으로 개인 플랜의 내부/비"
            "공개 이용에 해당한다고 설명합니다.",
        ),
        (
            "Public PDF with calculated results",
            "If the PDF is publicly downl"
            "oadable, it woul"
            "d be considered external dis"
            "play of data. In"
            "dividual plans do not allow "
            "external display"
            " of market data to third parties.",
            "실데이터 기반 계산 결과의 공개 PDF는 외부 표시로 구분합니다.",
        ),
        (
            "Fictional values",
            "If the screenshots contain c"
            "learly labeled f"
            "ictional values that are not"
            " derived from Tw"
            "elve Data, they would not be"
            " considered Twel"
            "ve Data data.",
            "Twelve Data에서 유래하지 않은 명확한 가상"
            " 예시는 해당 데이터로 보지 않는다고 설명합니다.",
        ),
    ]
    y = 670
    for title, text, summary in quotes:
        d.text(42, y, title, 511, 12, True)
        y = d.text(42, y - 29, escape(text), 511, 11) - 8
        y = d.text(42, y, summary, 511, 10.5, color=MUTED) - 28
    d.box(
        42,
        211,
        511,
        107,
        "출처 표시와 이용 권한은 별개입니다",
        "답변은 공개 시 출처 표시가 필요하다고 하면서도, "
        "공개 표시 권한은 개인 플랜에"
        " 포함되지 않는다고 명시합니다. 따라서 현재 제출물"
        "은 공개 자료를 완전 가상 사"
        "례로 구성하는 방법을 택했습니다.",
        size=10.4,
    )

    mail_root = Path.home() / "Desktop/공모전 용"
    for index, filename, label in [
        (4, "twelve API 문의 메일.png", "보낸 문의 메일 캡처 원본"),
        (5, "twelve API 답장 메일.png", "받은 답변 메일 캡처 원본"),
    ]:
        d.page(
            f"EMAIL EVIDENCE / {index:02d}",
            label,
            "사용자가 제공한 이미지 전체를 수록했습니다. 확대하여 확인할 수 있습니다.",
            wide=True,
        )
        path = mail_root / filename
        reader = ImageReader(str(path))
        w, h = reader.getSize()
        width = 758
        height = width * h / w
        d.c.drawImage(reader, 42, 421 - height, width, height, preserveAspectRatio=True)
        d.text(
            42,
            88,
            "원본 파일의 본문을 수정하지 않았습니다. 읽기 편한"
            " 핵심 발췌는 2~3쪽을 함께 참고해 주십시오.",
            758,
            9.5,
            color=MUTED,
        )
        d.text(
            42,
            65,
            "ZIP의 심사 내부용 폴더에도 원본 PNG 두 장을 동봉했습니다.",
            758,
            9.5,
            color=MUTED,
        )

    d.page(
        "HANDLING REQUEST / 06",
        "제출 파일의 사용 안내와 향후 계획",
        "공개·심사 자료의 폴더와 파일명을 구분했습니다.",
    )
    d.box(
        42,
        670,
        511,
        155,
        "심사 자료·비공개 시연 영상 처리 요청",
        NOTICE + "<br/><br/>" + NOTICE2,
        size=10.8,
    )
    d.text(42, 490, "향후 공개 서비스 운영 계획", 511, 14, True)
    end = d.text(42, 458, FUTURE, 511, 11)
    d.text(
        42,
        end - 12,
        "개인 Pro는 개인 플랜입니다. 외부 표시가 허용되"
        "는 사업자 플랜에서도 거래소별"
        " 조건·데이터 지역·추가 승인·재배포 계약을 확인합"
        "니다. 플랜 결제만으로 모든 "
        "데이터의 외부 공개가 자동 허용된다고 전제하지 않았습니다.",
        511,
        10.5,
    )
    d.text(42, 293, "참고한 공식 정책", 511, 12, True)
    d.link(
        42,
        265,
        "Twelve Data: Commercial and personal usage",
        "https://support.twelvedata.c"
        "om/en/articles/5"
        "332349-commercial-and-person"
        "al-usage",
    )
    d.link(42, 237, "Twelve Data: Terms of Use", "https://twelvedata.com/terms")
    d.text(
        42,
        201,
        "정책 확인일 2026-11-02. 이 안내는 실제 "
        "답변과 공개 정책을 바탕으로 "
        "제출 범위를 정리한 자료입니다. 제공자 또는 주최 "
        "측의 별도 계약·확약으로 작성"
        "하지 않았습니다.",
        511,
        9.5,
        color=MUTED,
    )
    d.text(42, 126, "권장 열람 순서", 511, 12, True)
    d.text(
        42,
        98,
        "공식 상세기획서 → 공개용 PDF·영상 → 심사용 PDF·영상 → 이 안내서의 메일 증빙",
        511,
        10,
    )
    d.save()


def main(*, only: str | None = None):
    OUT.mkdir(parents=True, exist_ok=True)
    pdfmetrics.registerFont(TTFont("KR", "C:/Windows/Fonts/malgun.ttf"))
    pdfmetrics.registerFont(TTFont("KRB", "C:/Windows/Fonts/malgunbd.ttf"))
    pdfmetrics.registerFontFamily(
        "KR", normal="KR", bold="KRB", italic="KR", boldItalic="KRB"
    )
    if only in (None, "public"):
        public_pdf()
    if only in (None, "private"):
        private_pdf()
    if only is None:
        guide_pdf()
    for filename, kind in [
        ("리스크렌즈_공개용.pdf", "public"),
        ("리스크렌즈_심사용_외부공개제외.pdf", "private"),
    ]:
        if only is not None and kind != only:
            continue
        import io

        target = OUT / filename
        writer = PdfWriter(clone_from=PdfReader(target))
        video = ROOT / M[kind]["file"]
        attachment = writer.add_attachment(video.name, video.read_bytes())
        attachment.description = TextStringObject("동봉 시연 영상과 동일한 MP4 파일")
        annotation = DictionaryObject(
            {
                NameObject("/Type"): NameObject("/Annot"),
                NameObject("/Subtype"): NameObject("/FileAttachment"),
                NameObject("/Rect"): ArrayObject(
                    [FloatObject(v) for v in (519, 628, 537, 646)]
                ),
                NameObject("/FS"): attachment.pdf_object,
                NameObject("/Name"): NameObject("/Paperclip"),
                NameObject("/Contents"): TextStringObject(
                    "동봉 시연 영상: " + video.name
                ),
            }
        )
        writer.add_annotation(len(writer.pages) - 1, annotation)
        buffer = io.BytesIO()
        writer.write(buffer)
        target.write_bytes(buffer.getvalue())


if __name__ == "__main__":
    selected = (
        "public"
        if "--public-only" in sys.argv[1:]
        else "private"
        if "--private-only" in sys.argv[1:]
        else None
    )
    main(only=selected)
