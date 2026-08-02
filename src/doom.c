typedef unsigned int u32;
typedef unsigned char u8;

#define W 320
#define H 200
#define MAP_W 16
#define MAP_H 16
#define ASSET_LIMIT 1600
#define PI 3.14159265f

#define FORWARD 1
#define BACKWARD 2
#define STRAFE_LEFT 4
#define STRAFE_RIGHT 8
#define TURN_LEFT 16
#define TURN_RIGHT 32
#define FIRE 64

static u32 pixels[W * H];
static float depth[W];
static u32 asset_pixels[ASSET_LIMIT * ASSET_LIMIT];
static int asset_width, asset_height, assets_ready;

static const u8 world[MAP_H][MAP_W] = {
  {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
  {1,0,0,0,0,0,0,2,0,0,0,0,0,0,0,1},
  {1,0,3,3,0,0,0,2,0,0,4,4,4,0,0,1},
  {1,0,3,0,0,2,2,2,0,0,4,0,0,0,0,1},
  {1,0,3,0,0,0,0,0,0,0,4,0,2,2,0,1},
  {1,0,0,0,1,1,0,0,3,0,0,0,2,0,0,1},
  {1,2,2,0,1,0,0,0,3,3,3,0,2,0,0,1},
  {1,0,0,0,1,0,4,0,0,0,0,0,0,0,0,1},
  {1,0,3,0,0,0,4,4,4,0,2,2,2,0,0,1},
  {1,0,3,3,3,0,0,0,0,0,0,0,2,0,0,1},
  {1,0,0,0,0,0,1,1,0,3,3,0,0,0,0,1},
  {1,0,2,2,2,0,1,0,0,3,0,0,4,4,0,1},
  {1,0,0,0,2,0,0,0,0,3,0,0,4,0,0,1},
  {1,0,0,0,2,0,0,2,2,2,0,0,4,0,0,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1}
};

typedef struct { float x, y; int alive; } Enemy;
static Enemy demons[6];
static float px, py, angle;
static int hp, demon_count, old_fire;
static float muzzle, hurt_clock;
static float animation_clock;

static float absf(float x) { return x < 0 ? -x : x; }
static int absi(int x) { return x < 0 ? -x : x; }
static float wrap(float x) {
  while (x > PI) x -= 2.0f * PI;
  while (x < -PI) x += 2.0f * PI;
  return x;
}
static float fsin(float x) {
  x = wrap(x);
  float y = 1.27323954f * x - 0.405284735f * x * absf(x);
  return 0.225f * (y * absf(y) - y) + y;
}
static float fcos(float x) { return fsin(x + PI * 0.5f); }
static float minf(float a, float b) { return a < b ? a : b; }
static float maxf(float a, float b) { return a > b ? a : b; }
static u32 rgb(int r, int g, int b) {
  if (r < 0) r = 0; if (r > 255) r = 255;
  if (g < 0) g = 0; if (g > 255) g = 255;
  if (b < 0) b = 0; if (b > 255) b = 255;
  return 0xff000000u | (u32)r | ((u32)g << 8) | ((u32)b << 16);
}
static int solid(float x, float y) {
  int ix = (int)x, iy = (int)y;
  return ix < 0 || iy < 0 || ix >= MAP_W || iy >= MAP_H || world[iy][ix] != 0;
}
static void put(int x, int y, u32 c) {
  if ((u32)x < W && (u32)y < H) pixels[y * W + x] = c;
}

static u32 asset_sample(int tile, int u, int v) {
  if (!assets_ready) return 0;
  int tw = asset_width / 4, th = asset_height / 4;
  int col = tile & 3, row = tile >> 2;
  int x = col * tw + (u & 255) * tw / 256;
  int y = row * th + (v & 255) * th / 256;
  return asset_pixels[y * asset_width + x];
}

static int chroma(u32 c) {
  int r = c & 255, g = (c >> 8) & 255, b = (c >> 16) & 255;
  return g > 18 && g > r + 3 && g > b + 3;
}

static u32 shade(u32 c, int light) {
  int r = (c & 255) * light / 255;
  int g = ((c >> 8) & 255) * light / 255;
  int b = ((c >> 16) & 255) * light / 255;
  return rgb(r, g, b);
}

static void clear_world(void) {
  for (int y = 0; y < H; y++) {
    int sky = 38 - y / 7;
    int floor = 26 + (y - H / 2) / 3;
    for (int x = 0; x < W; x++) {
      u32 c = y < H / 2 ? rgb(sky + 18, sky / 2 + 4, sky / 3 + 3)
                        : rgb(floor, floor - 8, floor - 11);
      if (assets_ready) {
        int tile = y < H / 2 ? 13 : 12;
        c = shade(asset_sample(tile, x * 3, y * 3), y < H / 2 ? 90 : 120);
      }
      pixels[y * W + x] = c;
    }
  }
}

static void walls(void) {
  float dirx = fcos(angle), diry = fsin(angle);
  float planex = -diry * 0.66f, planey = dirx * 0.66f;

  for (int x = 0; x < W; x++) {
    float camera = 2.0f * x / (float)W - 1.0f;
    float rayx = dirx + planex * camera, rayy = diry + planey * camera;
    int mx = (int)px, my = (int)py;
    float ddx = rayx == 0 ? 1e20f : absf(1.0f / rayx);
    float ddy = rayy == 0 ? 1e20f : absf(1.0f / rayy);
    int stepx, stepy, side = 0;
    float sdx, sdy;

    if (rayx < 0) { stepx = -1; sdx = (px - mx) * ddx; }
    else { stepx = 1; sdx = (mx + 1.0f - px) * ddx; }
    if (rayy < 0) { stepy = -1; sdy = (py - my) * ddy; }
    else { stepy = 1; sdy = (my + 1.0f - py) * ddy; }

    while (world[my][mx] == 0) {
      if (sdx < sdy) { sdx += ddx; mx += stepx; side = 0; }
      else { sdy += ddy; my += stepy; side = 1; }
    }

    float distance = side == 0 ? (mx - px + (1 - stepx) * 0.5f) / rayx
                               : (my - py + (1 - stepy) * 0.5f) / rayy;
    if (distance < 0.02f) distance = 0.02f;
    depth[x] = distance;
    int line = (int)(H / distance);
    int top = H / 2 - line / 2, bottom = H / 2 + line / 2;
    if (top < 0) top = 0; if (bottom >= H) bottom = H - 1;

    float hit = side == 0 ? py + distance * rayy : px + distance * rayx;
    int tx = ((int)(hit * 16.0f)) & 15;
    int type = world[my][mx];
    for (int y = top; y <= bottom; y++) {
      int ty = ((y - H / 2 + line / 2) * 16 / (line ? line : 1)) & 15;
      int mortar = (ty == 0 || (ty == 8 && ((tx / 8) & 1)) || tx == 0);
      int light = (int)(190.0f / (1.0f + distance * 0.17f));
      if (side) light = light * 3 / 4;
      if (assets_ready) {
        u32 texel = asset_sample(type - 1, tx * 16, ty * 16);
        put(x, y, shade(texel, mortar ? light / 2 : light));
      } else {
        int r = type == 1 ? light : type == 2 ? light / 2 : type == 3 ? light / 3 : light;
        int g = type == 1 ? light / 3 : type == 2 ? light / 2 : type == 3 ? light / 2 : light / 2;
        int b = type == 1 ? light / 5 : type == 2 ? light / 3 : type == 3 ? light / 5 : light / 5;
        if (mortar) { r /= 3; g /= 3; b /= 3; }
        put(x, y, rgb(r, g, b));
      }
    }
  }
}

static void sprites(void) {
  float dirx = fcos(angle), diry = fsin(angle);
  float planex = -diry * 0.66f, planey = dirx * 0.66f;
  float inv = 1.0f / (planex * diry - dirx * planey);

  for (int i = 0; i < 6; i++) {
    if (!demons[i].alive) continue;
    float sx = demons[i].x - px, sy = demons[i].y - py;
    float tx = inv * (diry * sx - dirx * sy);
    float ty = inv * (-planey * sx + planex * sy);
    if (ty <= 0.1f) continue;
    int screen = (int)((W / 2) * (1.0f + tx / ty));
    int size = absi((int)(H / ty));
    int left = screen - size / 2, right = screen + size / 2;
    int top = H / 2 - size / 2, bottom = H / 2 + size / 2;

    for (int x = left; x < right; x++) {
      if (x < 0 || x >= W || ty >= depth[x]) continue;
      int ux = (x - left) * 64 / (size ? size : 1) - 32;
      for (int y = top; y < bottom; y++) {
        if (y < 0 || y >= H) continue;
        int uy = (y - top) * 64 / (size ? size : 1) - 32;
        int head = ux * ux + (uy + 10) * (uy + 10) < 250;
        int body = absf((float)ux) < 16 && uy > -2 && uy < 27;
        int horns = uy < -16 && (absi(ux) + uy < 5);
        if (!(head || body || horns)) continue;
        int glow = (ux * ux + (uy + 11) * (uy + 11) < 32);
        int sprite_light = (int)(255.0f / (1.0f + ty * 0.08f));
        if (assets_ready) {
          int frame = 4 + (((int)(animation_clock * 2.0f) + i) % 3);
          int su = 4 + (x - left) * 248 / (size ? size : 1);
          int sv = 4 + (y - top) * 248 / (size ? size : 1);
          u32 texel = asset_sample(frame, su, sv);
          if (!chroma(texel)) put(x, y, shade(texel, sprite_light));
        } else {
          put(x, y, glow ? rgb(255, 170, 25) : rgb(sprite_light, sprite_light / 6, sprite_light / 12));
        }
      }
    }
  }
}

static void weapon(void) {
  int kick = (int)(muzzle * 14.0f);
  int cx = W / 2;
  if (assets_ready) {
    int size = 150, left = cx - size / 2, top = H - size + 38 - kick;
    int tile = muzzle > 0.01f ? 9 : 8;
    for (int y = top; y < H; y++) for (int x = left; x < left + size; x++) {
      int su = 4 + (x - left) * 248 / size;
      int sv = 4 + (y - top) * 248 / size;
      u32 texel = asset_sample(tile, su, sv);
      if (!chroma(texel)) put(x, y, texel);
    }
  } else {
  for (int y = 150 + kick; y < H; y++) {
    int half = 12 + (y - 150 - kick) / 3;
    for (int x = cx - half; x <= cx + half; x++) {
      int edge = absi(x - cx) > half - 4;
      put(x, y, edge ? rgb(42, 38, 34) : rgb(92 + (y & 7), 82, 65));
    }
  }
  }
  if (muzzle > 0.01f) {
    int radius = 7 + (int)(muzzle * 9.0f);
    for (int y = H / 2 - radius; y <= H / 2 + radius; y++)
      for (int x = W / 2 - radius; x <= W / 2 + radius; x++)
        if (absi(x - W / 2) + absi(y - H / 2) < radius) put(x, y, rgb(255, 190, 50));
  }
  for (int d = -5; d <= 5; d++) {
    if (absi(d) > 2) { put(W / 2 + d, H / 2, rgb(240,220,190)); put(W / 2, H / 2 + d, rgb(240,220,190)); }
  }
}

static void shoot(void) {
  float dirx = fcos(angle), diry = fsin(angle);
  float planex = -diry * 0.66f, planey = dirx * 0.66f;
  float inv = 1.0f / (planex * diry - dirx * planey);
  int target = -1;
  float closest = 1000.0f;
  for (int i = 0; i < 6; i++) {
    if (!demons[i].alive) continue;
    float sx = demons[i].x - px, sy = demons[i].y - py;
    float tx = inv * (diry * sx - dirx * sy);
    float ty = inv * (-planey * sx + planex * sy);
    if (ty > 0.1f && absf(tx / ty) < 0.12f && ty < closest && ty < depth[W / 2] + 0.3f) {
      target = i; closest = ty;
    }
  }
  if (target >= 0) { demons[target].alive = 0; demon_count--; }
}

__attribute__((export_name("game_init"))) void game_init(void) {
  px = 1.7f; py = 1.7f; angle = 0.15f; hp = 100; demon_count = 6;
  old_fire = 0; muzzle = 0; hurt_clock = 0; animation_clock = 0;
  const float ex[6] = {5.5f, 9.5f, 13.5f, 3.5f, 8.5f, 13.5f};
  const float ey[6] = {2.5f, 4.5f, 6.5f, 10.5f, 12.5f, 14.0f};
  for (int i = 0; i < 6; i++) { demons[i].x = ex[i]; demons[i].y = ey[i]; demons[i].alive = 1; }
}

__attribute__((export_name("game_update"))) void game_update(float dt, int input, int mouse_dx) {
  if (dt > 0.05f) dt = 0.05f;
  if (hp > 0 && demon_count > 0) {
    float turn = ((input & TURN_RIGHT) ? 1.0f : 0.0f) - ((input & TURN_LEFT) ? 1.0f : 0.0f);
    angle = wrap(angle + turn * dt * 2.2f + mouse_dx * 0.0025f);
    float dx = fcos(angle), dy = fsin(angle);
    float forward = ((input & FORWARD) ? 1.0f : 0.0f) - ((input & BACKWARD) ? 1.0f : 0.0f);
    float strafe = ((input & STRAFE_RIGHT) ? 1.0f : 0.0f) - ((input & STRAFE_LEFT) ? 1.0f : 0.0f);
    float vx = (dx * forward - dy * strafe) * dt * 2.4f;
    float vy = (dy * forward + dx * strafe) * dt * 2.4f;
    if (!solid(px + vx + (vx > 0 ? .18f : -.18f), py)) px += vx;
    if (!solid(px, py + vy + (vy > 0 ? .18f : -.18f))) py += vy;

    int firing = (input & FIRE) != 0;
    if (firing && !old_fire) { muzzle = 1.0f; shoot(); }
    old_fire = firing;

    hurt_clock -= dt;
    for (int i = 0; i < 6; i++) if (demons[i].alive) {
      float ex = demons[i].x - px, ey = demons[i].y - py;
      float distance2 = ex * ex + ey * ey;
      if (distance2 < 12.0f && distance2 > .5f) {
        float scale = dt * .28f;
        float nx = demons[i].x - ex * scale, ny = demons[i].y - ey * scale;
        if (!solid(nx, demons[i].y)) demons[i].x = nx;
        if (!solid(demons[i].x, ny)) demons[i].y = ny;
      }
      if (distance2 < .7f && hurt_clock <= 0) { hp -= 8; if (hp < 0) hp = 0; hurt_clock = .55f; }
    }
  }
  muzzle = maxf(0, muzzle - dt * 5.5f);
  animation_clock += dt;
  clear_world(); walls(); sprites(); weapon();
  if (hurt_clock > .35f) {
    for (int i = 0; i < W * H; i += 5) pixels[i] = rgb(130, 0, 0);
  }
}

__attribute__((export_name("get_framebuffer"))) u32 get_framebuffer(void) { return (u32)pixels; }
__attribute__((export_name("get_width"))) int get_width(void) { return W; }
__attribute__((export_name("get_height"))) int get_height(void) { return H; }
__attribute__((export_name("get_health"))) int get_health(void) { return hp; }
__attribute__((export_name("get_enemies"))) int get_enemies(void) { return demon_count; }
__attribute__((export_name("get_asset_buffer"))) u32 get_asset_buffer(void) { return (u32)asset_pixels; }
__attribute__((export_name("set_assets"))) void set_assets(int width, int height) {
  if (width > 0 && height > 0 && width <= ASSET_LIMIT && height <= ASSET_LIMIT) {
    asset_width = width; asset_height = height; assets_ready = 1;
  }
}
