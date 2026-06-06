/// Инвентарь и выбор типа блока. Requirement 6.
public final class Inventory {
    public struct Slot {
        public let type: BlockType
        public var count: Int   // 0...999
    }

    public static let maxCount = 999

    public private(set) var slots: [Slot]
    public private(set) var selectedIndex: Int

    public init() {
        // По слоту на каждый устанавливаемый тип (Requirement 6.2, >=5 слотов).
        slots = BlockType.placeable.map { Slot(type: $0, count: 0) }
        selectedIndex = 0   // первый слот выбран при старте (Requirement 6.3)
    }

    public var selectedType: BlockType {
        slots[selectedIndex].type
    }

    /// Выбор слота назначает Selected_Block_Type независимо от количества (Requirement 6.4).
    public func selectSlot(at index: Int) {
        guard index >= 0, index < slots.count else { return }
        selectedIndex = index
    }

    public func count(of type: BlockType) -> Int {
        slots.first(where: { $0.type == type })?.count ?? 0
    }

    /// +1, насыщение на 999 (Requirements 4.3, 4.4).
    @discardableResult
    public func add(_ type: BlockType) -> Bool {
        guard let i = slots.firstIndex(where: { $0.type == type }) else { return false }
        guard slots[i].count < Inventory.maxCount else { return false }
        slots[i].count += 1
        return true
    }

    /// -1, только если > 0 (Requirement 5.3).
    @discardableResult
    public func consume(_ type: BlockType) -> Bool {
        guard let i = slots.firstIndex(where: { $0.type == type }) else { return false }
        guard slots[i].count > 0 else { return false }
        slots[i].count -= 1
        return true
    }
}
