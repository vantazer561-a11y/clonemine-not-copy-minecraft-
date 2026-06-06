import simd

public struct PlayerAABB {
    public static let halfWidth: Float = 0.3
    public static let height: Float = 1.8
    public static let eyeHeight: Float = 1.6
}

/// Перемещение, гравитация, коллизии, прыжок. Requirement 3.
public final class PlayerController {
    public private(set) var position: SIMD3<Float>  // позиция ног (низ AABB)
    public private(set) var velocity: SIMD3<Float> = .zero
    public var yaw: Float = 0
    public var pitch: Float = 0
    public private(set) var onGround: Bool = false

    public static let moveSpeed: Float = 4.0      // блоков/сек (Req 3.1)
    public static let gravity: Float = 24.0       // блоков/сек^2 (Req 3.3)
    public static let jumpSpeed: Float = 8.0      // даёт подъём ~1.3 блока (Req 3.5)
    public static let lookSensitivity: Float = 0.005

    public init(position: SIMD3<Float> = SIMD3<Float>(0, 80, 0)) {
        self.position = position
    }

    public var eyePosition: SIMD3<Float> {
        position + SIMD3<Float>(0, PlayerAABB.eyeHeight, 0)
    }

    /// Поворот камеры пропорционально перетаскиванию; pitch ограничен [-90°,+90°] (Req 3.2, 3.6).
    public func applyLook(delta: SIMD2<Float>) {
        yaw += delta.x * PlayerController.lookSensitivity
        pitch -= delta.y * PlayerController.lookSensitivity
        let limit = Float.pi / 2
        pitch = max(-limit, min(limit, pitch))
    }

    /// Шаг симуляции. moveInput из зоны движения в [-1,1]^2.
    public func update(dt: Float, moveInput: SIMD2<Float>, jump: Bool, world: World) {
        // Горизонтальное движение относительно направления взгляда (yaw).
        let forward = SIMD3<Float>(sin(yaw), 0, cos(yaw))
        let right = SIMD3<Float>(sin(yaw - .pi / 2), 0, cos(yaw - .pi / 2))
        var wish = forward * moveInput.y + right * moveInput.x
        if simd_length(wish) > 1 { wish = simd_normalize(wish) }
        let horizontal = wish * PlayerController.moveSpeed

        velocity.x = horizontal.x
        velocity.z = horizontal.z

        // Гравитация (Req 3.3)
        if !onGround {
            velocity.y -= PlayerController.gravity * dt
        }
        // Прыжок только с земли (Req 3.5)
        if jump && onGround {
            velocity.y = PlayerController.jumpSpeed
            onGround = false
        }

        moveAxis(SIMD3<Float>(velocity.x * dt, 0, 0), world: world)
        moveAxis(SIMD3<Float>(0, 0, velocity.z * dt), world: world)
        moveAxisY(velocity.y * dt, world: world)
    }

    // Раздельное разрешение коллизий по осям (Req 3.4).
    private func moveAxis(_ delta: SIMD3<Float>, world: World) {
        let newPos = position + delta
        if !collides(at: newPos, world: world) {
            position = newPos
        } else {
            if delta.x != 0 { velocity.x = 0 }
            if delta.z != 0 { velocity.z = 0 }
        }
    }

    private func moveAxisY(_ dy: Float, world: World) {
        let newPos = position + SIMD3<Float>(0, dy, 0)
        if !collides(at: newPos, world: world) {
            position = newPos
            onGround = false
        } else {
            if dy < 0 { onGround = true }
            velocity.y = 0
        }
    }

    /// Проверка пересечения AABB игрока с твёрдыми блоками.
    public func collides(at pos: SIMD3<Float>, world: World) -> Bool {
        let hw = PlayerAABB.halfWidth
        let minX = Int(floor(pos.x - hw)); let maxX = Int(floor(pos.x + hw))
        let minY = Int(floor(pos.y));       let maxY = Int(floor(pos.y + PlayerAABB.height))
        let minZ = Int(floor(pos.z - hw)); let maxZ = Int(floor(pos.z + hw))
        for bx in minX...maxX {
            for by in minY...maxY {
                for bz in minZ...maxZ {
                    if world.block(at: BlockCoord(bx, by, bz)).isSolid { return true }
                }
            }
        }
        return false
    }

    /// Пересекает ли заданная ячейка объём игрока (для запрета установки, Req 5.4).
    public func occupies(blockCoord: BlockCoord) -> Bool {
        let hw = PlayerAABB.halfWidth
        let minX = Int(floor(position.x - hw)); let maxX = Int(floor(position.x + hw))
        let minY = Int(floor(position.y));       let maxY = Int(floor(position.y + PlayerAABB.height))
        let minZ = Int(floor(position.z - hw)); let maxZ = Int(floor(position.z + hw))
        return blockCoord.x >= minX && blockCoord.x <= maxX
            && blockCoord.y >= minY && blockCoord.y <= maxY
            && blockCoord.z >= minZ && blockCoord.z <= maxZ
    }
}
