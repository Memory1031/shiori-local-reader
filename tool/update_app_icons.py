"""Generate native icons on macOS using system sips."""
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/branding/shiori-icon.png"

def main():
    if not shutil.which("sips"):
        raise SystemExit("macOS sips required; on Windows use update-app-icons.ps1")
    targets = {f"android/app/src/main/res/mipmap-{d}/ic_launcher.png": n
               for d, n in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items()}
    catalog = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    for entry in json.loads((catalog / "Contents.json").read_text())["images"]:
        targets[str((catalog / entry["filename"]).relative_to(ROOT))] = round(float(entry["size"].split("x")[0]) * float(entry["scale"][:-1]))
    for path, size in targets.items():
        subprocess.run(["sips", "-z", str(size), str(size), str(SOURCE), "--out", str(ROOT / path)], check=True, stdout=subprocess.DEVNULL)
    for path in ["android/app/src/main/res/drawable-nodpi/shiori_launch_logo.png", "ios/Runner/Assets.xcassets/ShioriLaunchLogo.imageset/shiori-logo.png"]:
        shutil.copyfile(SOURCE, ROOT / path)
    print(f"Generated {len(targets)} app icons and two launch images.")

if __name__ == "__main__":
    main()
