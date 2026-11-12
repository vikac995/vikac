#version 320 es
// Holographic foil, drawn over a card with a screen blend. The rainbow,
// sparkle and glare all depend on the tilt, so the foil seems to catch light.
precision highp float;

#include <flutter/runtime_effect.glsl>

uniform vec2 u_size;   // card size, logical px
uniform vec2 u_tilt;   // -1 to 1 on each axis
uniform float u_time;
uniform float u_kind;  // 0 prism, 1 starlight, 2 mosaic

out vec4 frag_color;

float hash(vec2 p) {
  p = fract(p * vec2(443.897, 441.423));
  p += dot(p, p + 19.19);
  return fract(p.x * p.y);
}

vec3 hue(float h) {
  return clamp(abs(fract(h + vec3(0.0, 2.0, 1.0) / 3.0) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / u_size;
  vec2 t = u_tilt;
  float tl = clamp(length(t), 0.0, 1.4);

  // Iridescence: bands of colour whose position shifts with the viewing angle.
  float phase = dot(uv - 0.5, vec2(0.9, 1.25)) * 1.6 + t.x * 1.1 - t.y * 0.8 + u_time * 0.02;
  vec3 rainbow = mix(vec3(1.0), hue(phase), 0.85);

  float mask;
  vec3 extra = vec3(0.0);
  if (u_kind < 0.5) {
    // Prism: fine diagonal lines, like a diffraction grating.
    mask = 0.5 + 0.5 * sin((uv.x * 0.9 + uv.y * 1.3) * 260.0);
    mask = 0.35 + 0.65 * mask;
  } else if (u_kind < 1.5) {
    // Starlight: scattered stars that flash at different angles.
    vec2 g = uv * vec2(18.0, 25.0);
    vec2 id = floor(g);
    float h = hash(id);
    // Each star sits at its own spot in its cell, so no grid shows.
    vec2 f = fract(g) - 0.5 - (vec2(hash(id + 1.3), hash(id + 4.1)) - 0.5) * 0.5;
    float flash = pow(max(0.0, sin(h * 40.0 + t.x * 6.0 + t.y * 5.0)), 10.0);
    float star = max(0.0, 1.0 - length(f * vec2(1.0, 7.0)) * 4.2) + max(0.0, 1.0 - length(f * vec2(7.0, 1.0)) * 4.2);
    star += smoothstep(0.1, 0.0, length(f));
    extra = vec3(1.0) * star * flash * step(0.55, h) * 1.4;
    mask = 0.22;
  } else {
    // Mosaic: a grid of rounded cells, each with its own colour offset.
    vec2 g = uv * vec2(10.0, 14.0);
    vec2 id = floor(g);
    vec2 f = fract(g) - 0.5;
    float cell = smoothstep(0.46, 0.38, max(abs(f.x), abs(f.y)));
    rainbow = mix(vec3(1.0), hue(phase + hash(id) * 0.35), 0.9);
    mask = 0.25 + 0.75 * cell;
  }

  // Glare: a soft highlight that moves against the tilt.
  vec2 gp = vec2(0.5) + t * 0.38;
  float glare = exp(-dot((uv - gp) * vec2(1.0, 1.4), (uv - gp) * vec2(1.0, 1.4)) * 7.0);

  // Flat, the foil is a faint sheen; it comes alive as the card tilts.
  vec3 col = rainbow * mask * (0.05 + 0.6 * tl) + extra * (0.25 + tl) + vec3(glare) * (0.12 + 0.4 * tl);
  frag_color = vec4(clamp(col, 0.0, 1.0), 1.0);
}
