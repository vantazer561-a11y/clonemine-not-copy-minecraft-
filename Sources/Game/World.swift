import simd

/// Мир: генерация, хранение и обновление чанков. Requirements 1, 2, 4, 5.
public final class World {
    public let seed: UInt64
    private let generator: TerrainGenerator
    private(set) var chunks: [ChunkCoord: Chunk] = [:]
    private var dirty: Set<ChunkCoord> = []

    public init(seed: UInt64? = nil) {
        // Requirement 1.6: случайный сид, если не задан.
        self.seed = seed ?? UInt64.random(in: UInt64.min...UInt64.max)
        self.generator = TerrainGenerator(seed: self.seed)
        generateInitialArea()
    }

    private func generateInitialArea() {
        // Requirement 1.1: область не менее 5x5 (радиус 2) вокруг точки появления.
        let r = WorldConfig.initialRadius
        for cx in -r...r {
            for cz in -r...r {
                _ = loadChunk(ChunkCoord(cx, cz))
            }
        }
    }

    @discardableResult
    private func loadChunk(_ coord: ChunkCoord) -> Chunk {
        if let existing = chunks[coord] { return existing }
        let blocks = generator.generate(chunk: coord)
        let chunk = Chunk(coord: coord, blocks: blocks)
        chunks[coord] = chunk
        dirty.insert(coord)
        return chunk
    }

    public func chunk(at coord: ChunkCoord) -> Chunk? {
        chunks[coord]
    }

    /// Тип блока в мировых координатах (.air вне диапазона по Y или незагруженного чанка).
    public func block(at coord: BlockCoord) -> BlockType {
        guard coord.y >= 0, coord.y < WorldConfig.chunkSizeY else { return .air }
        let cc = CoordMath.chunkCoord(for: coord)
        guard let chunk = chunks[cc] else { return .air }
        let l = CoordMath.localCoord(for: coord)
        return chunk.blocks.block(localX: l.x, y: l.y, localZ: l.z)
    }

    @discardableResult
    public func setBlock(_ type: BlockType, at coord: BlockCoord) -> Bool {
        guard coord.y >= 0, coord.y < WorldConfig.chunkSizeY else { return false }
        let cc = CoordMath.chunkCoord(for: coord)
        let chunk = loadChunk(cc)
        let l = CoordMath.localCoord(for: coord)
        chunk.blocks.set(type, localX: l.x, y: l.y, localZ: l.z)
        chunk.isDirty = true
        chunk.isModified = true
        dirty.insert(cc)
        markNeighborDirtyIfEdge(coord: coord, local: l)
        return true
    }

    /// Удалить блок -> air. Возвращает тип удалённого (если был твёрдый). Requirement 4.1.
    @discardableResult
    public func removeBlock(at coord: BlockCoord) -> BlockType? {
        let current = block(at: coord)
        guard current != .air else { return nil }
        setBlock(.air, at: coord)
        return current
    }

    private func markNeighborDirtyIfEdge(coord: BlockCoord, local: (x: Int, y: Int, z: Int)) {
        let cc = CoordMath.chunkCoord(for: coord)
        if local.x == 0 { dirty.insert(ChunkCoord(cc.x - 1, cc.y)) }
        if local.x == WorldConfig.chunkSizeX - 1 { dirty.insert(ChunkCoord(cc.x + 1, cc.y)) }
        if local.z == 0 { dirty.insert(ChunkCoord(cc.x, cc.y - 1)) }
        if local.z == WorldConfig.chunkSizeZ - 1 { dirty.insert(ChunkCoord(cc.x, cc.y + 1)) }
    }

    /// Requirement 1.4: подгрузка соседних чанков у границы.
    public func ensureChunksLoaded(around position: SIMD3<Float>) {
        let pcx = CoordMath.floorDiv(Int(floor(position.x)), WorldConfig.chunkSizeX)
        let pcz = CoordMath.floorDiv(Int(floor(position.z)), WorldConfig.chunkSizeZ)
        let r = WorldConfig.initialRadius
        for cx in (pcx - r)...(pcx + r) {
            for cz in (pcz - r)...(pcz + r) {
                _ = loadChunk(ChunkCoord(cx, cz))
            }
        }
    }

    /// Возвращает и очищает множество "грязных" чанков, нуждающихся в перестройке меша.
    public func consumeDirtyChunks() -> [ChunkCoord] {
        let result = Array(dirty).filter { chunks[$0] != nil }
        dirty.removeAll()
        for c in result { chunks[c]?.isDirty = false }
        return result
    }
}
