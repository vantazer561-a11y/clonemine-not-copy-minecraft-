import simd

/// Связывает мир, игрока, инвентарь, небо и животных. Координирует игровой цикл.
public final class GameState {
    public let world: World
    public let player: PlayerController
    public let inventory: Inventory
    public let sky: Sky
    public let animals: AnimalManager
    public private(set) var camera: Camera

    // Текущий ввод (обновляется слоем UI)
    public var moveInput: SIMD2<Float> = .zero
    public var lookDelta: SIMD2<Float> = .zero
    public var jumpRequested: Bool = false
    public var sprinting: Bool = false

    private var pendingBreak = false
    private var pendingPlace = false
    private var breakCooldown: Float = 0
    private var placeCooldown: Float = 0

    /// Текущая цель луча (для подсветки в рендере).
    public private(set) var currentTarget: RaycastHit?

    public init(seed: UInt64? = nil) {
        world = World(seed: seed)
        let gen = TerrainGenerator(seed: world.seed)
        let h = gen.surfaceHeight(worldX: 0, worldZ: 0)
        player = PlayerController(position: SIMD3<Float>(0.5, Float(h) + 2, 0.5))
        inventory = Inventory()
        for _ in 0..<32 { inventory.add(.stone); inventory.add(.wood) }
        sky = Sky()
        animals = AnimalManager(seed: world.seed)
        camera = Camera(position: player.eyePosition)
    }

    public func requestBreak() { pendingBreak = true }
    public func requestPlace() { pendingPlace = true }

    public func update(dt: Float) {
        sky.update(dt: dt)

        if lookDelta != .zero {
            player.applyLook(delta: lookDelta)
            lookDelta = .zero
        }

        player.sprinting = sprinting
        player.update(dt: dt, moveInput: moveInput, jump: jumpRequested, world: world)
        jumpRequested = false

        world.ensureChunksLoaded(around: player.position)
        animals.update(dt: dt, playerPosition: player.position, world: world)

        camera.position = player.eyePosition
        camera.yaw = player.yaw
        camera.pitch = player.pitch

        // Постоянное обновление цели для подсветки (Req 7.3/7.4).
        currentTarget = VoxelRaycaster.raycast(origin: camera.position,
                                               direction: camera.forward,
                                               maxDistance: Camera.reachDistance,
                                               world: world)

        breakCooldown = max(0, breakCooldown - dt)
        placeCooldown = max(0, placeCooldown - dt)

        if pendingBreak && breakCooldown == 0 {
            Interaction.breakBlock(eye: camera.position, forward: camera.forward,
                                   world: world, inventory: inventory)
            breakCooldown = 0.18
            pendingBreak = false
        } else {
            pendingBreak = false
        }

        if pendingPlace && placeCooldown == 0 {
            Interaction.placeBlock(eye: camera.position, forward: camera.forward,
                                   world: world, inventory: inventory, player: player)
            placeCooldown = 0.18
            pendingPlace = false
        } else {
            pendingPlace = false
        }
    }
}
