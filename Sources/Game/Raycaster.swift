import simd

public struct RaycastHit {
    public let blockCoord: BlockCoord   // первый твёрдый блок на пути луча
    public let faceNormal: BlockCoord   // нормаль грани, обращённой к источнику
}

/// DDA-обход вокселей (алгоритм Amanatides–Woo). Requirements 4.5, 5.5.
public enum VoxelRaycaster {
    public static func raycast(origin: SIMD3<Float>,
                               direction: SIMD3<Float>,
                               maxDistance: Float,
                               world: World) -> RaycastHit? {
        let dir = simd_normalize(direction)
        var x = Int(floor(origin.x))
        var y = Int(floor(origin.y))
        var z = Int(floor(origin.z))

        let stepX = dir.x > 0 ? 1 : (dir.x < 0 ? -1 : 0)
        let stepY = dir.y > 0 ? 1 : (dir.y < 0 ? -1 : 0)
        let stepZ = dir.z > 0 ? 1 : (dir.z < 0 ? -1 : 0)

        let big: Float = 1e30
        let tDeltaX = dir.x != 0 ? abs(1 / dir.x) : big
        let tDeltaY = dir.y != 0 ? abs(1 / dir.y) : big
        let tDeltaZ = dir.z != 0 ? abs(1 / dir.z) : big

        func tMaxInit(_ o: Float, _ cell: Int, _ step: Int, _ delta: Float) -> Float {
            guard step != 0 else { return big }
            // Расстояние (в долях ячейки) до ближайшей границы по направлению шага.
            let boundary = step > 0 ? Float(cell + 1) : Float(cell)
            return abs(boundary - o) * delta
        }

        var tMaxX = tMaxInit(origin.x, x, stepX, tDeltaX)
        var tMaxY = tMaxInit(origin.y, y, stepY, tDeltaY)
        var tMaxZ = tMaxInit(origin.z, z, stepZ, tDeltaZ)

        var normal = BlockCoord(0, 0, 0)
        var travelled: Float = 0

        // Проверяем стартовую ячейку
        if world.block(at: BlockCoord(x, y, z)).isSolid {
            return RaycastHit(blockCoord: BlockCoord(x, y, z), faceNormal: BlockCoord(0, 0, 0))
        }

        while travelled <= maxDistance {
            if tMaxX < tMaxY && tMaxX < tMaxZ {
                x += stepX; travelled = tMaxX; tMaxX += tDeltaX
                normal = BlockCoord(-stepX, 0, 0)
            } else if tMaxY < tMaxZ {
                y += stepY; travelled = tMaxY; tMaxY += tDeltaY
                normal = BlockCoord(0, -stepY, 0)
            } else {
                z += stepZ; travelled = tMaxZ; tMaxZ += tDeltaZ
                normal = BlockCoord(0, 0, -stepZ)
            }
            if travelled > maxDistance { break }
            if world.block(at: BlockCoord(x, y, z)).isSolid {
                return RaycastHit(blockCoord: BlockCoord(x, y, z), faceNormal: normal)
            }
        }
        return nil
    }
}
