# WASM Doom — Godot Edition

An original Doom-style first-person shooter built as a native Godot 4 project.
It uses Godot's 3D renderer, physics, CharacterBody3D movement, raycast combat,
billboard enemies, textured level geometry, and CanvasLayer HUD.

The artwork in `assets/` is original. This project does not contain Doom source
code, WADs, js-dos, DOSBox, or commercial game assets.

## Run locally

Open `project.godot` in Godot 4.7.1 and press **F6**.

Controls:

- `WASD` or arrow keys: move and turn
- Mouse: look
- Left click or `Space`: fire
- `Esc`: release the mouse
- `R`: restart after victory or death

## Export for GitHub Pages

The workflow downloads the official Godot 4.7.1 editor and matching export
templates, exports the `Web` preset to `dist/`, and deploys it with GitHub Pages.

To export locally, install the Godot 4.7.1 export templates, then run:

```sh
godot --headless --path . --export-release Web build/web/index.html
```

`scripts/split_assets.py` reproducibly derives the Godot-ready texture and
alpha-sprite files from the authored atlas.
