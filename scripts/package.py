"""Build and verify a distributable Professionator ZIP from validated source."""
import argparse
import hashlib
import json
import re
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

PROJECT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", action="store_true", help="Build a ZIP containing only addon files, README, and license.")
    parser.add_argument("--output-directory", type=Path, default=PROJECT / "artifacts", help="Directory for the verified ZIP and its manifest.")
    arguments = parser.parse_args()
    if not arguments.build:
        parser.print_help()
        return 0

    report_path = PROJECT / "artifacts/integration-report.json"
    if not report_path.exists():
        parser.error("Run scripts/validate.py --run before packaging.")
    report = json.loads(report_path.read_text(encoding="utf-8"))
    if not report.get("passed"):
        parser.error("The integration workflow did not pass.")
    addon_directory = PROJECT / "Professionator"
    sources = sorted(path for path in addon_directory.iterdir() if path.is_file())
    for source in sources:
        if source.suffix not in (".lua", ".toc"):
            parser.error(f"Unexpected addon file: {source.name}")
        if hashlib.sha256(source.read_bytes()).hexdigest() != report["sourceHashes"].get(source.name):
            parser.error(f"Source changed after validation: {source.name}. Run validation again.")

    version = re.search(r"^## Version: (.+)$", (addon_directory / "Professionator.toc").read_text(encoding="utf-8"), re.MULTILINE).group(1).strip()
    files = {"Professionator/" + source.name: source.read_bytes() for source in sources}
    for filename in ("README.md", "LICENSE"):
        files["Professionator/" + filename] = (PROJECT / filename).read_bytes()
    arguments.output_directory.mkdir(parents=True, exist_ok=True)
    destination = arguments.output_directory / f"Professionator-{version}.zip"
    with ZipFile(destination, "w", compression=ZIP_DEFLATED) as archive:
        for filename, contents in files.items():
            archive.writestr(filename, contents)
    with ZipFile(destination) as archive:
        if set(archive.namelist()) != set(files) or archive.testzip() is not None:
            raise RuntimeError("Archive structure or integrity validation failed.")
        for filename, contents in files.items():
            if archive.read(filename) != contents:
                raise RuntimeError(f"Packaged content differs: {filename}")
    manifest = {"version": version, "archive": destination.name,
                "sha256": hashlib.sha256(destination.read_bytes()).hexdigest(),
                "files": {filename: hashlib.sha256(contents).hexdigest() for filename, contents in files.items()}}
    destination.with_suffix(".json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Built and verified {len(files)} files: {destination}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
