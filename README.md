# WASM DOOM

An original Doom-style raycast shooter implemented from scratch in C and
compiled directly to WebAssembly. It does not use Doom, js-dos, DOSBox, an
existing source port, or downloaded game assets.

The C engine owns the framebuffer, world map, raycasting renderer, textured
walls, animated enemies, collision, combat, health, and game state. JavaScript only
loads the WebAssembly module, copies its framebuffer to a canvas, and forwards
browser input. Original raster artwork is stored in `site/assets/hell-atlas.png`.

## Build and run

Requires Clang with the WebAssembly target and `wasm-ld`.

```sh
pnpm install
pnpm build
pnpm check
pnpm start
```

## GitHub Pages

Push `main`. The Pages workflow installs Clang, compiles `src/doom.c` into
`dist/doom.wasm`, verifies the module, and deploys the generated static site.
Set **Settings → Pages → Source** to **GitHub Actions** once for a new repo.
