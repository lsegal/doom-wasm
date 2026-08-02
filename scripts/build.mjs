import { cp, mkdir, rm } from "node:fs/promises";
import { spawnSync } from "node:child_process";

await rm("dist", { recursive: true, force: true });
await cp("site", "dist", { recursive: true });
await mkdir("dist", { recursive: true });

const args = [
  "--target=wasm32",
  "-O3",
  "-nostdlib",
  "-Wl,--no-entry",
  "-Wl,--export-memory",
  "-Wl,--initial-memory=16777216",
  "-Wl,--max-memory=16777216",
  "-Wl,--strip-all",
  "src/doom.c",
  "-o",
  "dist/doom.wasm",
];

const result = spawnSync(process.env.CLANG ?? "clang", args, { stdio: "inherit" });
if (result.error) throw result.error;
if (result.status !== 0) process.exit(result.status ?? 1);

console.log("Built the original C engine as dist/doom.wasm");
