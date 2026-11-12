#version 320 es
// Progressive blur: sharp at the bottom of the band, fully blurred at the
// top, in one pass over the live backdrop.
precision highp float;

#include <flutter/runtime_effect.glsl>

uniform vec2 u_size;     // set by the engine: backdrop texture size
uniform vec2 u_origin;   // top-left of the band's clip, physical px
uniform vec2 u_clip;     // size of that clip, physical px
uniform vec2 u_screen;   // screen size, physical px
uniform float u_top;     // physical y where the blur is strongest
uniform float u_bottom;  // physical y where it is zero
uniform float u_max;     // largest radius, physical px
uniform float u_taps;    // samples per pixel, up to 64
uniform vec4 u_tint;     // rgb, strength at the top
uniform sampler2D u_tex;

out vec4 frag_color;

vec2 g_origin;

vec2 texture_origin() {
  if (u_size.x >= u_screen.x - 1.5 && u_size.y >= u_screen.y - 1.5) {
    return vec2(0.0);
  }
  return u_origin - (u_size - u_clip) * 0.5;
}

vec3 tap(vec2 p) {
  vec2 uv = clamp((p - g_origin) / u_size, vec2(0.0), vec2(1.0));
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  return texture(u_tex, uv).rgb;
}

// Interleaved gradient noise: turns sampling patterns into fine grain.
float ign(vec2 p) {
  return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

void main() {
  g_origin = texture_origin();
  vec2 frag = FlutterFragCoord().xy + g_origin;
  float k = clamp((u_bottom - frag.y) / max(u_bottom - u_top, 1.0), 0.0, 1.0);
  k = k * k * (3.0 - 2.0 * k);
  float radius = u_max * k;

  vec3 col;
  if (radius < 0.75) {
    col = tap(frag);
  } else {
    vec3 sum = vec3(0.0);
    float n = 0.0;
    float rot = ign(frag) * 6.2831853;
    for (int i = 0; i < 64; i++) {
      if (float(i) >= u_taps) break;
      float fi = float(i) + 0.5;
      float r = sqrt(fi / u_taps) * radius;
      float a = fi * 2.39996323 + rot;
      sum += tap(frag + vec2(cos(a), sin(a)) * r);
      n += 1.0;
    }
    col = sum / n;
  }
  col = mix(col, u_tint.rgb, u_tint.a * k);
  frag_color = vec4(col, 1.0);
}
