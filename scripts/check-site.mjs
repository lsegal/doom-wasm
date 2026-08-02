import { readFile, stat } from "node:fs/promises";

const wasm = await readFile("dist/doom.wasm");
if (wasm.subarray(0, 4).toString("hex") !== "0061736d") throw new Error("dist/doom.wasm is not WebAssembly");
if ((await stat("dist/doom.wasm")).size < 4_000) throw new Error("doom.wasm is unexpectedly small");

const module = await WebAssembly.compile(wasm);
const exports = WebAssembly.Module.exports(module).map(({ name }) => name);
for (const name of ["memory", "game_init", "game_update", "get_framebuffer", "get_width", "get_height", "get_asset_buffer", "set_assets"]) {
  if (!exports.includes(name)) throw new Error(`doom.wasm is missing export: ${name}`);
}

const source = await readFile("site/app.js", "utf8");
if (source.includes("js-dos") || source.includes("doom.jsdos")) throw new Error("Emulator code is still present");
if (!source.includes("hell-atlas.png")) throw new Error("The game asset atlas is not loaded");
if (!source.includes("fpsFrames")) throw new Error("The FPS counter is missing");
console.log(`Verified original WebAssembly engine (${wasm.length} bytes, ${exports.length} exports).`);
