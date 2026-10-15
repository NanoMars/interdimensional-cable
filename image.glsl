#define TAU 6.28318

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}
float h1(float seed, float k) { return hash(vec2(seed, k)); }

float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    mat2 m = mat2(1.6, 1.2, -1.2, 1.6);
    for (int i = 0; i < 5; i++) { v += a * noise(p); p = m * p; a *= 0.5; }
    return v;
}

mat2 rot(float a) { float c = cos(a), s = sin(a); return mat2(c, -s, s, c); }

vec2 voronoi(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    float d = 9.0, id = 0.0;
    for (int y = -1; y <= 1; y++)
    for (int x = -1; x <= 1; x++) {
        vec2 g = vec2(x, y);
        vec2 o = vec2(hash(i + g), hash(i + g + 17.0));
        float dd = length(g + o - f);
        if (dd < d) { d = dd; id = hash(i + g + 31.0); }
    }
    return vec2(d, id);
}

float pattern(vec2 uv, float t)
{
    float rows = floor(14.0 + 6.0 * sin(t * 0.7));
    float row = floor(uv.y * rows);
    float speed = (hash(vec2(row, 1.0)) - 0.5) * 0.6;
    float cols  = mix(4.0, 16.0, hash(vec2(row, 2.0)));
    float x = (uv.x + t * speed) * cols;
    float cell = floor(x);
    float tick = floor(t * (1.0 + 4.0 * hash(vec2(cell, row))));
    float r = hash(vec2(cell + tick * 13.0, row));
    if (r < 0.4)  return 1.0;
    if (r < 0.65) return 0.0;
    float w = 1.0 + floor(hash(vec2(cell, tick)) * 4.0);
    float stripe = floor(fract(x) * 48.0 / w);
    return step(0.5, hash(vec2(stripe + cell * 50.0, row + tick)));
}

// ---------- 8 ways to bend space ----------
vec2 warp(vec2 p, float type, float s, float t) {
    float a = h1(s, 1.0), b = h1(s, 2.0);
    if (type < 1.0) return p * (0.5 + 2.0 * a);                                   // zoom
    if (type < 2.0) return vec2(atan(p.y, p.x) / TAU + 0.5, length(p))
                         * vec2(1.0 + floor(a * 5.0), 1.0 + 3.0 * b);              // polar
    if (type < 3.0) { float r = max(length(p), 1e-3);                              // log spiral
        return vec2(atan(p.y, p.x) / TAU * (1.0 + floor(a * 4.0)) + log(r) * (b - 0.5) * 2.0,
                    log(r) - t * 0.3); }
    if (type < 4.0) return p / max(dot(p, p), 0.01) * (0.2 + 0.5 * a);           // inside out
    if (type < 5.0) { p = rot(a * TAU) * p;                                        // tiled
        return fract(p * (2.0 + floor(b * 6.0))) - 0.5; }
    if (type < 6.0) return p + (0.05 + 0.2 * b) * sin(p.yx * (2.0 + 8.0 * a) + t * 2.0); // ripple
    if (type < 7.0) {                                                              // fractal fold
        vec2 k = vec2(0.4 + 0.4 * a, 0.3 + 0.5 * b);
        for (int i = 0; i < 3; i++) {
            p = rot(1.3 + float(i) * (0.5 + a * 2.0) + t * 0.2) * p;
            p.x = abs(p.x);
            p = p / clamp(dot(p, p), 0.3, 2.0) - k;
        }
        return p;
    }
    vec2 q = vec2(fbm(p * 1.5 + t), fbm(p * 1.5 + 5.2 - t));                     // liquid
    return p + (0.5 + 1.5 * a) * (q - 0.5);
}

// ---------- 7 things to fill space with ----------
float fill(vec2 p, float type, float s, float t) {
    float a = h1(s, 3.0), b = h1(s, 4.0);
    if (type < 1.0) return pattern(p * 0.5 + 0.5, t);                              // barcode
    if (type < 2.0) return step(0.5, fract(fbm(p * (1.0 + 2.0 * a) + t * 0.3) * (4.0 + 12.0 * b))); // contours
    if (type < 3.0) { vec2 v = voronoi(p * (2.0 + 6.0 * a) + t * 0.3);             // cells
        return b < 0.5 ? smoothstep(0.05, 0.4, v.x) : v.y; }
    if (type < 4.0) return 0.5 + 0.5 * sin(length(p) * (10.0 + 40.0 * a) - t * (2.0 + 6.0 * b)); // rings
    if (type < 5.0) return step(0.45 + 0.1 * sin(t), noise(p * (3.0 + 20.0 * a) + t));            // blobs
    if (type < 6.0) return 0.5 + 0.5 * sin(p.x * (5.0 + 30.0 * a) + t) * sin(p.y * (5.0 + 30.0 * b) - t * 1.3); // interference
    return fbm(p * (1.0 + 3.0 * a) + t * 0.2);                                     // fog
}

