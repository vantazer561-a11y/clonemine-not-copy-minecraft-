import simd

/// Спавнит и обновляет животных вокруг игрока.
public final class AnimalManager {
    public private(set) var animals: [Animal] = []
    private let generator: TerrainGenerator
    private var spawnRng: UInt64
    private let maxAnimals = 12

    public init(seed: UInt64) {
        self.generator = TerrainGenerator(seed: seed)
        self.spawnRng = seed ^ 0xA5A5_5A5A_1234_9876
    }

    private func nextRandom() -> Float {
        spawnRng ^= spawnRng << 13; spawnRng ^= spawnRng >> 7; spawnRng ^= spawnRng << 17
        return Float(spawnRng & 0xFFFF) / Float(0x10000)
    }

    public func update(dt: Float, playerPosition: SIMD3<Float>, world: World) {
        // Спавн при нехватке, в радиусе вокруг игрока.
        if animals.count < maxAnimals {
            spawnNear(playerPosition: playerPosition, world: world)
        }
        for a in animals {
            a.update(dt: dt, world: world)
        }
        // Удаляем тех, кто провалился или слишком далеко.
        animals.removeAll { a in
            let d = simd_distance(SIMD2<Float>(a.position.x, a.position.z),
                                  SIMD2<Float>(playerPosition.x, playerPosition.z))
            return a.position.y < -5 || d > 60
        }
    }

    private func spawnNear(playerPosition: SIMD3<Float>, world: World) {
        let angle = nextRandom() * 2 * .pi
        let radius = 16 + nextRandom() * 24
        let wx = Int(playerPosition.x + cos(angle) * radius)
        let wz = Int(playerPosition.z + sin(angle) * radius)
        let h = generator.surfaceHeight(worldX: wx, worldZ: wz)
        // Не спавним под водой.
        guard h > 38 else { return }
        let kind = Animal.Kind.allCases[Int(nextRandom() * Float(Animal.Kind.allCases.count)) % Animal.Kind.allCases.count]
        let pos = SIMD3<Float>(Float(wx) + 0.5, Float(h) + 1, Float(wz) + 0.5)
        let seed = UInt64(bitPattern: Int64(wx &* 73856093 ^ wz &* 19349663)) ^ spawnRng
        animals.append(Animal(kind: kind, position: pos, seed: seed))
    }
}
