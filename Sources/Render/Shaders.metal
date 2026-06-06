#include <metal_stdlib>
using namespace metal;

struct VoxelVertex {
    float3 position;
    float3 normal;
    float4 color;
};

struct Uniforms {
    float4x4 viewProjection;
    float4   cameraPos;    // xyz
    float4   sunDir;       // xyz = направление НА солнце
    float4   sunColor;     // rgb
    float4   skyColor;     // rgb, w = fogDensity
    float4   params;       // x = time
};

struct VOut {
    float4 position [[position]];
    float4 color;
    float3 normal;
    float3 worldPos;
};

vertex VOut voxel_vertex(const device VoxelVertex *verts [[buffer(0)]],
                         constant Uniforms &u [[buffer(1)]],
                         uint vid [[vertex_id]]) {
    VOut out;
    float4 worldPos = float4(verts[vid].position, 1.0);
    out.position = u.viewProjection * worldPos;
    out.color = verts[vid].color;
    out.normal = verts[vid].normal;
    out.worldPos = verts[vid].position;
    return out;
}

fragment float4 voxel_fragment(VOut in [[stage_in]], constant Uniforms &u [[buffer(1)]]) {
    float3 N = normalize(in.normal);
    float3 L = normalize(u.sunDir.xyz);

    // Диффузное освещение от солнца (Lambert) + мягкий амбиент неба.
    float diffuse = max(dot(N, L), 0.0);
    float ambient = 0.45;
    // Небо подсвечивает верхние грани чуть холоднее.
    float skyTerm = 0.15 * clamp(N.y * 0.5 + 0.5, 0.0, 1.0);

    float3 lit = in.color.rgb * (ambient + skyTerm + diffuse * u.sunColor.rgb);

    // Туман по расстоянию до камеры (экспоненциальный).
    float dist = length(in.worldPos - u.cameraPos.xyz);
    float fogDensity = u.skyColor.w;
    float fog = 1.0 - exp(-fogDensity * dist);
    fog = clamp(fog, 0.0, 1.0);
    float3 finalColor = mix(lit, u.skyColor.rgb, fog);

    return float4(finalColor, in.color.a);
}

// ----- Небо: полноэкранный градиент + диск солнца -----
struct SkyOut {
    float4 position [[position]];
    float2 uv;
};

vertex SkyOut sky_vertex(uint vid [[vertex_id]]) {
    // Полноэкранный треугольник.
    float2 p[3] = { float2(-1.0, -1.0), float2(3.0, -1.0), float2(-1.0, 3.0) };
    SkyOut o;
    o.position = float4(p[vid], 0.999999, 1.0);  // на дальней плоскости
    o.uv = p[vid] * 0.5 + 0.5;
    return o;
}

fragment float4 sky_fragment(SkyOut in [[stage_in]], constant Uniforms &u [[buffer(1)]]) {
    // Вертикальный градиент неба.
    float t = clamp(in.uv.y, 0.0, 1.0);
    float3 horizon = float3(0.78, 0.86, 0.95);
    float3 zenith  = float3(0.25, 0.50, 0.85);
    float3 sky = mix(horizon, zenith, t);

    // Положение солнца в clip-space (через направление взгляда нельзя,
    // поэтому рисуем по экранной проекции направления солнца).
    float4 sunClip = u.viewProjection * float4(u.cameraPos.xyz + u.sunDir.xyz * 300.0, 1.0);
    float2 sunNdc = sunClip.xy / max(sunClip.w, 0.0001);
    float2 sunScreen = sunNdc * 0.5 + 0.5;

    float2 d = in.uv - sunScreen;
    float r = length(d);
    // Диск + мягкое гало.
    float disk = smoothstep(0.06, 0.045, r);
    float halo = exp(-r * 9.0) * 0.6;
    float3 sunGlow = u.sunColor.rgb * (disk + halo);

    // Если солнце за камерой (w<0), не рисуем.
    float visible = step(0.0, sunClip.w);
    float3 result = sky + sunGlow * visible;
    return float4(result, 1.0);
}

// ----- Цветная геометрия (животные, выделение) с простым освещением -----
struct EntityVertex {
    float3 position;
    float3 normal;
};

struct EntityOut {
    float4 position [[position]];
    float3 normal;
};

struct EntityUniforms {
    float4x4 mvp;
    float4   color;
    float4   sunDir;   // xyz
};

vertex EntityOut entity_vertex(const device EntityVertex *verts [[buffer(0)]],
                               constant EntityUniforms &u [[buffer(1)]],
                               uint vid [[vertex_id]]) {
    EntityOut o;
    o.position = u.mvp * float4(verts[vid].position, 1.0);
    o.normal = verts[vid].normal;
    return o;
}

fragment float4 entity_fragment(EntityOut in [[stage_in]],
                                constant EntityUniforms &u [[buffer(1)]]) {
    float3 N = normalize(in.normal);
    float diffuse = max(dot(N, normalize(u.sunDir.xyz)), 0.0);
    float3 lit = u.color.rgb * (0.5 + 0.5 * diffuse);
    return float4(lit, u.color.a);
}

// --- HUD (прицел) рисуется простым цветом в clip-space ---
struct HudVertex {
    float2 position;
};

vertex float4 hud_vertex(const device HudVertex *verts [[buffer(0)]],
                         uint vid [[vertex_id]]) {
    return float4(verts[vid].position, 0.0, 1.0);
}

fragment float4 hud_fragment() {
    return float4(1.0, 1.0, 1.0, 0.9);
}
