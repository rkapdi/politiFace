"""Generates a 1024x1024 placeholder app icon for Politiface.

Outputs to app/assets/icon/app_icon.png. Swap with real artwork by replacing
this PNG (keep the same dimensions) and re-running flutter_launcher_icons.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def find_font(candidates: list[str], size: int) -> ImageFont.FreeTypeFont:
    for path in candidates:
        try:
            return ImageFont.truetype(path, size=size)
        except OSError:
            continue
    return ImageFont.load_default()


def main() -> None:
    size = 1024
    bg = (26, 26, 46, 255)           # #1A1A2E (handoff seed color)
    fg = (255, 255, 255, 255)
    accent = (192, 57, 43, 255)      # #C0392B accent red

    img = Image.new("RGBA", (size, size), bg)
    draw = ImageDraw.Draw(img)

    # Small accent dot in the upper-left third — gives the monogram a
    # politiface-y feel without being mascot-like.
    dot_radius = size * 0.045
    dot_center = (int(size * 0.30), int(size * 0.30))
    draw.ellipse(
        [
            dot_center[0] - dot_radius,
            dot_center[1] - dot_radius,
            dot_center[0] + dot_radius,
            dot_center[1] + dot_radius,
        ],
        fill=accent,
    )

    # Centered "P".
    font = find_font(
        [
            "/System/Library/Fonts/HelveticaNeue.ttc",
            "/System/Library/Fonts/Supplemental/Arial.ttf",
            "/Library/Fonts/Arial.ttf",
        ],
        size=int(size * 0.62),
    )
    text = "P"
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    tx = (size - tw) / 2 - bbox[0]
    ty = (size - th) / 2 - bbox[1]
    draw.text((tx, ty), text, fill=fg, font=font)

    out_dir = Path(__file__).resolve().parent.parent / "app" / "assets" / "icon"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / "app_icon.png"
    img.save(out_path, "PNG")
    print(f"wrote {out_path} ({size}x{size})")


if __name__ == "__main__":
    main()
