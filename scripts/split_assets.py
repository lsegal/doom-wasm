"""Split the authored 4x4 atlas into Godot-ready texture and alpha sprites."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "hell-atlas.png"
OUTPUT = ROOT / "assets" / "generated"

NAMES = (
    "wall_brick", "wall_steel", "wall_moss", "wall_tan",
    "demon_idle", "demon_hurt", "demon_attack", "demon_dead",
    "weapon_idle", "weapon_fire", "ammo", "medkit",
    "floor", "ceiling", "door", "lava",
)


def remove_green(image: Image.Image) -> Image.Image:
    pixels = image.convert("RGBA")
    output = []
    for red, green, blue, alpha in pixels.get_flattened_data():
        green_dominance = green - max(red, blue)
        if green > 18 and green_dominance > 3:
            output.append((red, green, blue, 0))
        elif green_dominance > 0:
            output.append((red, max(red, blue), blue, alpha))
        else:
            output.append((red, green, blue, alpha))
    pixels.putdata(output)
    return pixels


def main() -> None:
    atlas = Image.open(SOURCE).convert("RGBA")
    OUTPUT.mkdir(parents=True, exist_ok=True)

    for index, name in enumerate(NAMES):
        column, row = index % 4, index // 4
        left = round(atlas.width * column / 4)
        right = round(atlas.width * (column + 1) / 4)
        top = round(atlas.height * row / 4)
        bottom = round(atlas.height * (row + 1) / 4)
        tile = atlas.crop((left, top, right, bottom))

        if row in (1, 2):
            tile = remove_green(tile)

        tile.save(OUTPUT / f"{name}.png", optimize=True)

    print(f"Generated {len(NAMES)} Godot textures in {OUTPUT}")


if __name__ == "__main__":
    main()
