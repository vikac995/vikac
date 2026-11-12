#version 320 es
// Lumen glass. Runs as a backdrop filter: the engine hands us the pixels
// already on screen (blurred by an earlier pass) and we bend, tint and light
// them inside one rounded shape.
precision highp float;

#include <flutter/runtime_effect.glsl>

uniform vec2 u_size;        // set by the engine: size of the backdrop texture
uniform vec2 u_center;      // shape centre, physical px
uniform vec2 u_half;        // shape half extents, physical px
uniform float u_radius;     // corner radius, physical px
uniform float u_bevel;      // width of the refracting rim, physical px
uniform float u_refract;    // max displacement at the rim, physical px
uniform float u_dispersion; // 0 = off, otherwise RGB split fraction
uniform float u_magnify;    // 1 = none; >1 enlarges what is behind
uniform vec4 u_tint;        // rgb + base amount
uniform float u_light;      // rim light strength
uniform float u_saturation; // 1 = unchanged
uniform float u_adapt;      // extra tint where the backdrop fights the foreground
uniform float u_px;         // device pixel ratio
uniform vec2 u_origin;      // top-left of this surface's clip, physical px
uniform vec2 u_clip;        // size of that clip, physical px
uniform vec2 u_screen;      // size of the screen, physical px
uniform sampler2D u_tex;

out vec4 frag_color;

float sd_round_box(vec2 p, vec2 b, float r) {
  vec2 q = abs(p) - b + r;
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// The engine may hand us the whole screen or only the part under this
// surface's clip, depending on how the layers are arranged. The texture size
// tells us which, and from that where the texture's top-left sits on screen.
vec2 texture_origin() {
  if (u_size.x >= u_screen.x - 1.5 && u_size.y >= u_screen.y - 1.5) {
    return vec2(0.0);
  }
  return u_origin - (u_size - u_clip) * 0.5;
}

vec2 g_origin;

vec3 tap(vec2 p) {
  vec2 uv = clamp((p - g_origin) / u_size, vec2(0.0), vec2(1.0));
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  return texture(u_tex, uv).rgb;
}

void main() {
  g_origin = texture_origin();
  vec2 frag = FlutterFragCoord().xy + g_origin;
  vec2 p = frag - u_center;
  float d = sd_round_box(p, u_half, u_radius);

  if (d > 1.0) {
    frag_color = vec4(tap(frag), 1.0);
    return;
  }

  float depth = max(-d, 0.0);

  // Outward normal from the distance field.
  vec2 e = vec2(1.0, 0.0);
  vec2 n = vec2(
    sd_round_box(p + e.xy, u_half, u_radius) - sd_round_box(p - e.xy, u_half, u_radius),
    sd_round_box(p + e.yx, u_half, u_radius) - sd_round_box(p - e.yx, u_half, u_radius));
  n = n / max(length(n), 1e-4);

  // Rim profile: 1 at the edge, easing to 0 where the glass goes flat.
  float t = clamp(1.0 - depth / max(u_bevel, 1.0), 0.0, 1.0);
  float bend = 1.0 - sqrt(1.0 - t * t);

  vec2 src = u_center + p / u_magnify;
  vec2 disp = -n * bend * u_refract;

  vec3 col;
  if (u_dispersion > 0.0) {
    col.r = tap(src + disp * (1.0 - u_dispersion)).r;
    col.g = tap(src + disp).g;
    col.b = tap(src + disp * (1.0 + u_dispersion)).b;
  } else {
    col = tap(src + disp);
  }

  float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
  col = mix(vec3(luma), col, u_saturation);

  // Tint, plus extra tint where the backdrop would hurt legibility: bright
  // content under a dark tint, dark content under a light one.
  float tint_luma = dot(u_tint.rgb, vec3(0.2126, 0.7152, 0.0722));
  float clash = tint_luma < 0.5 ? smoothstep(0.45, 0.95, luma) : smoothstep(0.55, 0.05, luma);
  float amount = clamp(u_tint.a + u_adapt * clash, 0.0, 0.96);
  col = mix(col, u_tint.rgb, amount);

  // Lighting: a thin specular line on the rim, strongest top-left and
  // bottom-right, with a soft glow and shade across the bevel.
  float k = dot(n, normalize(vec2(-0.55, -0.83)));
  float rim = smoothstep(1.6 * u_px, 0.0, depth);
  float spec = 0.22 + 0.78 * pow(abs(k), 1.6);
  col += rim * spec * u_light;
  col += t * t * max(k, 0.0) * 0.10 * u_light;
  col *= 1.0 - t * t * max(-k, 0.0) * 0.10;

  frag_color = vec4(clamp(col, 0.0, 1.0), 1.0);
}
