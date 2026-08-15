from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
source = root / "assets" / "gajurmukhi-app-logo.png"
image = Image.open(source).convert("RGBA")
if image.width > 512 or image.height > 512:
    image = image.resize((512, 512), Image.Resampling.LANCZOS)
    image.save(source, format="PNG", optimize=True)
for density, size in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
    target = root / "android" / "app" / "src" / "main" / "res" / f"mipmap-{density}" / "ic_launcher.png"
    target.parent.mkdir(parents=True, exist_ok=True)
    image.resize((size, size), Image.Resampling.LANCZOS).save(target, format="PNG", optimize=True)
