"""Validate locally generated submission files and create the reference ZIP."""

from __future__ import annotations

import hashlib
import json
import shutil
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tmp/proposal-tools"))
from PIL import Image  # noqa: E402
from pypdf import PdfReader  # noqa: E402

BASE = ROOT / "tmp/submission"
OUTPUT = ROOT / "output/submission"
PACKAGE = OUTPUT / "리스크렌즈_참고자료"
PUBLIC = PACKAGE / "01_공개용"
PRIVATE = PACKAGE / "02_심사내부용_외부공개제외"
MANIFEST = json.loads((BASE / "video-manifest.json").read_text(encoding="utf-8"))


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def validate_pdf(filename: str, pages: int, kind: str | None = None) -> None:
    reader = PdfReader(ROOT / "output/pdf" / filename)
    assert len(reader.pages) == pages
    text = "\n".join(page.extract_text() for page in reader.pages)
    assert "\ufffd" not in text
    assert "API 키" not in text
    if kind:
        video = ROOT / MANIFEST[kind]["file"]
        assert set(reader.attachments) == {video.name}
        assert digest(reader.attachments[video.name][0]) == digest(video.read_bytes())
        assert any(
            annotation.get_object().get("/Subtype") == "/FileAttachment"
            for annotation in reader.pages[-1].get("/Annots", [])
        )
        expected_frames = {
            digest(Image.open(ROOT / chapter["frame"]).convert("RGB").tobytes())
            for chapter in MANIFEST[kind]["chapters"]
        }
        for page in reader.pages:
            for image in page.images:
                assert digest(image.image.convert("RGB").tobytes()) in expected_frames
        if kind == "public":
            assert "가상" in text
            assert "사업자 플랜" in text
            for forbidden in ("심사용_외부공개제외", "apikey=", "Dooz"):
                assert forbidden not in text
            for chapter in MANIFEST[kind]["chapters"]:
                assert chapter["source"].startswith("public-")
            for page in reader.pages:
                for annotation in page.get("/Annots", []):
                    action = annotation.get_object().get("/A", {})
                    assert "심사용" not in str(action)
    print(f"PASS: {pages}-page PDF; text and attachment checks: {filename}")


def main() -> None:
    validate_pdf("리스크렌즈_공개용.pdf", 7, "public")
    validate_pdf("리스크렌즈_심사용_외부공개제외.pdf", 6, "private")
    validate_pdf("리스크렌즈_자료안내_심사내부용.pdf", 6)
    PUBLIC.mkdir(parents=True, exist_ok=True)
    PRIVATE.mkdir(parents=True, exist_ok=True)
    mapping = [
        (ROOT / "output/pdf/리스크렌즈_공개용.pdf", PUBLIC),
        (ROOT / MANIFEST["public"]["file"], PUBLIC),
        (ROOT / "output/pdf/리스크렌즈_심사용_외부공개제외.pdf", PRIVATE),
        (ROOT / MANIFEST["private"]["file"], PRIVATE),
        (ROOT / "output/pdf/리스크렌즈_자료안내_심사내부용.pdf", PRIVATE),
    ]
    files = []
    for source, folder in mapping:
        target = folder / source.name
        shutil.copy2(source, target)
        assert digest(source.read_bytes()) == digest(target.read_bytes())
        files.append(target)
    mail_root = Path.home() / "Desktop/공모전 용"
    for original, name in [
        ("twelve API 문의 메일.png", "메일증빙_문의.png"),
        ("twelve API 답장 메일.png", "메일증빙_답장.png"),
    ]:
        source = mail_root / original
        target = PRIVATE / name
        shutil.copy2(source, target)
        assert digest(source.read_bytes()) == digest(target.read_bytes())
        files.append(target)
    intro = PACKAGE / "00_먼저읽어주세요.txt"
    intro.write_text(
        "리스크 렌즈 공모전 참고자료 | 2026-11-02\n\n"
        "권장 순서: 공식 상세기획서 → 공개용 PDF와 영상 → "
        "심사용 PDF와 영상 → 자료안내\n\n"
        "1. 공식 상세기획서는 별도 필수 업로드 칸에 제출합니다.\n"
        "   이 ZIP은 선택 사항인 '그 외 참고자료' 칸에 제출할 파일입니다.\n"
        "2. 01_공개용: 실제 시세에서 유래하지 않은 가상 예시 자료입니다.\n"
        "   홈페이지 게시·공개 다운로드·대외 홍보에는 "
        "이 폴더의 PDF와 영상을 사용해 주십시오.\n"
        "3. 02_심사내부용_외부공개제외: 공모전 내부 심사 목적으로 제출합니다.\n"
        "   홈페이지 게시·공개 다운로드·대외 홍보에서는 제외해 주시기 바랍니다.\n"
        "   내부용 안내서에는 데이터 제공자에게 보낸 "
        "문의와 답장 원본 캡처를 담았습니다.\n"
        "4. PDF 마지막 쪽에 영상 장면별 시간이 있습니다. "
        "PDF에도 MP4를 파일 첨부했습니다.\n"
        "   첨부 재생을 지원하지 않는 뷰어에서는 같은 폴더의 MP4를 직접 열어 주세요.\n"
        "   두 영상은 무음이며 실기기 화면의 주요 조작을 발췌·편집했습니다.\n"
        "5. 비공개 표시는 주최 측에 대한 처리 요청이며, "
        "수락이 확정된 것으로 표현하지 않았습니다.\n"
        "   공개가 필요한 경우 공개용 자료를 사용해 주십시오.\n\n"
        "팀 리스크 렌즈 | 조장 이도윤 · 팀원 장효재 · 이혁\n"
        "이 묶음에는 APK·API 키·서명 파일·원시 시세 데이터가 없습니다.\n",
        encoding="utf-8-sig",
    )
    files.append(intro)
    hashes = PACKAGE / "파일목록_SHA256.txt"
    hashes.write_text(
        "\n".join(
            f"{digest(path.read_bytes())}  {path.relative_to(PACKAGE).as_posix()}"
            for path in files
        )
        + "\n",
        encoding="utf-8-sig",
    )
    files.append(hashes)
    archive = OUTPUT / "리스크렌즈_참고자료_제출용.zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as bundle:
        for path in files:
            bundle.write(path, path.relative_to(PACKAGE))
    with zipfile.ZipFile(archive) as bundle:
        assert bundle.testzip() is None
        for path in files:
            assert digest(bundle.read(path.relative_to(PACKAGE).as_posix())) == digest(
                path.read_bytes()
            )
    assert archive.stat().st_size < 200_000_000
    assert not any(path.suffix in {".apk", ".jks", ".env"} for path in files)
    desktop = mail_root / archive.name
    shutil.copy2(archive, desktop)
    assert digest(desktop.read_bytes()) == digest(archive.read_bytes())
    print(f"PASS: ZIP integrity, {len(files)} files, {archive.stat().st_size:,} bytes")
    print(f"PASS: Desktop copy SHA256 {digest(archive.read_bytes())}")
    print(archive)


if __name__ == "__main__":
    main()
