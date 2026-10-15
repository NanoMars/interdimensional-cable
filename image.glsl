float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float pattern(vec2 uv, float t)
{
    // chunky rows that still breathe a bit
    float rows = floor(14.0 + 6.0 * sin(t * 0.7));
    float row = floor(uv.y * rows);

    float speed = (hash(vec2(row, 1.0)) - 0.5) * 0.6;
    float cols  = mix(4.0, 16.0, hash(vec2(row, 2.0)));

    float x = (uv.x + t * speed) * cols;
    float cell = floor(x);

    float rate = 1.0 + 4.0 * hash(vec2(cell, row));
    float tick = floor(t * rate);
    float r = hash(vec2(cell + tick * 13.0, row));

    if (r < 0.4)  return 1.0;   // white
    if (r < 0.65) return 0.0;   // black

    // barcode: 12 to 48 stripes inside each block
    float w = 1.0 + floor(hash(vec2(cell, tick)) * 4.0);
    float stripe = floor(fract(x) * 48.0 / w);
    return step(0.5, hash(vec2(stripe + cell * 50.0, row + tick)));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // stuttering clock
    float beat = floor(iTime * 2.0);
    float h = hash(vec2(beat, 4.0));
    float t = iTime;
    if (h < 0.2)      t = beat * 0.5;
    else if (h > 0.8) t += h * 10.0;

    // kaleidoscope, mouse x controls wedge count
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    float rad = max(length(p), 0.001);
    float ang = atan(p.y, p.x);
    float wedges = 3.0 + floor(iMouse.x / iResolution.x * 10.0);
    float seg = 6.28318 / wedges;
    ang = abs(mod(ang, seg) - seg * 0.5);

    // gentler tunnel so the pattern isn't crushed
    vec2 uv = vec2(ang / (seg * 0.5), fract(0.15 / rad + t * 0.2));

    uv.x += 0.02 * sin(uv.y * 20.0 + t * 3.0);

    // datamosh, but rarer
    vec2 blk = floor(fragCoord / vec2(80.0, 20.0));
    float glitchTick = floor(t * 4.0);
    float shove = step(0.93, hash(blk * 1.7 + glitchTick));
    uv.x += (hash(blk + glitchTick) - 0.5) * 0.3 * shove;

    // small RGB split so it fringes the edges instead of scrambling everything
    float split = 0.004;
    vec3 col = vec3(
        pattern(uv + vec2(split, 0.0), t),
        pattern(uv, t),
        pattern(uv - vec2(split, 0.0), t)
    );

    // rainbow as a tint on top, so black stays black and white stays bright
    vec3 tint = 0.6 + 0.4 * cos(6.28318 * (rad + t * 0.1 + vec3(0.0, 0.33, 0.67)));
    col *= tint;

    if (hash(vec2(beat, 7.0)) > 0.9) col = 1.0 - col;

    col *= 1.0 - rad * 0.6;
    col *= 0.92 + 0.08 * sin(fragCoord.y * 1.5);

    fragColor = vec4(col, 1.0);
}