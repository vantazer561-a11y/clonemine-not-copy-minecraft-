import simd

/// Простое животное: блуждает по миру, падает под гравитацией, перепрыгивает уступы.
public final class Animal {
    public enum Kind: CaseIterable {
        case pig, sheep, cow

        public var color: SIMD4<Float> {
            switch self {
            case .pig:   return SIMD4<Float>(0.95, 0.65, 0.70, 1)
            case .sheep: return SIMD4<Float>(0.92, 0.92, 0.88, 1)
            case .cow:   return SIMD4<Float>(0.40, 0.28, 0.20, 1)
            }
        }
        /// Габариты тела (ширина по X/Z, высота по Y).
        public var size: SIMD3<Float> {
            switch self {
            case .pig:   return SIMD3<Float>(0.9, 0.8, 1.2)
            case .sheep: return SIMD3<Float>(0.8, 1.0, 1.2)
            case .cow:   return SIMD3<Float>(1.0, 1.1, 1.5)
            }
        }
    }

    public let kind: Kind
    public var position: SIMD3<Float>
    public var velocity: SIMD3<Float> = .zero
    public var heading: Float           // направление движения (рад)
    public private(set) var onGround = false

    private var changeDirTimer: Float
    private var rng: UInt64

    public static let gravity: Float = 22
    public static let walkSpeed: Float = 1.6

    public init(kind: Kind, position: SIMD3<Float>, seed: UInt64) {
        self.kind = kind
        self.position = position
        self.rng = seed | 1
        self.heading = Float(seed % 628) / 100.0
        self.changeDirTimer = 2 + Float(seed % 300) / 100.0
    }

    private func nextRandom() -> Float {
        // xorshift64
        rng ^= rng << 13; rng ^= rng >> 7; rng ^= rng << 17
        return Float(rng & 0xFFFF) / Float(0x10000)
    }

    public func update(dt: Float, world: World) {
        changeDirTimer -= dt
        if changeDirTimer <= 0 {
            heading = nextRandom() * 2 * .pi
            changeDirTimer = 2 + nextRandom() * 4
        }

        let dir = SIMD3<Float>(sin(heading), 0, cos(heading))
        velocity.x = dir.x * Animal.walkSpeed
        velocity.z = dir.z * Animal.walkSpeed

        if !onGround {
            velocity.y -= Animal.gravity * dt
        }

        // Авто-прыжок через блок высотой 1, если впереди стена.
        let ahead = position + dir * 0.6
        let footBlock = BlockCoord(Int(floor(ahead.x)), Int(floor(position.y)), Int(floor(ahead.z)))
        if onGround && world.block(at: footBlock).isSolid {
            velocity.y = 7
            onGround = false
        }

        moveAxis(SIMD3<Float>(velocity.x * dt, 0, 0), world: world)
        moveAxis(SIMD3<Float>(0, 0, velocity.z * dt), world: world)
        moveY(velocity.y * dt, world: world)
    }

    private func moveAxis(_ delta: SIMD3<Float>, world: World) {
        let newPos = position + delta
        if !collides(at: newPos, world: world) {
            position = newPos
        } else {
            // Упёрлись — сменим направление в следующий тик.
            changeDirTimer = min(changeDirTimer, 0.1)
            if delta.x != 0 { velocity.x = 0 }
            if delta.z != 0 { velocity.z = 0 }
        }
    }

    private func moveY(_ dy: Float, world: World) {
        let newPos = position + SIMD3<Float>(0, dy, 0)
        if !collides(at: newPos, world: world) {
            position = newPos
            onGround = false
        } else {
            if dy < 0 { onGround = true }
            velocity.y = 0
        }
    }

    public func collides(at pos: SIMD3<Float>, world: World) -> Bool {
        let s = kind.size
        let hx = s.x * 0.5, hz = s.z * 0.5
        let minX = Int(floor(pos.x - hx)); let maxX = Int(floor(pos.x + hx))
        let minY = Int(floor(pos.y));        let maxY = Int(floor(pos.y + s.y))
        let minZ = Int(floor(pos.z - hz)); let maxZ = Int(floor(pos.z + hz))
        for bx in minX...maxX {
            for by in minY...maxY {
                for bz in minZ...maxZ {
                    if world.block(at: BlockCoord(bx, by, bz)).isSolid { return true }
                }
            }
        }
        return false
    }
}
