// 出典: ISO/IEC 7816-4:2005 5.1.3 Table 5、Table 6
package struct StatusWord: Hashable, Sendable {
    package static let success = StatusWord(sw1: 0x90, sw2: 0x00)

    package var rawValue: UInt16 {
        UInt16(sw1) << 8 | UInt16(sw2)
    }

    package var condition: Condition {
        switch (sw1, sw2) {
        case (0x90, 0x00):
            .success

        case (0x63, 0xC0...0xCF):
            // 下位 4 ビット（X）を取り出す
            .counter(Int(sw2 & 0x0F))

        case (0x69, 0x83):
            .authenticationMethodBlocked

        case (0x6A, 0x82):
            .fileOrApplicationNotFound

        default:
            .other
        }
    }

    package let sw1: UInt8
    package let sw2: UInt8

    package init(sw1: UInt8, sw2: UInt8) {
        self.sw1 = sw1
        self.sw2 = sw2
    }
}

package extension StatusWord {
    enum Condition: Equatable, Sendable {
        case success
        case counter(Int)
        case authenticationMethodBlocked
        case fileOrApplicationNotFound
        case other
    }
}
