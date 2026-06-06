import simd

/// Тип блока (воксель). См. Requirement 6 (типы блоков).
public enum BlockType: UInt8, CaseIterable {
    case air = 0
    case grass
    case dirt
    case stone
    case sand
    case wood
    case water

    /// Твёрдый ли блок (участвует в коллизиях и raycast). Вода и воздух — нет.
    public var isSolid: Bool { self != .air && self != .water }

    /// Можно ли блок устанавливать из инвентаря.
    public var isPlaceable: Bool { self != .air }

    /// Устанавливаемые игроком типы (для слотов инвентаря). Requirement 6.1: >= 5.
    public static var placeable: [BlockType] {
        allCases.filter { $0.isPlaceable }
    }

    /// Базовый цвет типа блока. Requirement 6.5: каждый тип визуально различим.
    public var color: SIMD4<Float> {
        switch self {
        case .air:   return SIMD4<Float>(0, 0, 0, 0)
        case .grass: return SIMD4<Float>(0.36, 0.62, 0.24, 1)
        case .dirt:  return SIMD4<Float>(0.55, 0.40, 0.25, 1)
        case .stone: return SIMD4<Float>(0.50, 0.50, 0.52, 1)
        case .sand:  return SIMD4<Float>(0.86, 0.80, 0.55, 1)
        case .wood:  return SIMD4<Float>(0.45, 0.30, 0.15, 1)
        case .water: return SIMD4<Float>(0.20, 0.40, 0.80, 0.7)
        }
    }
}
