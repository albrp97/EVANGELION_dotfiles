float roundedBox(vec2 point, vec2 center, vec2 halfSize, float radius) {
    vec2 q = abs(point - center) - halfSize + radius;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

float lineDistance(vec2 point, vec2 start, vec2 end) {
    vec2 segment = end - start;
    float denom = max(dot(segment, segment), 0.001);
    float t = clamp(dot(point - start, segment) / denom, 0.0, 1.0);
    return length(point - (start + segment * t));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 terminal = texture(iChannel0, uv);

    if (iCursorVisible == 0) {
        fragColor = terminal;
        return;
    }

    vec2 currentCenter = iCurrentCursor.xy + iCurrentCursor.zw * 0.5;
    vec2 previousCenter = iPreviousCursor.xy + iPreviousCursor.zw * 0.5;
    float age = max(iTime - iTimeCursorChange, 0.0);
    float fade = exp(-age * 4.64);
    float moved = smoothstep(1.0, 8.0, length(currentCenter - previousCenter));

    vec3 evaOrange = vec3(0.965, 0.757, 0.467);

    float trailWidth = max(max(iCurrentCursor.z, iCurrentCursor.w) * 0.72, 10.0);
    float trail = 1.0 - smoothstep(
        trailWidth * 0.15,
        trailWidth,
        lineDistance(fragCoord, previousCenter, currentCenter)
    );
    trail *= fade * moved * 0.55;

    vec2 halfCursor = max(iCurrentCursor.zw * 0.5, vec2(5.0));
    float glowDistance = roundedBox(
        fragCoord,
        currentCenter,
        halfCursor + vec2(6.0),
        6.0
    );
    float glow = (1.0 - smoothstep(0.0, 18.0, glowDistance)) * 0.25;

    vec3 color = terminal.rgb;
    color = mix(color, evaOrange, trail);
    color += evaOrange * glow;

    fragColor = vec4(color, terminal.a);
}
