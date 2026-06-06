import simd

/// Детерминированная процедурная генерация ландшафта.
/// Requirements 1.2 (детерминированность), 1.5 (>=3 типа на поверхности), 1.6 (сид).
public struct TerrainGenerator {
    public let seed: UInt64

    public init(seed: UInt64) {
        self.seed = seed
    }

    /// Хэш-функция (SplitMix64-подобная), детерминированно зависит от seed и координат.
    @inline(__always)
    private func hash(_ x: Int, _ z: Int) -> UInt64 {
        var v = seed &+ UInt64(bitPattern: Int64(x)) &* 0x9E3779B97F4A7C15
        v ^= UInt64(bitPattern: Int64(z)) &* 0xC2B2AE3D27D4EB4F
        v = (v ^ (v >> 30)) &* 0xBF58476D1CE4E5B9
        v = (v ^ (v >> 27)) &* 0x94D049BB133111EB
        v ^= v >> 31
        return v
    }

    /// Значение шума в [0,1) для целочисленного узла сетки.
    @inline(__always)
    private func noiseAt(_ x: Int, _ z: Int) -> Float {
        Float(hash(x, z) & 0xFFFFFF) / Float(0x1000000)
    }

    /// Сглаженный (билинейно интерполированный) шум.
    private func smoothNoise(_ x: Float, _ z: Float) -> Float {
        let x0 = Int(floor(x)); let z0 = Int(floor(z))
        let fx = x - Float(x0); let fz = z - Float(z0)
        let n00 = noiseAt(x0, z0)
        let n10 = noiseAt(x0 + 1, z0)
        let n01 = noiseAt(x0, z0 + 1)
        let n11 = noiseAt(x0 + 1, z0 + 1)
        let sx = fx * fx * (3 - 2 * fx)
        let sz = fz * fz * (3 - 2 * fz)
        let a = n00 + (n10 - n00) * sx
        let b = n01 + (n11 - n01) * sx
        return a + (b - a) * sz
    }

    /// Высота поверхности в мировых координатах столбца.
    public func surfaceHeight(worldX: Int, worldZ: Int) -> Int {
        var amplitude: Float = 24
        var frequency: Float = 0.02
        var height: Float = 40
        for _ in 0..<4 {
            height += (smoothNoise(Float(worldX) * frequency, Float(worldZ) * frequency) - 0.5)
                * 2 * amplitude
            amplitude *= 0.5
            frequency *= 2
        }
        return max(1, min(WorldConfig.chunkSizeY - 2, Int(height)))
    }

    /// Заполняет блоки чанка детерминированно.
    public func generate(chunk coord: ChunkCoord) -> ChunkBlocks {
        var blocks = ChunkBlocks()
        let baseX = coord.x * WorldConfig.chunkSizeX
        let baseZ = coord.y * WorldConfig.chunkSizeZ
        let waterLevel = 38

        for lx in 0..<WorldConfig.chunkSizeX {
            for lz in 0..<WorldConfig.chunkSizeZ {
                let wx = baseX + lx
                let wz = baseZ + lz
                let h = surfaceHeight(worldX: wx, worldZ: wz)

                for y in 0...h {
                    let type: BlockType
                    if y == h {
                        // Поверхностный слой: трава / песок / камень (>=3 типа, Req 1.5)
                        if h <= waterLevel + 1 {
                            type = .sand
                        } else if h > 70 {
                            type = .stone
                        } else {
                            type = .grass
                        }
                    } else if y > h - 4 {
                        type = .dirt
                    } else {
                        type = .stone
                    }
                    blocks.set(type, localX: lx, y: y, localZ: lz)
                }

                // Вода в низинах
                if h < waterLevel {
                    for y in (h + 1)...waterLevel {
                        blocks.set(.water, localX: lx, y: y, localZ: lz)
                    }
                }
            }
        }
        return blocks
    }
}
