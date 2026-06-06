import simd

/// Связывает мир, игрока, инвентарь и ввод. Координирует игровой цикл.
public final class GameState {
    public let world: World
    public let player: PlayerController
    public let inventory: Inventory
    public private(set) var camera: Camera

    // Текущий ввод (обновляется слоем UI)
    public var moveInput: SIMD2<Float> = .zero
    public var lookDelta: SIMD2<Float> = .zero
    public var jumpRequested: Bool = false

    private var pendingBreak = false
    private var pendingPlace = false

    public init(seed: UInt64? = nil) {
        world = World(seed: seed)
        // Появление над поверхностью в центре мира.
        let gen = TerrainGenerator(seed: world.seed)
        let h = gen.surfaceHeight(worldX: 0, worldZ: 0)
        player = PlayerController(position: SIMD3<Float>(0.5, Float(h) + 2, 0.5))
        inventory = Inventory()
        // Немного блоков на старт, чтобы было что ставить.
        for _ in 0..<32 { inventory.add(.stone); inventory.add(.wood) }
        camera = Camera(position: player.eyePosition)
    }

    public func requestBreak() { pendingBreak = true }
    public func requestPlace() { pendingPlace = true }

    public func update(dt: Float) {
        // Поворот камеры
        if lookDelta != .zero {
            player.applyLook(delta: lookDelta)
            lookDelta = .zero
        }

        player.update(dt: dt, moveInput: moveInput, jump: jumpRequested, world: world)
        jumpRequested = false

        world.ensureChunksLoaded(around: player.position)

        camera.position = player.eyePosition
        camera.yaw = player.yaw
        camera.pitch = player.pitch

        if pendingBreak {
            Interaction.breakBlock(eye: camera.position, forward: camera.forward,
                                   world: world, inventory: inventory)
            pendingBreak = false
        }
        if pendingPlace {
            Interaction.placeBlock(eye: camera.position, forward: camera.forward,
                                   world: world, inventory: inventory, player: player)
            pendingPlace = false
        }
    }
}
