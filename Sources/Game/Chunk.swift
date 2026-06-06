import simd

/// Координата чанка в горизонтальной сетке (chunkX, chunkZ).
public typealias ChunkCoord = SIMD2<Int>
/// Мировые целочисленные координаты блока.
public typealias BlockCoord = SIMD3<Int>

public enum WorldConfig {
    public static let chunkSizeX = 16
    public static let chunkSizeZ = 16
    public static let chunkSizeY = 256
    public static let initialRadius = 2   // 5x5 чанков => радиус 2 (Requirement 1.1)
    public static let loadMargin = 2      // Requirement 1.4
    public static let blocksPerChunk = 16 * 16 * 256
}

/// Плотное хранилище блоков чанка. Индекс = x + z*16 + y*16*16. (Requirement 2.1)
public struct ChunkBlocks {
    public private(set) var storage: [BlockType]

    public init() {
        storage = [BlockType](repeating: .air, count: WorldConfig.blocksPerChunk)
    }

    @inline(__always)
    static func index(_ x: Int, _ y: Int, _ z: Int) -> Int {
        x + z * WorldConfig.chunkSizeX + y * WorldConfig.chunkSizeX * WorldConfig.chunkSizeZ
    }

    @inline(__always)
    public func block(localX x: Int, y: Int, localZ z: Int) -> BlockType {
        guard x >= 0, x < WorldConfig.chunkSizeX,
              z >= 0, z < WorldConfig.chunkSizeZ,
              y >= 0, y < WorldConfig.chunkSizeY else { return .air }
        return storage[ChunkBlocks.index(x, y, z)]
    }

    public mutating func set(_ t: BlockType, localX x: Int, y: Int, localZ z: Int) {
        guard x >= 0, x < WorldConfig.chunkSizeX,
              z >= 0, z < WorldConfig.chunkSizeZ,
              y >= 0, y < WorldConfig.chunkSizeY else { return }
        storage[ChunkBlocks.index(x, y, z)] = t
    }
}

public final class Chunk {
    public let coord: ChunkCoord
    public var blocks: ChunkBlocks
    public var isDirty: Bool = true       // нужна перестройка меша
    public var isModified: Bool = false   // изменён игроком (Requirement 2.5)

    public init(coord: ChunkCoord, blocks: ChunkBlocks) {
        self.coord = coord
        self.blocks = blocks
    }
}

public enum CoordMath {
    /// Деление с округлением вниз (корректно для отрицательных).
    @inline(__always)
    public static func floorDiv(_ a: Int, _ b: Int) -> Int {
        let q = a / b
        let r = a % b
        return (r != 0 && (r < 0) != (b < 0)) ? q - 1 : q
    }

    @inline(__always)
    public static func mod(_ a: Int, _ b: Int) -> Int {
        let r = a % b
        return r < 0 ? r + b : r
    }

    /// Мировые координаты блока -> координата чанка.
    public static func chunkCoord(for block: BlockCoord) -> ChunkCoord {
        ChunkCoord(floorDiv(block.x, WorldConfig.chunkSizeX),
                   floorDiv(block.z, WorldConfig.chunkSizeZ))
    }

    /// Мировые координаты блока -> локальные внутри чанка.
    public static func localCoord(for block: BlockCoord) -> (x: Int, y: Int, z: Int) {
        (mod(block.x, WorldConfig.chunkSizeX), block.y, mod(block.z, WorldConfig.chunkSizeZ))
    }
}
