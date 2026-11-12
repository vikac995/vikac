#version 320 es
// Ripples: bends the pixels of the widget below like a water surface and
// lights the wave crests.
precision highp float;

#include <flutter/runtime_effect.glsl>

uniform vec2 u_size;  // set by the engine: texture size
uniform vec4 u_r0;    // x, y (texture px), age (s), amplitude
uniform vec4 u_r1;
uniform vec4 u_r2;
uniform vec4 u_r3;
uniform vec4 u_r4;
uniform vec4 u_r5;
uniform float u_px;   // device pixel ratio
uniform sampler2D u_tex;

out vec4 frag_color;

vec2 g_disp;
float g_light;

void ripple(vec2 frag, vec4 r) {
  if (r.w <= 0.0) return;
  vec2 d = frag - r.xy;
  float dist = length(d);
  float speed = 520.0 * u_px;
  float k = 6.2831 / (52.0 * u_px);
  float x = dist - r.z * speed;
  float width = (34.0 + r.z * 70.0) * u_px;
  float env = exp(-(x * x) / (2.0 * width * width)) * exp(-r.z * 1.5) * r.w;
  float wave = sin(x * k);
  vec2 dir = dist > 0.001 ? d / dist : vec2(0.0);
  g_disp += dir * wave * env * 16.0 * u_px;
  g_light += cos(x * k) * env;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  g_disp = vec2(0.0);
  g_light = 0.0;
  ripple(frag, u_r0);
  ripple(frag, u_r1);
  ripple(frag, u_r2);
  ripple(frag, u_r3);
  ripple(frag, u_r4);
  ripple(frag, u_r5);

  // No y flip here: unlike a backdrop, a layer's own texture is already
  // upright on every backend.
  vec2 uv = clamp((frag + g_disp) / u_size, vec2(0.0), vec2(1.0));
  vec4 c = texture(u_tex, uv);
  c.rgb += vec3(max(g_light, 0.0) * 0.16 - max(-g_light, 0.0) * 0.08);
  frag_color = vec4(clamp(c.rgb, 0.0, 1.0) * c.a, c.a);
}
