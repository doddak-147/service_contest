"""Build a source-only cloud archive; never include local secrets or environments."""

import hashlib
import io
import json
import subprocess
import tarfile
from pathlib import Path


def prepare_release(root: Path) -> Path:
    commit = subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=root, text=True
    ).strip()
    files = subprocess.check_output(
        ["git", "ls-files", "apps/api/app", "apps/api/requirements.txt"],
        cwd=root,
        text=True,
    ).splitlines()
    contents = {}
    for name in files:
        relative = Path(name).relative_to("apps/api").as_posix()
        if relative != "requirements.txt" and not (
            relative.startswith("app/") and relative.endswith(".py")
        ):
            raise ValueError("Unexpected runtime resource; review before packaging")
        source = root / name
        if source.is_symlink():
            raise ValueError("Release sources must be regular files")
        contents[relative] = source.read_bytes()
    if "app/main.py" not in contents:
        raise ValueError("Application entry point is missing")
    manifest = {
        "release_id": "api-1.2.0-" + commit[:12],
        "source_commit": commit,
        "files": {
            name: hashlib.sha256(data).hexdigest()
            for name, data in sorted(contents.items())
        },
    }
    contents["release.json"] = json.dumps(manifest, indent=2).encode()
    output = root / "tmp/cloud-release"
    output.mkdir(parents=True, exist_ok=True)
    archive = output / "risk-lens-api.tar.gz"
    with tarfile.open(archive, "w:gz") as package:
        for name, data in sorted(contents.items()):
            info = tarfile.TarInfo(name)
            info.size = len(data)
            info.mode = 0o644
            package.addfile(info, io.BytesIO(data))
    (output / "package-info.json").write_text(
        json.dumps(
            {
                "release_id": manifest["release_id"],
                "sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
                "source_commit": commit,
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    return archive


if __name__ == "__main__":
    print(prepare_release(Path(__file__).resolve().parents[1]))
