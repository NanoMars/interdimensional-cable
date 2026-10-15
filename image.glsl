#define TAU 6.28318
#define PI  3.14159

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

vec2 warp(vec2 p, float type, float s, float t) {
    float a = h1(s, 1.0), b = h1(s, 2.0);
    if (type < 1.0) return p * (0.5 + 2.0 * a);
    if (type < 2.0) return vec2(atan(p.y, p.x) / TAU + 0.5, length(p))
                         * vec2(1.0 + floor(a * 5.0), 1.0 + 3.0 * b);
    if (type < 3.0) { float r = max(length(p), 1e-3);
        return vec2(atan(p.y, p.x) / TAU * (1.0 + floor(a * 4.0)) + log(r) * (b - 0.5) * 2.0,
                    log(r) - t * 0.3); }
    if (type < 4.0) return p / max(dot(p, p), 0.01) * (0.2 + 0.5 * a);
    if (type < 5.0) { p = rot(a * TAU) * p;
        return fract(p * (2.0 + floor(b * 6.0))) - 0.5; }
    if (type < 6.0) return p + (0.05 + 0.2 * b) * sin(p.yx * (2.0 + 8.0 * a) + t * 2.0);
    if (type < 7.0) {
        vec2 k = vec2(0.4 + 0.4 * a, 0.3 + 0.5 * b);
        for (int i = 0; i < 3; i++) {
            p = rot(1.3 + float(i) * (0.5 + a * 2.0) + t * 0.2) * p;
            p.x = abs(p.x);
            p = p / clamp(dot(p, p), 0.3, 2.0) - k;
        }
        return p;
    }
    vec2 q = vec2(fbm(p * 1.5 + t), fbm(p * 1.5 + 5.2 - t));
    return p + (0.5 + 1.5 * a) * (q - 0.5);
}

// second warp slot, which is sometimes switched off
vec2 warpMaybe(vec2 p, float s, float t) {
    if (h1(s, 23.0) < 0.4) return p;
    return warp(p, floor(h1(s, 22.0) * 8.0), s + 7.0, t);
}

