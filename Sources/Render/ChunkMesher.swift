import simd

public struct VoxelVertex {
    public var position: SIMD3<Float>
    public var normal: SIMD3<Float>
    public var color: SIMD4<Float>
}

public struct ChunkMesh {
    public var vertices: [VoxelVertex] = []
    public var indices: [UInt32] = []
}

/// Face-culling мешер: грань строится только если соседний блок не твёрдый.
/// Requirements 2.3, 7.5.
public enum ChunkMesher {
    // (нормаль, 4 угла грани в локальных координатах единичного куба)
    private static let faces: [(normal: SIMD3<Float>, corners: [SIMD3<Float>])] = [
        (SIMD3<Float>(0, 0, 1),  [SIMD3<Float>(0,0,1), SIMD3<Float>(1,0,1), SIMD3<Float>(1,1,1), SIMD3<Float>(0,1,1)]),
        (SIMD3<Float>(0, 0, -1), [SIMD3<Float>(1,0,0), SIMD3<Float>(0,0,0), SIMD3<Float>(0,1,0), SIMD3<Float>(1,1,0)]),
        (SIMD3<Float>(1, 0, 0),  [SIMD3<Float>(1,0,1), SIMD3<Float>(1,0,0), SIMD3<Float>(1,1,0), SIMD3<Float>(1,1,1)]),
        (SIMD3<Float>(-1, 0, 0), [SIMD3<Float>(0,0,0), SIMD3<Float>(0,0,1), SIMD3<Float>(0,1,1), SIMD3<Float>(0,1,0)]),
        (SIMD3<Float>(0, 1, 0),  [SIMD3<Float>(0,1,1), SIMD3<Float>(1,1,1), SIMD3<Float>(1,1,0), SIMD3<Float>(0,1,0)]),
        (SIMD3<Float>(0, -1, 0), [SIMD3<Float>(0,0,0), SIMD3<Float>(1,0,0), SIMD3<Float>(1,0,1), SIMD3<Float>(0,0,1)]),
    ]

    public static func buildMesh(for chunk: Chunk, world: World) -> ChunkMesh {
        var mesh = ChunkMesh()
        let baseX = chunk.coord.x * WorldConfig.chunkSizeX
        let baseZ = chunk.coord.y * WorldConfig.chunkSizeZ

        for lx in 0..<WorldConfig.chunkSizeX {
            for lz in 0..<WorldConfig.chunkSizeZ {
                for y in 0..<WorldConfig.chunkSizeY {
                    let type = chunk.blocks.block(localX: lx, y: y, localZ: lz)
                    guard type != .air else { continue }
                    let wx = baseX + lx, wz = baseZ + lz
                    let origin = SIMD3<Float>(Float(wx), Float(y), Float(wz))

                    for face in faces {
                        let nx = wx + Int(face.normal.x)
                        let ny = y + Int(face.normal.y)
                        let nz = wz + Int(face.normal.z)
                        let neighbor = world.block(at: BlockCoord(nx, ny, nz))
                        // Грань видна, если сосед не твёрдый (face culling)
                        if neighbor.isSolid { continue }
                        if type == .water && neighbor == .water { continue }
                        appendFace(&mesh, origin: origin, face: face, color: type.color)
                    }
                }
            }
        }
        return mesh
    }

    private static func appendFace(_ mesh: inout ChunkMesh, origin: SIMD3<Float>,
                                   face: (normal: SIMD3<Float>, corners: [SIMD3<Float>]),
                                   color: SIMD4<Float>) {
        let base = UInt32(mesh.vertices.count)
        // Простое затенение по нормали для читаемости граней.
        let shade = 0.65 + 0.35 * max(0, simd_dot(simd_normalize(face.normal),
                                                   simd_normalize(SIMD3<Float>(0.4, 1, 0.3))))
        let shaded = SIMD4<Float>(color.x * shade, color.y * shade, color.z * shade, color.w)
        for c in face.corners {
            mesh.vertices.append(VoxelVertex(position: origin + c,
                                             normal: face.normal,
                                             color: shaded))
        }
        mesh.indices.append(contentsOf: [base, base + 1, base + 2, base, base + 2, base + 3])
    }
}
