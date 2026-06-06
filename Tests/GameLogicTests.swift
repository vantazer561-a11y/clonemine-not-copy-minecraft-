import XCTest
import simd
@testable import VoxelGame

final class GameLogicTests: XCTestCase {

    // Feature: ios-voxel-game, Property 1: детерминированность генерации
    func testDeterministicGeneration() {
        for _ in 0..<100 {
            let seed = UInt64.random(in: 0...UInt64.max)
            let cx = Int.random(in: -10...10)
            let cz = Int.random(in: -10...10)
            let a = TerrainGenerator(seed: seed).generate(chunk: ChunkCoord(cx, cz))
            let b = TerrainGenerator(seed: seed).generate(chunk: ChunkCoord(cx, cz))
            XCTAssertEqual(a.storage, b.storage)
        }
    }

    // Feature: ios-voxel-game, Property 2: начальная область сгенерирована (>=5x5)
    func testInitialAreaGenerated() {
        let world = World(seed: 42)
        let r = WorldConfig.initialRadius
        for cx in -r...r {
            for cz in -r...r {
                XCTAssertNotNil(world.chunk(at: ChunkCoord(cx, cz)))
            }
        }
    }

    // Feature: ios-voxel-game, Property 4: инвариант размера чанка
    func testChunkSizeInvariant() {
        let blocks = TerrainGenerator(seed: 7).generate(chunk: ChunkCoord(0, 0))
        XCTAssertEqual(blocks.storage.count, 16 * 16 * 256)
    }

    // Feature: ios-voxel-game, Property 6: round-trip хранилища блоков
    func testBlockRoundTrip() {
        let world = World(seed: 1)
        for _ in 0..<100 {
            let coord = BlockCoord(Int.random(in: -40...40),
                                   Int.random(in: 1...200),
                                   Int.random(in: -40...40))
            let type = BlockType.placeable.randomElement()!
            world.setBlock(type, at: coord)
            XCTAssertEqual(world.block(at: coord), type)
        }
    }

    // Feature: ios-voxel-game, Property 19: границы инвентаря (насыщение)
    func testInventorySaturation() {
        let inv = Inventory()
        for _ in 0..<1100 { inv.add(.stone) }
        XCTAssertEqual(inv.count(of: .stone), Inventory.maxCount)
        for _ in 0..<(Inventory.maxCount + 50) { inv.consume(.stone) }
        XCTAssertEqual(inv.count(of: .stone), 0)
    }

    // Feature: ios-voxel-game, Property 22: выбор слота назначает выбранный тип
    func testSelectSlotAssignsType() {
        let inv = Inventory()
        for i in 0..<inv.slots.count {
            inv.selectSlot(at: i)
            XCTAssertEqual(inv.selectedType, inv.slots[i].type)
        }
    }

    // Feature: ios-voxel-game, Property 23: различимость отображения типов
    func testColorsAreDistinct() {
        let placeable = BlockType.placeable
        for i in 0..<placeable.count {
            for j in (i + 1)..<placeable.count {
                XCTAssertNotEqual(placeable[i].color, placeable[j].color)
            }
        }
    }

    // Feature: ios-voxel-game, Property 15: ограничение угла наклона камеры
    func testPitchClamped() {
        let p = PlayerController()
        for _ in 0..<100 {
            p.applyLook(delta: SIMD2<Float>(0, Float.random(in: -10000...10000)))
            XCTAssertLessThanOrEqual(abs(p.pitch), Float.pi / 2 + 1e-4)
        }
    }

    // Feature: ios-voxel-game, Property 16/17: raycast находит первый твёрдый блок
    func testRaycastHitsSolid() {
        let world = World(seed: 5)
        // Поставим блок прямо перед лучом.
        world.setBlock(.stone, at: BlockCoord(0, 100, 5))
        let hit = VoxelRaycaster.raycast(origin: SIMD3<Float>(0.5, 100.5, 0.5),
                                         direction: SIMD3<Float>(0, 0, 1),
                                         maxDistance: 5, world: world)
        XCTAssertEqual(hit?.blockCoord, BlockCoord(0, 100, 5))
    }

    // Feature: ios-voxel-game, Property 18: промах луча не меняет состояние
    func testRaycastMissNoChange() {
        let world = World(seed: 9)
        let inv = Inventory(); inv.add(.stone)
        // Высоко в небе блоков нет.
        let eye = SIMD3<Float>(0.5, 250, 0.5)
        let before = world.block(at: BlockCoord(0, 250, 5))
        let placed = Interaction.placeBlock(eye: eye, forward: SIMD3<Float>(0, 0, 1),
                                            world: world, inventory: inv,
                                            player: PlayerController(position: SIMD3<Float>(0.5, 248, 0.5)))
        XCTAssertFalse(placed)
        XCTAssertEqual(world.block(at: BlockCoord(0, 250, 5)), before)
    }

    // Feature: ios-voxel-game, Property 13: коллизии (непроникновение)
    func testCollisionBlocksMovement() {
        let world = World(seed: 3)
        // Сплошная стена из камня на x=2 в зоне движения игрока.
        for y in 69...75 {
            for z in -2...2 {
                world.setBlock(.stone, at: BlockCoord(2, y, z))
            }
        }
        // Пол под игроком, чтобы не проваливался.
        for x in -1...1 {
            for z in -2...2 {
                world.setBlock(.stone, at: BlockCoord(x, 69, z))
            }
        }
        let p = PlayerController(position: SIMD3<Float>(0.5, 70, 0.5))
        // yaw=0 => right=(-1,0,0); moveInput.x=-1 => движение в +x (к стене).
        for _ in 0..<180 {
            p.update(dt: 1.0 / 60.0, moveInput: SIMD2<Float>(-1, 0), jump: false, world: world)
        }
        // Игрок не должен пройти сквозь стену: правый край AABB < 2.
        XCTAssertLessThan(p.position.x + PlayerAABB.halfWidth, 2.0 + 1e-3)
    }
}
