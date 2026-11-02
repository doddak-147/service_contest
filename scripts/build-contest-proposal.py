"""Render the reviewed proposal Markdown with PDF-only authoring dependencies.

Install reportlab/pypdf in tmp/proposal-tools; API/mobile dependencies stay unchanged.
"""

import re
import sys
from html import escape
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tmp/proposal-tools"))

from reportlab.lib import colors  # noqa: E402
from reportlab.lib.pagesizes import A4  # noqa: E402
from reportlab.lib.styles import ParagraphStyle  # noqa: E402
from reportlab.lib.utils import ImageReader  # noqa: E402
from reportlab.pdfbase import pdfmetrics  # noqa: E402
from reportlab.pdfbase.ttfonts import TTFont  # noqa: E402
from reportlab.platypus import (  # noqa: E402
    Flowable,
    Image,
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

SOURCE = ROOT / "docs/contest/리스크렌즈_상세기획서_초안.md"
OUTPUT = ROOT / "output/pdf/리스크렌즈_상세기획서_초안.pdf"
PAGE_WIDTH, PAGE_HEIGHT = A4
WIDTH = PAGE_WIDTH - 104
INK = colors.HexColor("#183A43")
MUTED = colors.HexColor("#52656B")


def initialize_fonts() -> None:
    font_root = Path("C:/Windows/Fonts")
    pdfmetrics.registerFont(TTFont("Korean", str(font_root / "malgun.ttf")))
    pdfmetrics.registerFont(TTFont("KoreanBold", str(font_root / "malgunbd.ttf")))
    pdfmetrics.registerFontFamily(
        "Korean", normal="Korean", bold="KoreanBold", italic="Korean"
    )


def style(size: float = 9.7, **kwargs: object) -> ParagraphStyle:
    options = {
        "fontName": "Korean",
        "fontSize": size,
        "leading": size * 1.52,
        "textColor": colors.black,
        "wordWrap": "CJK",
        "spaceAfter": 7,
        **kwargs,
    }
    return ParagraphStyle("proposal", **options)


def markup(text: str) -> str:
    value = escape(text)
    value = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", value)
    value = re.sub(r"`([^`]+)`", r"\1", value)
    return value


class Architecture(Flowable):
    def __init__(self) -> None:
        super().__init__()
        self.width, self.height = WIDTH, 174

    def draw(self) -> None:
        canvas = self.canv
        canvas.setFillColor(colors.HexColor("#F1F5F5"))
        canvas.setStrokeColor(colors.HexColor("#CBD5D8"))
        canvas.roundRect(3, 132, self.width - 6, 36, 5, fill=1, stroke=1)
        canvas.setFillColor(INK)
        canvas.setFont("KoreanBold", 9)
        canvas.drawString(14, 153, "Android 앱")
        canvas.setFont("Korean", 8.5)
        canvas.drawString(14, 140, "사용 환경에 맞는 계산과 체험")
        box_width = (self.width - 20) / 3
        branches = [
            (
                "운영 HTTPS",
                [
                    "Naver Cloud",
                    "Nginx → FastAPI",
                    "현금흐름 · AI 문제",
                    "실제 시세 차단",
                ],
            ),
            (
                "비공개 USB 시연",
                ["PC 로컬 API", "미국 주식·ETF", "Twelve Data + ECB", "심사 시연 범위"],
            ),
            (
                "완전 가상 체험",
                [
                    "앱 안의 고정 사례",
                    "분석 API 무호출",
                    "독립 가상 그래프",
                    "실제 시세 미사용",
                ],
            ),
        ]
        for index, (title, labels) in enumerate(branches):
            x = index * (box_width + 10)
            canvas.setFillColor(colors.HexColor("#F1F5F5"))
            canvas.roundRect(x, 12, box_width, 87, 5, fill=1, stroke=1)
            canvas.setFillColor(INK)
            canvas.setFont("KoreanBold", 8.8)
            canvas.drawString(x + 10, 81, title)
            canvas.setFont("Korean", 8.5)
            for row, label in enumerate(labels):
                canvas.drawString(x + 10, 64 - row * 12, label)
        canvas.setStrokeColor(MUTED)
        canvas.line(self.width / 2, 132, self.width / 2, 115)
        centers = [i * (box_width + 10) + box_width / 2 for i in range(3)]
        canvas.line(centers[0], 115, centers[-1], 115)
        for x in centers:
            canvas.line(x, 115, x, 101)
            canvas.line(x - 2, 104, x, 101)
            canvas.line(x + 2, 104, x, 101)


def screenshots() -> Table:
    images = []
    folder = ROOT / "output/qa/2026-11-02"
    for name in ("cash-flow-fictional.png", "price-history-fictional.png"):
        path = str(folder / name)
        width, height = ImageReader(path).getSize()
        image = Image(path, width=160, height=160 * height / width, lazy=0)
        images.append(image)
    captions = [
        Paragraph("완전 가상 체험의 생활 충격·현금 잔액", style(8)),
        Paragraph("독립 가상 곡선의 원화·달러 흐름과 MDD", style(8)),
    ]
    table = Table([images, captions], colWidths=[WIDTH / 2] * 2, hAlign="CENTER")
    table.setStyle(
        TableStyle(
            [
                ("ALIGN", (0, 0), (-1, -1), "CENTER"),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("TOPPADDING", (0, 0), (-1, -1), 4),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
            ]
        )
    )
    return table


def data_table(rows: list[list[str]]) -> Table:
    columns = len(rows[0])
    ratios = {2: [0.27, 0.73], 3: [0.24, 0.47, 0.29], 4: [0.13, 0.29, 0.29, 0.29]}
    widths = [WIDTH * ratio for ratio in ratios[columns]]
    cell_style = style(8.7, spaceBefore=0)
    cell_style.spaceAfter = 0
    cells = [[Paragraph(markup(cell), cell_style) for cell in row] for row in rows]
    table = Table(cells, colWidths=widths, repeatRows=1, hAlign="LEFT")
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#E8F0F1")),
                ("GRID", (0, 0), (-1, -1), 0.45, colors.HexColor("#D9D9D9")),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("LEFTPADDING", (0, 0), (-1, -1), 8),
                ("RIGHTPADDING", (0, 0), (-1, -1), 8),
                ("TOPPADDING", (0, 0), (-1, -1), 6),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
            ]
        )
    )
    return table


