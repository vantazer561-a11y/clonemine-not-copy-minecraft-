import XCTest
import simd
@testable import VoxelGame

final class WorldContentTests: XCTestCase {

    // Деревья: генерация детерминирована и появляется листва/дерево хотя бы где-то.
    func testTreesAreGeneratedDeterministically() {
        let seed: UInt64 = 12345
        var foundLeaves = false
        for cx in -3...3 {
            for cz in -3...3 {
                let a = TerrainGenerator(seed: seed).generate(chunk: ChunkCoord(cx, cz))
                let b = TerrainGenerator(seed: seed).generate(chunk: ChunkCoord(cx, cz))
                XCTAssertEqual(a.storage, b.storage, "Генерация чанка должна быть детерминированной")
                if a.storage.contains(.leaves) { foundLeaves = true }
            }
        }
        XCTAssertTrue(foundLeaves, "В достаточно большой области должны появиться деревья (листва)")
    }

    // Листва прозрачна, дерево — твёрдый блок.
    func testLeavesTransparency() {
        XCTAssertTrue(BlockType.leaves.isTransparent)
        XCTAssertTrue(BlockType.leaves.isSolid)   // листва твёрдая для коллизий, но прозрачная для меша
        XCTAssertFalse(BlockType.wood.isTransparent)
    }

    // Небо: суточный цикл цикличен и daylight в [0,1].
    func testSkyCycle() {
        let sky = Sky()
        for _ in 0..<1000 {
            sky.update(dt: 0.5)
            let d = sky.daylight
            XCTAssertGreaterThanOrEqual(d, 0)
            XCTAssertLessThanOrEqual(d, 1)
            let dir = sky.sunDirection
            XCTAssertEqual(simd_length(dir), 1, accuracy: 1e-3)
        }
    }

    // Инверсия обзора: знак изменения pitch меняется на противоположный.
    func testInvertYControl() {
        let normal = PlayerController()
        normal.invertY = false
        normal.applyLook(delta: SIMD2<Float>(0, 100))
        let inverted = PlayerController()
        inverted.invertY = true
        inverted.applyLook(delta: SIMD2<Float>(0, 100))
        XCTAssertEqual(normal.pitch, -inverted.pitch, accuracy: 1e-5)
    }

    // Чувствительность масштабирует поворот.
    func testSensitivityScaling() {
        let slow = PlayerController(); slow.lookSensitivity = 0.5
        let fast = PlayerController(); fast.lookSensitivity = 2.0
        slow.applyLook(delta: SIMD2<Float>(100, 0))
        fast.applyLook(delta: SIMD2<Float>(100, 0))
        XCTAssertGreaterThan(abs(fast.yaw), abs(slow.yaw))
    }

    // Бег увеличивает горизонтальную скорость перемещения.
    func testSprintIncreasesSpeed() {
        let world = World(seed: 1)
        // плоский пол
        for x in -3...3 { for z in -3...3 { world.setBlock(.stone, at: BlockCoord(x, 60, z)) } }

        let walker = PlayerController(position: SIMD3<Float>(0.5, 61, 0.5))
        walker.sprinting = false
        let runner = PlayerController(position: SIMD3<Float>(0.5, 61, 0.5))
        runner.sprinting = true
        for _ in 0..<30 {
            walker.update(dt: 1.0/60.0, moveInput: SIMD2<Float>(0, 1), jump: false, world: world)
            runner.update(dt: 1.0/60.0, moveInput: SIMD2<Float>(0, 1), jump: false, world: world)
        }
        XCTAssertGreaterThan(runner.position.z, walker.position.z)
    }

    // Животное падает под гравитацией и встаёт на поверхность.
    func testAnimalLandsOnGround() {
        let world = World(seed: 2)
        for x in -2...2 { for z in -2...2 { world.setBlock(.stone, at: BlockCoord(x, 50, z)) } }
        let animal = Animal(kind: .pig, position: SIMD3<Float>(0.5, 60, 0.5), seed: 99)
        for _ in 0..<300 {
            animal.update(dt: 1.0/60.0, world: world)
        }
        // Должно остановиться около поверхности y=51 (верх блока на y=50).
        XCTAssertLessThan(animal.position.y, 53)
        XCTAssertGreaterThan(animal.position.y, 50)
    }

    // Менеджер животных спавнит существ рядом с игроком.
    func testAnimalSpawning() {
        let world = World(seed: 7)
        let mgr = AnimalManager(seed: 7)
        let pos = SIMD3<Float>(0, 60, 0)
        for _ in 0..<60 {
            mgr.update(dt: 0.1, playerPosition: pos, world: world)
        }
        XCTAssertGreaterThan(mgr.animals.count, 0, "Должны заспавниться животные")
    }
}