vec3 harsh(float i) {
    i = mod(floor(i), 6.0);
    if (i < 1.0) return vec3(0.0);
    if (i < 2.0) return vec3(1.0);
    if (i < 3.0) return vec3(1.0, 0.05, 0.1);
    if (i < 4.0) return vec3(0.1, 0.2, 1.0);
    if (i < 5.0) return vec3(0.6, 1.0, 0.0);
    return vec3(1.0, 0.3, 0.8);
}

// ---------- 5 ways to colour it ----------
vec3 colourise(float v, float type, float s, vec2 p) {
    if (type < 1.0) { float ia = floor(h1(s, 5.0) * 37.0);                         // two clashing colours
        return mix(harsh(ia), harsh(ia + 1.0 + floor(h1(s, 6.0) * 5.0)), v); }
    if (type < 2.0) { vec3 d = vec3(h1(s, 10.0), h1(s, 11.0), h1(s, 12.0));        // random gradient
        return 0.5 + 0.5 * cos(TAU * (v * (0.5 + 2.0 * h1(s, 7.0)) + d)); }
    if (type < 3.0) { float lv = 2.0 + floor(h1(s, 13.0) * 4.0);                   // posterised mono
        return vec3(floor(v * lv) / (lv - 1.0)) * mix(vec3(1.0), vec3(1.0, 0.9, 0.75), h1(s, 14.0)); }
    if (type < 4.0) return vec3(v, fract(v * 3.0 + p.x), fract(v * 7.0 - p.y));    // channel scramble
    return vec3(1.0 - v) * vec3(0.9, 0.82, 0.72) + vec3(0.2, 0.9, 0.7) * pow(v, 8.0); // bone negative
}

vec3 scene(vec2 p, float s, float time) {
    // how time behaves in this scene
    float tm = h1(s, 20.0);
    float t = tm < 0.15 ? 0.0                              // frozen
            : tm < 0.3  ? -time                            // backwards
            : tm < 0.45 ? time * 4.0                       // fast
            : tm < 0.55 ? floor(time * 6.0) / 2.0          // jerky
            : time;

    vec2 q = warp(p, floor(h1(s, 21.0) * 8.0), s, t);
    if (h1(s, 23.0) > 0.4) q = warp(q, floor(h1(s, 22.0) * 8.0), s + 7.0, t); // sometimes chain two
    float v = clamp(fill(q, floor(h1(s, 24.0) * 7.0), s, t), 0.0, 1.0);
    return colourise(v, floor(h1(s, 25.0) * 5.0), s, q);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    // a clock that speeds up and slows down unevenly, so cuts never fall into a rhythm
    float clock = iTime * 0.7 + 0.5 * sin(iTime * 0.37) + 0.35 * sin(iTime * 1.13) + 0.03 * sin(iTime * 2.9);
    float seg = floor(clock);
    float local = fract(clock);

    vec3 oldCol = scene(p, seg - 1.0, iTime);
    vec3 newCol = scene(p, seg, iTime);

    // 5 ways for the next scene to arrive
    float tt = h1(seg, 30.0);
    float prog = clamp(local * (1.0 + 9.0 * h1(seg, 31.0)), 0.0, 1.0);
    float m;
    if (tt < 0.25) m = 1.0;                                                        // hard cut
    else if (tt < 0.45) m = step(fbm(p * 3.0 + seg), prog);                        // dissolves through noise
    else if (tt < 0.6) {                                                           // grows from a random point
        vec2 c = vec2(h1(seg, 32.0), h1(seg, 33.0)) - 0.5;
        m = step(length(p - c) + 0.1 * noise(p * 10.0), prog * 1.5);
    }
    else if (tt < 0.75) m = step(hash(floor(fragCoord / (4.0 + 28.0 * h1(seg, 34.0))) + seg), prog); // block decay
    else m = step(1.0 - prog, dot(oldCol, vec3(0.333)));                            // infection: brightest parts turn first

    vec3 col = mix(oldCol, newCol, m);

    // tiny unpredictable events
    float micro = floor(iTime * 7.0);
    if (h1(micro, 40.0) > 0.93) col = abs(newCol - oldCol);   // the two scenes collide
    if (h1(micro, 41.0) > 0.96) col = col.gbr;                // colour channels swap

    fragColor = vec4(col, 1.0);
}