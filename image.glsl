float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    mat2 m = mat2(1.6, 1.2, -1.2, 1.6);
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p = m * p;
        a *= 0.5;
    }
    return v;
}

mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

float pattern(vec2 uv, float t)
{
    float rows = floor(14.0 + 6.0 * sin(t * 0.7));
    float row = floor(uv.y * rows);

    float speed = (hash(vec2(row, 1.0)) - 0.5) * 0.6;
    float cols  = mix(4.0, 16.0, hash(vec2(row, 2.0)));

    float x = (uv.x + t * speed) * cols;
    float cell = floor(x);

    float rate = 1.0 + 4.0 * hash(vec2(cell, row));
    float tick = floor(t * rate);
    float r = hash(vec2(cell + tick * 13.0, row));

    if (r < 0.4)  return 1.0;
    if (r < 0.65) return 0.0;

    float w = 1.0 + floor(hash(vec2(cell, tick)) * 4.0);
    float stripe = floor(fract(x) * 48.0 / w);
    return step(0.5, hash(vec2(stripe + cell * 50.0, row + tick)));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    float t = iTime * 0.3;
    float breath = 0.5 + 0.5 * sin(iTime * 0.7);

    // the origin wanders, so there's no fixed centre
    p += 0.3 * vec2(sin(t * 0.37), cos(t * 0.29));

    // bend space before folding, so even the fold lines are crooked
    p += 0.3 * (vec2(fbm(p * 2.0 + t), fbm(p * 2.0 - t + 3.1)) - 0.5);

    vec2 k = vec2(0.55 + 0.1 * sin(t * 0.7), 0.45 + 0.1 * cos(t * 0.53));
    vec2 z = p * (1.2 + 0.4 * breath);
    float trap = 1e9;
    for (int i = 0; i < 3; i++) {
        // a different twist before each fold, so the mirrors never line up
        z = rot(1.1 + 0.7 * float(i) + t * 0.2) * z;
        // fold only one axis
        z.x = abs(z.x);
        // clamped, so it doesn't shatter into static
        z = z / clamp(dot(z, z), 0.3, 2.0) - k;
        trap = min(trap, length(z));
    }

    // only some patches get the fractal, the rest stay smooth and raw
    float mask = smoothstep(0.35, 0.65, fbm(p * 1.5 + t * 0.5));
    vec2 s = mix(p * 2.0, z, mask) * 0.5;

    vec2 q = vec2(fbm(s + t), fbm(s + vec2(5.2, 1.3) - t));
    vec2 r = vec2(fbm(s + 4.0 * q + vec2(1.7, 9.2) + t * 0.5),
                  fbm(s + 4.0 * q + vec2(8.3, 2.8)));
    float f = fbm(s + 4.0 * r);

    float c = pattern(r * 1.5 + f * 0.5, iTime * 0.5 + f * 4.0);

    vec3 col = mix(vec3(0.04, 0.02, 0.03), vec3(0.9, 0.82, 0.72), c);
    col *= 0.4 + 0.8 * f;

    float fold = clamp(length(q - r) * 1.5, 0.0, 1.0);
    col += vec3(0.2, 0.9, 0.7) * pow(fold, 3.0);

    col += exp(-trap * 6.0) * vec3(1.0, 0.25, 0.05) * 0.6 * mask;

    col *= 0.85 + 0.15 * sin(f * 20.0 - iTime * 2.0);

    fragColor = vec4(col, 1.0);
}