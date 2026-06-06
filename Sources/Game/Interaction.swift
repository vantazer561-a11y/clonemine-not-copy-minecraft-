import simd

/// Разрушение и установка блоков. Requirements 4, 5.
public enum Interaction {
    /// Разрушение: raycast -> удалить -> пополнить инвентарь (Req 4).
    @discardableResult
    public static func breakBlock(eye: SIMD3<Float>, forward: SIMD3<Float>,
                                  world: World, inventory: Inventory) -> Bool {
        guard let hit = VoxelRaycaster.raycast(origin: eye, direction: forward,
                                               maxDistance: Camera.reachDistance,
                                               world: world) else { return false }
        guard let removed = world.removeBlock(at: hit.blockCoord) else { return false }
        inventory.add(removed)  // насыщение на 999 внутри
        return true
    }

    /// Установка: raycast -> ячейка у обращённой грани -> разместить (Req 5).
    @discardableResult
    public static func placeBlock(eye: SIMD3<Float>, forward: SIMD3<Float>,
                                  world: World, inventory: Inventory,
                                  player: PlayerController) -> Bool {
        let type = inventory.selectedType
        guard inventory.count(of: type) > 0 else { return false }   // Req 5.2
        guard let hit = VoxelRaycaster.raycast(origin: eye, direction: forward,
                                               maxDistance: Camera.reachDistance,
                                               world: world) else { return false } // Req 5.6
        let target = hit.blockCoord &+ hit.faceNormal
        // Ячейка занята твёрдым блоком или пересекает игрока -> отмена (Req 5.4)
        guard !world.block(at: target).isSolid else { return false }
        guard !player.occupies(blockCoord: target) else { return false }
        guard world.setBlock(type, at: target) else { return false }
        inventory.consume(type)  // Req 5.3
        return true
    }
}
