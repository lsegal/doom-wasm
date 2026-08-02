const canvas = document.querySelector("#game");
const context = canvas.getContext("2d", { alpha: false });
const frame = document.querySelector("#game-frame");
const loading = document.querySelector("#loading");
const message = document.querySelector("#message");
const health = document.querySelector("#health");
const enemies = document.querySelector("#enemies");
const fps = document.querySelector("#fps");
const fullscreen = document.querySelector("#fullscreen");

context.imageSmoothingEnabled = false;

const INPUT = {
  FORWARD: 1,
  BACKWARD: 2,
  LEFT: 4,
  RIGHT: 8,
  TURN_LEFT: 16,
  TURN_RIGHT: 32,
  FIRE: 64,
};

const keyMap = new Map([
  ["KeyW", INPUT.FORWARD],
  ["ArrowUp", INPUT.FORWARD],
  ["KeyS", INPUT.BACKWARD],
  ["ArrowDown", INPUT.BACKWARD],
  ["KeyA", INPUT.LEFT],
  ["KeyD", INPUT.RIGHT],
  ["ArrowLeft", INPUT.TURN_LEFT],
  ["ArrowRight", INPUT.TURN_RIGHT],
  ["Space", INPUT.FIRE],
  ["ControlLeft", INPUT.FIRE],
]);

let input = 0;
let mouseTurn = 0;
let lastTime = performance.now();
let fpsStarted = lastTime;
let fpsFrames = 0;

const response = await fetch("./doom.wasm");
if (!response.ok) throw new Error(`Unable to load doom.wasm (${response.status})`);
const bytes = await response.arrayBuffer();
const { instance } = await WebAssembly.instantiate(bytes);
const game = instance.exports;

const atlas = new Image();
atlas.src = "./assets/hell-atlas.png";
await atlas.decode();
const atlasCanvas = document.createElement("canvas");
atlasCanvas.width = atlas.naturalWidth;
atlasCanvas.height = atlas.naturalHeight;
const atlasContext = atlasCanvas.getContext("2d", { willReadFrequently: true });
atlasContext.drawImage(atlas, 0, 0);
const atlasPixels = atlasContext.getImageData(0, 0, atlasCanvas.width, atlasCanvas.height).data;
new Uint8Array(game.memory.buffer, game.get_asset_buffer(), atlasPixels.length).set(atlasPixels);
game.set_assets(atlasCanvas.width, atlasCanvas.height);

game.game_init();
const image = context.createImageData(game.get_width(), game.get_height());
loading.hidden = true;
canvas.focus();

function loop(now) {
  const delta = Math.min((now - lastTime) / 1000, 0.05);
  lastTime = now;

  game.game_update(delta, input, mouseTurn);
  mouseTurn = 0;

  const source = new Uint8ClampedArray(
    game.memory.buffer,
    game.get_framebuffer(),
    image.data.length,
  );
  image.data.set(source);
  context.putImageData(image, 0, 0);

  fpsFrames++;
  if (now - fpsStarted >= 500) {
    fps.textContent = Math.round((fpsFrames * 1000) / (now - fpsStarted));
    fpsFrames = 0;
    fpsStarted = now;
  }

  const hp = game.get_health();
  const remaining = game.get_enemies();
  health.textContent = hp;
  enemies.textContent = remaining;

  if (hp <= 0) {
    message.textContent = "YOU DIED — press R to restart";
    message.hidden = false;
  } else if (remaining === 0) {
    message.textContent = "HELL CLEARED — press R to restart";
    message.hidden = false;
  } else {
    message.hidden = true;
  }

  requestAnimationFrame(loop);
}

addEventListener("keydown", (event) => {
  if (event.code === "KeyR" && (game.get_health() <= 0 || game.get_enemies() === 0)) {
    game.game_init();
  }
  const bit = keyMap.get(event.code);
  if (bit) {
    input |= bit;
    event.preventDefault();
  }
});

addEventListener("keyup", (event) => {
  const bit = keyMap.get(event.code);
  if (bit) {
    input &= ~bit;
    event.preventDefault();
  }
});

canvas.addEventListener("click", () => canvas.requestPointerLock());
addEventListener("mousemove", (event) => {
  if (document.pointerLockElement === canvas) mouseTurn += event.movementX;
});

fullscreen.addEventListener("click", async () => {
  if (document.fullscreenElement) await document.exitFullscreen();
  else await frame.requestFullscreen();
});

addEventListener("error", (event) => {
  loading.hidden = false;
  loading.textContent = `Startup failed: ${event.message}`;
});

requestAnimationFrame(loop);
