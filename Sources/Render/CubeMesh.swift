import simd

struct EntityVertex {
    var position: SIMD3<Float>
    var normal: SIMD3<Float>
}

/// Геометрия единичного куба [0,1]^3 с нормалями — для животных и подсветки.
enum CubeMesh {
    static let vertices: [EntityVertex] = {
        let faces: [(SIMD3<Float>, [SIMD3<Float>])] = [
            (SIMD3<Float>(0, 0, 1),  [SIMD3<Float>(0,0,1), SIMD3<Float>(1,0,1), SIMD3<Float>(1,1,1), SIMD3<Float>(0,1,1)]),
            (SIMD3<Float>(0, 0, -1), [SIMD3<Float>(1,0,0), SIMD3<Float>(0,0,0), SIMD3<Float>(0,1,0), SIMD3<Float>(1,1,0)]),
            (SIMD3<Float>(1, 0, 0),  [SIMD3<Float>(1,0,1), SIMD3<Float>(1,0,0), SIMD3<Float>(1,1,0), SIMD3<Float>(1,1,1)]),
            (SIMD3<Float>(-1, 0, 0), [SIMD3<Float>(0,0,0), SIMD3<Float>(0,0,1), SIMD3<Float>(0,1,1), SIMD3<Float>(0,1,0)]),
            (SIMD3<Float>(0, 1, 0),  [SIMD3<Float>(0,1,1), SIMD3<Float>(1,1,1), SIMD3<Float>(1,1,0), SIMD3<Float>(0,1,0)]),
            (SIMD3<Float>(0, -1, 0), [SIMD3<Float>(0,0,0), SIMD3<Float>(1,0,0), SIMD3<Float>(1,0,1), SIMD3<Float>(0,0,1)]),
        ]
        var verts: [EntityVertex] = []
        for (n, c) in faces {
            // два треугольника на грань
            let quad = [c[0], c[1], c[2], c[0], c[2], c[3]]
            for p in quad { verts.append(EntityVertex(position: p, normal: n)) }
        }
        return verts
    }()
}

func makeTranslationScale(translation t: SIMD3<Float>, scale s: SIMD3<Float>) -> simd_float4x4 {
    simd_float4x4(columns: (
        SIMD4<Float>(s.x, 0, 0, 0),
        SIMD4<Float>(0, s.y, 0, 0),
        SIMD4<Float>(0, 0, s.z, 0),
        SIMD4<Float>(t.x, t.y, t.z, 1)
    ))
}