def footer(canvas: object, doc: object) -> None:
    canvas.saveState()
    canvas.setFont("Korean", 8)
    canvas.setFillColor(MUTED)
    canvas.drawString(52, 32, "리스크 렌즈 상세기획서 · 2026.11.02")
    canvas.drawRightString(PAGE_WIDTH - 52, 32, str(doc.page))
    canvas.restoreState()


def build() -> None:
    initialize_fonts()
    story = []
    lines = SOURCE.read_text(encoding="utf-8").splitlines()
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        if not line:
            i += 1
            continue
        if line == "<!-- pagebreak -->":
            story.append(PageBreak())
        elif line.startswith("# "):
            story.append(Paragraph(markup(line[2:]), style(20, fontName="KoreanBold")))
            story.append(Spacer(1, 7))
        elif line.startswith("## "):
            story.append(
                Paragraph(
                    markup(line[3:]),
                    style(
                        13.5, fontName="KoreanBold", keepWithNext=True, spaceBefore=4
                    ),
                )
            )
        elif line.startswith("### "):
            story.append(
                Paragraph(
                    markup(line[4:]),
                    style(
                        10.7, fontName="KoreanBold", keepWithNext=True, spaceBefore=5
                    ),
                )
            )
        elif line.startswith("| "):
            rows = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                cells = [
                    cell.strip() for cell in lines[i].strip().strip("|").split("|")
                ]
                if not all(re.fullmatch(r":?-+:?", cell) for cell in cells):
                    rows.append(cells)
                i += 1
            story.extend([data_table(rows), Spacer(1, 8)])
            continue
        elif line.startswith("<!-- figure:"):
            story.append(Architecture() if "architecture" in line else screenshots())
            story.append(Spacer(1, 5))
        elif re.match(r"\[\d\]", line):
            story.append(Paragraph(markup(line), style(7.5)))
        elif line.startswith("- "):
            story.append(Paragraph("• " + markup(line[2:]), style(9.5, leftIndent=6)))
        else:
            story.append(Paragraph(markup(line), style()))
        i += 1
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    document = SimpleDocTemplate(
        str(OUTPUT),
        pagesize=A4,
        leftMargin=52,
        rightMargin=52,
        topMargin=46,
        bottomMargin=51,
        title="리스크 렌즈 상세기획서",
        author="리스크 렌즈",
        subject="차입투자와 생활 충격을 확인하는 금융위험 예방 서비스",
    )
    document.build(story, onFirstPage=footer, onLaterPages=footer)
    print(OUTPUT)


if __name__ == "__main__":
    build()
