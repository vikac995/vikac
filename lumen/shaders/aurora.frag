#version 320 es
// Aurora: a domain-warped noise field. The finger swirls and pulls it.
precision highp float;

#include <flutter/runtime_effect.glsl>

uniform vec2 u_size;      // logical px
uniform float u_time;     // seconds
uniform vec2 u_touch;     // logical px
uniform float u_press;    // 0 to 1
uniform float u_octaves;  // 2 to 6
uniform vec3 u_c0;        // background
uniform vec3 u_c1;
uniform vec3 u_c2;
uniform vec3 u_c3;

out vec4 frag_color;

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
             mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  mat2 m = mat2(1.6, 1.2, -1.2, 1.6);
  for (int i = 0; i < 6; i++) {
    if (float(i) >= u_octaves) break;
    v += a * noise(p);
    p = m * p;
    a *= 0.5;
  }
  return v;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  float s = min(u_size.x, u_size.y);
  vec2 p = frag / s * 2.0;
  vec2 t = u_touch / s * 2.0;

  // Swirl and pull around the finger.
  vec2 d = p - t;
  float r2 = dot(d, d);
  float infl = u_press * exp(-r2 * 2.6);
  float ang = infl * 2.6;
  mat2 rot = mat2(cos(ang), -sin(ang), sin(ang), cos(ang));
  p = t + rot * d * (1.0 - 0.35 * infl);

  float time = u_time * 0.07;
  vec2 q = vec2(fbm(p + vec2(0.0, time)), fbm(p + vec2(5.2, 1.3) - time));
  vec2 w = vec2(fbm(p + 3.6 * q + vec2(1.7, 9.2) + time * 1.4),
                fbm(p + 3.6 * q + vec2(8.3, 2.8) - time));
  float f = fbm(p + 3.2 * w);

  vec3 col = mix(u_c0, u_c1, clamp(f * f * 2.4, 0.0, 1.0));
  col = mix(col, u_c2, clamp(length(q) * 0.95 - 0.28, 0.0, 1.0));
  col = mix(col, u_c3, clamp(w.y * w.y * 1.7 - 0.22, 0.0, 1.0) * 0.85);
  col += infl * 0.22 * (u_c2 + u_c3) * 0.5;

  // Fine dither: hides banding in the dark gradients.
  col += (hash(frag + fract(u_time * 7.0)) - 0.5) / 255.0;
  frag_color = vec4(clamp(col, 0.0, 1.0), 1.0);
}
