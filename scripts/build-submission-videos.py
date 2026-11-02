"""Edit local, consented Android screen recordings into contest videos.

Raw files under tmp/submission and private outputs are intentionally ignored.
No API credentials or live data are needed to run the editor.
"""

from __future__ import annotations

import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "tmp/submission"
OUT = ROOT / "output/video"
FONT = "C\\:/Windows/Fonts/malgun.ttf"


def run(args: list[str]) -> None:
    subprocess.run(args, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)


def duration(path: Path) -> float:
    return float(
        subprocess.check_output(
            [
                "ffprobe",
                "-v",
                "error",
                "-show_entries",
                "format=duration",
                "-of",
                "default=noprint_wrappers=1:nokey=1",
                str(path),
            ]
        )
    )


def draw(text: str, name: str, size: int, y: int, color: str = "white") -> str:
    target = BASE / f"{name}.txt"
    target.write_text(text, encoding="utf-8")
    relative = target.relative_to(ROOT).as_posix()
    return (
        f"drawtext=fontfile='{FONT}':textfile='{relative}':"
        f"fontcolor={color}:fontsize={size}:x=(w-text_w)/2:y={y}"
    )


def encode(args: list[str], target: Path) -> None:
    run(
        [
            "ffmpeg",
            "-y",
            "-v",
            "error",
            *args,
            "-an",
            "-r",
            "15",
            "-c:v",
            "libx264",
            "-preset",
            "fast",
            "-crf",
            "21",
            "-pix_fmt",
            "yuv420p",
            "-movflags",
            "+faststart",
            str(target),
        ]
    )


def build(kind: str, entries: list[tuple[str, str, str]], filename: str) -> dict:
    public = kind == "public"
    label = "공개용 · 완전 가상 예시" if public else "심사 내부용 · 외부 공개 제외"
    segments: list[Path] = []
    chapters = []
    clock = 5.0
    for suffix, lines in [
        (
            "intro",
            [
                "리스크 렌즈",
                label,
                "금융위험 예방 서비스",
                "실기기 화면 · 주요 조작 발췌 · 무음",
            ],
        ),
        (
            "outro",
            [
                "리스크 렌즈",
                "조장 이도윤 · 팀원 장효재 · 이혁",
                "투자 추천·미래 예측을 제공하지 않습니다.",
                "실제 시세에서 유래하지 않은 가상 예시입니다."
                if public
                else "홈페이지 게시·공개 다운로드·대외 홍보 제외 요청",
            ],
        ),
    ]:
        filters = [
            draw(line, f"{kind}-{suffix}-{i}", 56 if i == 0 else 33, 600 + i * 140)
            for i, line in enumerate(lines)
        ]
        path = BASE / f"{kind}-{suffix}.mp4"
        encode(
            [
                "-f",
                "lavfi",
                "-i",
                "color=c=0x103B45:s=1080x1920:r=15:d=5",
                "-vf",
                ",".join(filters),
            ],
            path,
        )
        if suffix == "intro":
            segments.append(path)
        else:
            outro = path
    for index, (source, capture, title) in enumerate(entries, 1):
        raw = BASE / f"{source}.mp4"
        start_epoch = json.loads((BASE / f"{source}.recording.json").read_text())[
            "start"
        ]
        point = (BASE / f"{capture}.png").stat().st_mtime - start_epoch
        length = 9.0
        start = max(0.0, min(point - 4, duration(raw) - length - 0.05))
        filters = [
            "crop=1080:2144:0:70",
            "scale=-2:1720",
            "pad=1080:1920:(ow-iw)/2:100:color=0x103B45",
            "setsar=1",
            "tpad=stop_mode=clone:stop_duration=1",
            draw(f"{index:02d}  {title}", f"{kind}-heading-{index}", 35, 30),
            draw(label, f"{kind}-label-{index}", 29, 1835),
            draw(
                "실기기 화면 · 주요 조작 발췌 · 무음",
                f"{kind}-footer-{index}",
                23,
                1880,
            ),
        ]
        segment = BASE / f"{kind}-edit-{index:02d}.mp4"
        encode(
            [
                "-ss",
                str(start),
                "-i",
                str(raw),
                "-t",
                str(length),
                "-vf",
                ",".join(filters),
            ],
            segment,
        )
        segments.append(segment)
        chapters.append(
            {
                "title": title,
                "start": clock,
                "duration": length,
                "frame_at": round(
                    clock + max(0.3, min(length - 0.3, point - start)), 3
                ),
                "capture": capture,
                "source": raw.name,
                "source_start": round(start, 3),
            }
        )
        clock += length
    segments.append(outro)
    concat = BASE / f"{kind}-concat.txt"
    concat.write_text("\n".join(f"file '{p.name}'" for p in segments), encoding="utf-8")
    target = OUT / filename
    run(
        [
            "ffmpeg",
            "-y",
            "-v",
            "error",
            "-f",
            "concat",
            "-safe",
            "0",
            "-i",
            str(concat),
            "-c",
            "copy",
            "-movflags",
            "+faststart",
            str(target),
        ]
    )
    for index, chapter in enumerate(chapters, 1):
        frame = BASE / f"{kind}-final-frame-{index:02d}.png"
        run(
            [
                "ffmpeg",
                "-y",
                "-v",
                "error",
                "-ss",
                str(chapter["frame_at"]),
                "-i",
                str(target),
                "-frames:v",
                "1",
                str(frame),
            ]
        )
        chapter["frame"] = frame.relative_to(ROOT).as_posix()
    return {
        "file": target.relative_to(ROOT).as_posix(),
        "duration": duration(target),
        "sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
        "chapters": chapters,
        "audio": False,
    }


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {}
    manifest["public"] = build(
        "public",
        [
            ("public-new", "public-profile", "가상 재무정보로 체험 시작"),
            ("public-new", "public-cash-summary", "생활 충격 전후 현금 잔액"),
            ("public-new", "public-cash-graph", "월별 현금흐름 그래프"),
            ("public-flow", "public-history", "완전 가상 과거 위험 그래프"),
            ("public-flow", "public-combined", "차입금과 손실 충격 연결"),
            ("public-quiz", "public-quiz-wrong", "위험 이해 체험 · 오답 설명"),
            ("public-quiz", "public-quiz-correct", "위험 이해 체험 · 정답 확인"),
        ],
        "리스크렌즈_공개용_시연.mp4",
    )
    manifest["private"] = build(
        "private",
        [
            ("private-setup", "private-health", "가상 재무정보의 계산 결과"),
            ("private-stock", "private-risk", "실제 종목 과거 위험 분석"),
            ("private-stock", "private-dates", "고점·저점·회복 기준일"),
            (
                "private-chart-final",
                "private-history-final",
                "일별 종가 기반 원화·달러 차트",
            ),
            ("private-stock", "private-source", "데이터 출처와 참고 환율"),
            ("private-impact", "private-impact-bars", "관측 MDD를 재무 조건에 적용"),
            ("private-impact", "private-explanation", "기본 설명과 시나리오별 비교"),
        ],
        "리스크렌즈_심사용_외부공개제외.mp4",
    )
    (BASE / "video-manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    for key, item in manifest.items():
        print(key, item["file"], round(item["duration"], 2), "seconds")


if __name__ == "__main__":
    main()
