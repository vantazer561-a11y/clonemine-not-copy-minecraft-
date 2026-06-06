#include <metal_stdlib>
using namespace metal;

struct VoxelVertex {
    float3 position;
    float3 normal;
    float4 color;
};

struct Uniforms {
    float4x4 viewProjection;
};

struct VOut {
    float4 position [[position]];
    float4 color;
};

vertex VOut voxel_vertex(const device VoxelVertex *verts [[buffer(0)]],
                         constant Uniforms &u [[buffer(1)]],
                         uint vid [[vertex_id]]) {
    VOut out;
    float4 worldPos = float4(verts[vid].position, 1.0);
    out.position = u.viewProjection * worldPos;
    out.color = verts[vid].color;
    return out;
}

fragment float4 voxel_fragment(VOut in [[stage_in]]) {
    return in.color;
}

// --- HUD (прицел / выделение) рисуется простым цветом в clip-space ---
struct HudVertex {
    float2 position;
};

vertex float4 hud_vertex(const device HudVertex *verts [[buffer(0)]],
                         uint vid [[vertex_id]]) {
    return float4(verts[vid].position, 0.0, 1.0);
}

fragment float4 hud_fragment() {
    return float4(1.0, 1.0, 1.0, 1.0);
}
