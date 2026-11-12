#version 320 es
// Discomorphism. A mirror ball made of flat tiles, each reflecting a few
// moving coloured lights, and the light spots it throws around the room.
precision highp float;

#include <flutter/runtime_effect.glsl>

uniform vec2 u_size;    // logical px
uniform float u_time;
uniform vec3 u_ball;    // centre x, y, radius (logical px)
uniform float u_party;  // 0.25 calm to 1 full party
uniform float u_beat;   // 0 to 1, pulses on the beat
uniform float u_spin;   // rotation angle, radians

out vec4 frag_color;

const float PI = 3.14159265;

float hash(vec2 p) {
  p = fract(p * vec2(234.34, 435.345));
  p += dot(p, p + 34.23);
  return fract(p.x * p.y);
}

vec3 hue(float h) {
  return clamp(abs(fract(h + vec3(0.0, 2.0, 1.0) / 3.0) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
}

vec3 rotY(vec3 v, float a) {
  float c = cos(a), s = sin(a);
  return vec3(c * v.x + s * v.z, v.y, -s * v.x + c * v.z);
}

// What a tile sees: a dark club, a white key light and three coloured
// spotlights circling the room.
vec3 env(vec3 d) {
  // Soft ambient: a mirror ball reads as silver because it reflects a
  // dimly lit room, not a black void.
  vec3 col = mix(vec3(0.10, 0.09, 0.13), vec3(0.32, 0.30, 0.38), smoothstep(-0.6, 0.9, d.y));
  float t = u_time;
  for (int i = 0; i < 3; i++) {
    float fi = float(i);
    vec3 L = normalize(vec3(cos(t * (0.5 + 0.17 * fi) + fi * 2.1), 0.35 + 0.25 * sin(t * 0.7 + fi), sin(t * (0.5 + 0.17 * fi) + fi * 2.1)));
    col += hue(fi / 3.0 + t * 0.03) * pow(max(dot(d, L), 0.0), 12.0) * 1.8 * u_party;
  }
  col += vec3(1.0, 0.97, 0.9) * pow(max(dot(d, normalize(vec3(-0.4, 0.8, 0.5))), 0.0), 22.0) * 1.6;
  return col;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 c = u_ball.xy;
  float R = u_ball.z;
  vec2 p = frag - c;
  float r = length(p) / R;
  vec3 col;

  if (r < 1.0) {
    // Sphere point and its position on the turning ball.
    vec3 n = vec3(p.x / R, -p.y / R, sqrt(max(1.0 - r * r, 0.0)));
    vec3 o = rotY(n, u_spin);
    float lat = asin(clamp(o.y, -1.0, 1.0));
    float lon = atan(o.z, o.x);

    const float rows = 24.0;
    float fy = (lat / PI + 0.5) * rows;
    float row = floor(fy);
    float latC = ((row + 0.5) / rows - 0.5) * PI;
    float cols = max(4.0, floor(rows * 2.0 * cos(latC)));
    float fx = (lon / (2.0 * PI) + 0.5) * cols;
    float colI = floor(fx);
    vec2 id = vec2(colI, row);
    vec2 f = vec2(fract(fx), fract(fy));

    // Each tile is flat: its normal is the tile centre's, slightly askew.
    float lonC = ((colI + 0.5) / cols - 0.5) * 2.0 * PI;
    vec3 tn = vec3(cos(latC) * cos(lonC), sin(latC), cos(latC) * sin(lonC));
    tn = normalize(tn + 0.06 * (vec3(hash(id), hash(id + 7.1), hash(id + 3.3)) - 0.5));
    tn = rotY(tn, -u_spin);

    vec3 refl = reflect(vec3(0.0, 0.0, -1.0), tn);
    col = env(refl) * 0.95 + 0.05;

    // Glints: a few tiles flash at a time.
    float g = hash(id + floor(u_time * 6.0));
    col += vec3(1.0) * step(0.985, g) * 1.5;

    // Grout between tiles, and darker edges toward the rim.
    float edge = min(min(f.x, 1.0 - f.x) * cols / rows, min(f.y, 1.0 - f.y));
    col *= mix(0.25, 1.0, smoothstep(0.02, 0.09, edge));
    col *= 0.45 + 0.55 * n.z;
    col *= smoothstep(1.0, 0.985, r);
  } else {
    // The room: dark, with the ball's light spots sweeping across it.
    col = vec3(0.025, 0.02, 0.045) * (1.0 - 0.4 * frag.y / u_size.y);
    col += vec3(0.25, 0.1, 0.35) * 0.18 * exp(-(r - 1.0) * 1.5) * u_party;

    float a = atan(p.y, p.x) + u_spin;
    float ld = log(r) * 9.0;
    vec2 cell = vec2(a / (2.0 * PI) * 70.0, ld);
    vec2 id = floor(cell);
    vec2 f = fract(cell);
    float h = hash(id);
    if (h > 0.45) {
      vec2 at = vec2(hash(id + 1.7), hash(id + 9.2)) * 0.6 + 0.2;
      float sz = 0.16 + 0.1 * hash(id + 4.4);
      float spot = smoothstep(sz, sz * 0.25, length((f - at) * vec2(1.0, 1.6)));
      vec3 sc = mix(vec3(1.0), hue(hash(id + 2.2) + u_time * 0.05), 0.7 * u_party);
      float fall = 1.0 / (1.0 + (r - 1.0) * 0.35);
      col += sc * spot * fall * (0.35 + 0.65 * u_party) * (0.8 + 0.6 * u_beat);
    }
    // The wire the ball hangs from.
    float wire = smoothstep(1.2, 0.0, abs(p.x)) * step(frag.y, c.y - R);
    col += vec3(0.35) * wire;
  }

  col += (hash(frag + fract(u_time)) - 0.5) / 255.0;
  frag_color = vec4(clamp(col, 0.0, 1.0), 1.0);
}
