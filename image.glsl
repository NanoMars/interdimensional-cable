float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// harsh limited palette instead of a smooth rainbow
vec3 palette(float i) {
    i = mod(floor(i), 6.0);
    if (i < 1.0) return vec3(0.0);
    if (i < 2.0) return vec3(1.0);
    if (i < 3.0) return vec3(1.0, 0.05, 0.1);   // acid red
    if (i < 4.0) return vec3(0.1, 0.2, 1.0);    // electric blue
    if (i < 5.0) return vec3(0.6, 1.0, 0.0);    // toxic green
    return vec3(1.0, 0.3, 0.8);                 // hot pink
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
    // stuttering clock
    float beat = floor(iTime * 2.0);
    float h = hash(vec2(beat, 4.0));
    float t = iTime;
    if (h < 0.2)      t = beat * 0.5;
    else if (h > 0.8) t += h * 10.0;

    vec2 sc = fragCoord / iResolution.xy;

    // collage grid that changes shape every beat
    vec2 grid = vec2(2.0 + floor(hash(vec2(beat, 1.0)) * 3.0),
                     1.0 + floor(hash(vec2(beat, 2.0)) * 3.0));
    vec2 tileId = floor(sc * grid);
    vec2 local  = fract(sc * grid);
    float tileSeed = hash(tileId + beat * 3.1);
    float mode = floor(tileSeed * 4.0);

    // centred coords inside the tile, corrected for its shape
    float tileAspect = (iResolution.x / grid.x) / (iResolution.y / grid.y);
    vec2 p = (local - 0.5) * vec2(tileAspect, 1.0);

    vec2 uv;
    float tt = t;
    if (mode < 1.0) {
        // flat barcode wall
        uv = local;
    } else if (mode < 2.0) {
        // tunnel whose centre wanders around
        vec2 q = p - 0.25 * vec2(sin(t * 1.3), cos(t * 0.9));
        float rad = max(length(q), 0.001);
        uv = vec2(atan(q.y, q.x) / 6.28318 + 0.5, fract(0.15 / rad + t * 0.3));
    } else if (mode < 3.0) {
        // log spiral
        float rad = max(length(p), 0.001);
        uv = vec2(fract(atan(p.y, p.x) / 6.28318 * 3.0 + log(rad) * 0.8 - t * 0.2),
                  fract(rad * 2.0));
    } else {
        // slit-scan: each row of the tile lives at a different moment in time
        uv = local;
        tt = t - local.y * 3.0;
    }

    // melting columns that drip downwards
    float colId = floor(fragCoord.x / 6.0);
    float drip = step(0.8, hash(vec2(colId, floor(t * 2.0))));
    uv.y += drip * hash(vec2(colId, 3.0)) * 0.4 * fract(t * 2.0);

    // two clashing colours per tile, never the same one twice
    float ia = floor(tileSeed * 37.0);
    float ib = ia + 1.0 + floor(hash(tileId + 5.0) * 5.0);
    float c = pattern(uv, tt);
    vec3 col = mix(palette(ia), palette(ib), c);

    // misprint: an offset ghost of the pattern knocks out some of the colour
    float ghost = pattern(uv + vec2(0.015, 0.0), tt - 0.1);
    col = abs(col - ghost * vec3(0.0, 0.6, 0.6));

    // black gutters between tiles
    vec2 edge = min(local, 1.0 - local) * iResolution.xy / grid;
    col *= step(3.0, min(edge.x, edge.y));

    if (hash(vec2(beat, 7.0)) > 0.9) col = 1.0 - col;
    col *= 0.92 + 0.08 * sin(fragCoord.y * 1.5);

    fragColor = vec4(col, 1.0);
}