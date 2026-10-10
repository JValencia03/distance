// Slowly drifting pastel glows over the background color, plus a faint
// paper grain. Used behind the home screen by AuroraBackground.
#version 460 core

#include <flutter/runtime_effect.glsl>

// Uniform order matters: AuroraBackground sets them by index.
uniform vec2 uSize;      // 0, 1: canvas size in logical pixels
uniform float uTime;     // 2: seconds since the animation started
uniform vec3 uBase;      // 3-5: background color
uniform vec3 uGlowA;     // 6-8: top right glow (peach)
uniform vec3 uGlowB;     // 9-11: left glow (lavender)
uniform vec3 uGlowC;     // 12-14: bottom glow (mint)
uniform float uStrength; // 15: glow opacity, lower in dark mode

out vec4 fragColor;

// 1 at the center of a glow, fading smoothly to 0 at its radius.
float glow(vec2 p, vec2 center, float radius) {
  float d = length(p - center) / radius;
  return smoothstep(1.0, 0.0, d);
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / uSize;
  // Distances in units of the screen height, so glows stay round.
  float aspect = uSize.x / uSize.y;
  vec2 p = vec2(uv.x * aspect, uv.y);
  float t = uTime * 0.18;

  vec2 a = vec2(aspect * (0.88 + 0.10 * sin(t * 1.3)), 0.06 + 0.05 * cos(t));
  vec2 b = vec2(aspect * (0.05 + 0.12 * cos(t * 0.9)), 0.30 + 0.07 * sin(t * 1.1));
  vec2 c = vec2(aspect * (0.65 + 0.20 * sin(t * 0.7 + 1.0)), 0.92 + 0.05 * cos(t * 0.8));

  vec3 color = uBase;
  color = mix(color, uGlowA, glow(p, a, 0.55) * uStrength);
  color = mix(color, uGlowB, glow(p, b, 0.60) * uStrength);
  color = mix(color, uGlowC, glow(p, c, 0.50) * uStrength * 0.8);

  // Static per-pixel noise, like the grain of paper.
  float noise = fract(sin(dot(frag, vec2(12.9898, 78.233))) * 43758.5453);
  color += (noise - 0.5) * 0.02;

  fragColor = vec4(color, 1.0);
}