float fill(vec2 p, float type, float s, float t) {
    float a = h1(s, 3.0), b = h1(s, 4.0);
    if (type < 1.0) return pattern(p * 0.5 + 0.5, t);
    if (type < 2.0) return step(0.5, fract(fbm(p * (1.0 + 2.0 * a) + t * 0.3) * (4.0 + 12.0 * b)));
    if (type < 3.0) { vec2 v = voronoi(p * (2.0 + 6.0 * a) + t * 0.3);
        return b < 0.5 ? smoothstep(0.05, 0.4, v.x) : v.y; }
    if (type < 4.0) return 0.5 + 0.5 * sin(length(p) * (10.0 + 40.0 * a) - t * (2.0 + 6.0 * b));
    if (type < 5.0) return step(0.45 + 0.1 * sin(t), noise(p * (3.0 + 20.0 * a) + t));
    if (type < 6.0) return 0.5 + 0.5 * sin(p.x * (5.0 + 30.0 * a) + t) * sin(p.y * (5.0 + 30.0 * b) - t * 1.3);
    return fbm(p * (1.0 + 3.0 * a) + t * 0.2);
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

vec3 colourise(float v, float type, float s, vec2 p) {
    if (type < 1.0) { float ia = floor(h1(s, 5.0) * 37.0);
        return mix(harsh(ia), harsh(ia + 1.0 + floor(h1(s, 6.0) * 5.0)), v); }
    if (type < 2.0) { vec3 d = vec3(h1(s, 10.0), h1(s, 11.0), h1(s, 12.0));
        return 0.5 + 0.5 * cos(TAU * (v * (0.5 + 2.0 * h1(s, 7.0)) + d)); }
    if (type < 3.0) { float lv = 2.0 + floor(h1(s, 13.0) * 4.0);
        return vec3(floor(v * lv) / (lv - 1.0)) * mix(vec3(1.0), vec3(1.0, 0.9, 0.75), h1(s, 14.0)); }
    if (type < 4.0) return vec3(v, fract(v * 3.0 + p.x), fract(v * 7.0 - p.y));
    return vec3(1.0 - v) * vec3(0.9, 0.82, 0.72) + vec3(0.2, 0.9, 0.7) * pow(v, 8.0);
}

float timeMode(float s) {
    float tm = h1(s, 20.0);
    if (tm < 0.15) return h1(s, 26.0) * 100.0;   // frozen at a random moment
    if (tm < 0.3)  return -iTime;                // backwards
    if (tm < 0.45) return iTime * 4.0;           // fast
    if (tm < 0.55) return floor(iTime * 6.0) / 2.0; // jerky
    return iTime;
}

// One gene: returns (old seed, new seed, how far the change has got at this pixel)
vec3 gene(float id, vec2 p) {
    // its own lopsided clock, which can even stall or slip backwards
    float rate = 0.15 + 0.4 * hash(vec2(id, 99.0));
    float c = iTime * rate
            + 0.6 * sin(iTime * (0.21 + 0.07 * id) + id * 2.3)
            + 0.3 * sin(iTime * (0.77 + 0.11 * id) + id * 5.1);
    float seg = floor(c), f = fract(c);
    float key = seg + id * 100.0;

    // every change has its own timing: some snap, some take ages
    float start = 0.7 * h1(key, 1.0);
    float len = mix(0.02, 1.0 - start, h1(key, 2.0));
    float w = smoothstep(start, start + len, f);

    // and it creeps across the screen instead of happening everywhere at once
    float spread = 2.0 * h1(key, 3.0);
    float n = noise(p * (1.0 + 4.0 * h1(key, 4.0)) + seg + iTime * 0.1);
    w = clamp(w * (1.0 + spread) - spread * n, 0.0, 1.0);

    return vec3(key - 1.0, key, w);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 sp = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    // gene 5: zoom and rotation of the whole thing
    vec3 gz = gene(5.0, sp);
    float zoom = mix(exp2(h1(gz.x, 50.0) * 3.0 - 1.5), exp2(h1(gz.y, 50.0) * 3.0 - 1.5), gz.z);
    float ang  = mix(h1(gz.x, 51.0) * TAU, h1(gz.y, 51.0) * TAU, gz.z);
    vec2 p = rot(ang) * sp * zoom;

    // gene 4: how time behaves
    vec3 gt = gene(4.0, sp);
    float t = mix(timeMode(gt.x), timeMode(gt.y), gt.z);

    // gene 0: first warp. Halfway through a change, the two warps get multiplied together
    vec3 g0 = gene(0.0, sp);
    vec2 qa = warp(p, floor(h1(g0.x, 21.0) * 8.0), g0.x, t);
    vec2 qb = warp(p, floor(h1(g0.y, 21.0) * 8.0), g0.y, t);
    vec2 q = mix(qa, qb, g0.z) + sin(PI * g0.z) * h1(g0.y, 60.0) * qa * qb;

    // gene 1: optional second warp
    vec3 g1 = gene(1.0, sp);
    q = mix(warpMaybe(q, g1.x, t), warpMaybe(q, g1.y, t), g1.z);

    // gene 2: what fills space. Halfway states wrap around into something new
    vec3 g2 = gene(2.0, sp);
    float va = clamp(fill(q, floor(h1(g2.x, 24.0) * 7.0), g2.x, t), 0.0, 1.0);
    float vb = clamp(fill(q, floor(h1(g2.y, 24.0) * 7.0), g2.y, t), 0.0, 1.0);
    float v = mix(va, vb, g2.z);
    v = mix(v, fract(va + vb + t * 0.1), sin(PI * g2.z) * h1(g2.y, 61.0));

    // gene 3: colour
    vec3 g3 = gene(3.0, sp);
    vec3 col = mix(colourise(v, floor(h1(g3.x, 25.0) * 5.0), g3.x, q),
                   colourise(v, floor(h1(g3.y, 25.0) * 5.0), g3.y, q), g3.z);

    fragColor = vec4(col, 1.0);
}