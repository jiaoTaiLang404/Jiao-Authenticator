
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uBend;
uniform sampler2D uBackdrop;
out vec4 fragColor;

vec4 readBackdrop(vec2 uv) {
  // Flutter 3.47+ uses top-down render targets on all Impeller backends.
  return texture(uBackdrop, clamp(uv, vec2(0.0), vec2(1.0)));
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec2 pixel = 1.0 / uSize;
  vec2 center = uv - vec2(0.5);
  vec2 edgeDistance = min(uv, 1.0 - uv) * uSize;
  float rim = 1.0 - smoothstep(0.0, 0.24 * min(uSize.x, uSize.y),
      min(edgeDistance.x, edgeDistance.y));
  uv -= center * pixel * uBend * rim;
  vec2 d = pixel * 3.0;
  fragColor = readBackdrop(uv) * 0.24
    + (readBackdrop(uv + vec2(d.x, 0.0)) + readBackdrop(uv - vec2(d.x, 0.0))
    + readBackdrop(uv + vec2(0.0, d.y)) + readBackdrop(uv - vec2(0.0, d.y))) * 0.13
    + (readBackdrop(uv + d) + readBackdrop(uv - d)
    + readBackdrop(uv + vec2(d.x, -d.y)) + readBackdrop(uv + vec2(-d.x, d.y))) * 0.06;
}
