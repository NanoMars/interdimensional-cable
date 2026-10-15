float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float pattern(vec2 uv, float t)
{
    float rows = uv.x * 200.0 + sin(t * 0.7) * 60.0;
    float row = floor(uv.y * rows);

    float speed = (hash(vec2(row, 1.0)) - 0.5) * 0.6;
    float cols  = mix(6.0, 30.0, hash(vec2(row, 2.0)));

    float x = (uv.x + t * speed) * cols;
    float cell = floor(x);

    float rate = 1.0 + 8.0 * hash(vec2(cell * x, row));
    float tick = floor(t * rate);
    float r = hash(vec2(cell + tick * 13.0, row));

    if (r < 0.35) return 1.0;
    if (r < 0.6)  return fract(tick * 0.37);
    float w = 1.0 + floor(hash(vec2(cell, tick)) * 4.0);
    float stripe = floor(x * iResolution.y / (cols * w * (x + sin(t))));
    return step(0.5, hash(vec2(stripe, row + tick)));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // stuttering clock: sometimes freezes, sometimes skips ahead
    float beat = floor(iTime * 2.0);
    float h = hash(vec2(beat, 4.0));
    float t = iTime;
    if (h < 0.2)      t = beat * 0.5;      // freeze
    else if (h > 0.8) t += h * 10.0;       // skip

    // kaleidoscope: fold the screen into wedges, drag the mouse sideways for more
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    float rad = max(length(p), 0.001);
    float ang = atan(p.y, p.x);
    float wedges = 3.0 + floor(iMouse.x / iResolution.x * 10.0);
    float seg = 6.28318 / wedges;
    ang = abs(mod(ang, seg) - seg * 0.5);

    // tunnel: distance from centre becomes depth, flying forward
    vec2 uv = vec2(ang / (seg * 0.5), fract(0.3 / rad + t * 0.3));

    // wobble, kept from last time
    uv.x += 0.03 * sin(uv.y * 40.0 + t * 3.0);

    // datamosh: random chunks get shoved sideways
    vec2 blk = floor(fragCoord / vec2(80.0, 20.0));
    float glitchTick = floor(t * 4.0);
    float shove = step(0.85, hash(blk * 1.7 + glitchTick));
    uv.x += (hash(blk + glitchTick) - 0.5) * 0.3 * shove;

    // RGB split
    float split = 0.01 + 0.01 * sin(t * 5.0);
    vec3 col = vec3(
        pattern(uv + vec2(split, 0.0), t),
        pattern(uv, t - 0.05),
        pattern(uv - vec2(split, 0.0), t + 0.05)
    );

    // half the colour goes through a drifting rainbow palette
    vec3 rainbow = 0.5 + 0.5 * cos(6.28318 * (col + vec3(0.0, 0.33, 0.67) + t * 0.1));
    col = mix(col, rainbow, 0.5);

    // occasional full-screen invert flash
    if (hash(vec2(beat, 7.0)) > 0.9) col = 1.0 - col;

    // dark edges and scanlines
    col *= 1.0 - rad * 0.8;
    col *= 0.8 + 0.2 * sin(fragCoord.y * 3.0);

    fragColor = vec4(col, 1.0);
}