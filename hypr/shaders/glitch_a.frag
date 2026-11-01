#version 320 es
// Kuber — glitch burst, frame A. One of three shaders flashed briefly by
// hypr/scripts/glitch.sh (hyprctl keyword screen_shader swap) just before a
// HUD element opens (rofi, window switcher, security panel) — a signal-tear
// punctuation, not an ambient effect.
//
// Static — no `time` uniform. The flicker comes entirely from the script
// swapping which shader is bound across ~90ms, not from anything animated
// within a single shader, so damage tracking stays on and this costs a
// handful of one-off full redraws, not a sustained per-frame one.

precision highp float;

in  vec2 v_texcoord;
uniform sampler2D tex;
layout(location = 0) out vec4 fragColor;

float hash(float n) { return fract(sin(n) * 43758.5453123); }

void main() {
    vec2 uv = v_texcoord;

    // coarse horizontal bands, each torn sideways by a hashed offset
    float band = floor(uv.y * 28.0);
    float jitter = (hash(band * 13.37) - 0.5) * 0.045;
    if (hash(band * 7.77) > 0.82) jitter *= 4.0;  // a few bands tear hard
    vec2 suv = vec2(clamp(uv.x + jitter, 0.0, 1.0), uv.y);

    // exaggerated chromatic split while glitching
    const float split = 0.006;
    float r = texture(tex, clamp(suv + vec2(split, 0.0), 0.0, 1.0)).r;
    float g = texture(tex, suv).g;
    float b = texture(tex, clamp(suv - vec2(split, 0.0), 0.0, 1.0)).b;

    fragColor = vec4(r, g, b, 1.0);
}
