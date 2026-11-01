#version 320 es
// Kuber — cyber-HUD screen shader.
// Wired in via decoration:screen_shader in hypr/look.lua.
//
// GLES 3.20, matching Hyprland 0.56's vertex-shader pairing (see Skemos's
// skemos.frag for why the #version line must be first and exact — a
// versionless shader defaults to GLSL ES 1.00 and fails to link on the
// strict Mesa path, i.e. boots where the AMD iGPU wins the primary-GPU race).
//
// Static — no `time` uniform, so debug:damage_tracking stays ON and this
// costs nothing per-frame (the lesson from Skemos's animated-shader attempt:
// a time-varying shader forces Hyprland to redraw the whole screen every
// frame regardless of whether anything changed). Three distance-from-centre
// effects, so it reads as looking through a display pane, not a filter
// slapped on the desktop:
//   - chromatic aberration: R/B channels sample slightly offset, growing
//     toward the edges — HUD-glass colour fringing.
//   - scanlines: a faint horizontal raster (same formula as Skemos's, which
//     is confirmed to render correctly on this machine).
//   - edge fresnel: the outer rim of the screen picks up a hairline of
//     corp red, like a bezel catching light.

precision highp float;

in  vec2 v_texcoord;
uniform sampler2D tex;
layout(location = 0) out vec4 fragColor;

const float ABERRATION  = 0.0020;  // max channel offset at the edge
const float SCANLINE    = 0.035;   // horizontal raster strength
const float FRESNEL     = 0.12;    // edge-glow strength
const vec3  FRESNEL_COL = vec3(0.784, 0.118, 0.173); // #c81e2c, corp red

void main() {
    vec2 uv  = v_texcoord;
    vec2 ctr = uv - 0.5;
    float d  = length(ctr);

    vec2 dir = d > 0.0001 ? ctr / d : vec2(0.0);
    vec2 off = dir * d * d * ABERRATION;

    float r = texture(tex, uv - off).r;
    float g = texture(tex, uv).g;
    float b = texture(tex, uv + off).b;
    vec3 col = vec3(r, g, b);

    float p = gl_FragCoord.y;
    col *= 1.0 - SCANLINE * (0.5 - 0.5 * cos(p * 2.0943951));  // ~3px period

    float edge = smoothstep(0.35, 0.5, d);
    col += FRESNEL_COL * edge * FRESNEL;

    fragColor = vec4(col, 1.0);
}
