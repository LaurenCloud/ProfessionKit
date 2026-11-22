"""Generate the antialiased craft wheel texture used in the recipe list."""
import argparse
from pathlib import Path

from PIL import Image, ImageDraw


def generate(destination):
    tile_size = 64
    sample_size = tile_size * 8
    frames_per_mode = 64
    atlas = Image.new("RGBA", (16 * tile_size, 8 * tile_size))
    sample_bounds = (0, 0, sample_size - 1, sample_size - 1)
    track_color, progress_color = (152, 111, 49), (255, 210, 88)

    # Share the exact inner and outer silhouettes across every animation frame.
    alpha = Image.new("L", (sample_size, sample_size))
    ImageDraw.Draw(alpha).ellipse((22, 22, sample_size - 23, sample_size - 23), outline=255, width=38)
    alpha = alpha.resize((tile_size, tile_size), Image.Resampling.LANCZOS)
    for frame in range(2 * frames_per_mode):
        colors = Image.new("RGB", (sample_size, sample_size), track_color)
        draw = ImageDraw.Draw(colors)
        if frame >= frames_per_mode:
            start = -90 + (frame - frames_per_mode) * 360 / frames_per_mode
            draw.pieslice(sample_bounds, start, start + 90, fill=progress_color)
        elif frame == frames_per_mode - 1:
            draw.rectangle(sample_bounds, fill=progress_color)
        elif frame > 0:
            draw.pieslice(sample_bounds, -90, -90 + frame * 360 / (frames_per_mode - 1), fill=progress_color)
        tile = colors.resize((tile_size, tile_size), Image.Resampling.LANCZOS)
        tile.putalpha(alpha)
        atlas.paste(tile, (frame % 16 * tile_size, frame // 16 * tile_size))
    atlas.save(destination)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", action="store_true", help="Write CraftWheel.tga to the ProfessionKit addon directory.")
    if parser.parse_args().build:
        generate(Path(__file__).resolve().parents[1] / "ProfessionKit" / "CraftWheel.tga")
    else:
        parser.print_help()
