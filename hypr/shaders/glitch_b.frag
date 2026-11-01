#version 320 es
// Kuber — glitch burst, frame B. See glitch_a.frag for the scheme and why
// it's static. Different band count / offsets from frame A so alternating
// between the two reads as noise rather than a single repeating pattern,
// plus a couple of bright tear lines for a harder pop mid-burst.

precision highp float;

in  vec2 v_texcoord;
uniform sampler2D tex;
layout(location = 0) out vec4 fragColor;

float hash(float n) { return fract(sin(n) * 110.345); }

void main() {
    vec2 uv = v_texcoord;

    float band = floor(uv.y * 19.0);
    float jitter = (hash(band * 3.17 + 5.0) - 0.5) * 0.07;
    if (hash(band * 9.11) > 0.78) jitter *= -3.0;
    vec2 suv = vec2(clamp(uv.x + jitter, 0.0, 1.0), uv.y);

    const float split = 0.010;
    float r = texture(tex, clamp(suv - vec2(split, 0.0), 0.0, 1.0)).r;
    float g = texture(tex, suv).g;
    float b = texture(tex, clamp(suv + vec2(split, 0.0), 0.0, 1.0)).b;
    vec3 col = vec3(r, g, b);

    float line = step(0.985, hash(band * 1.91));
    col += vec3(0.9, 0.95, 1.0) * line * 0.5;

    fragColor = vec4(col, 1.0);
}
