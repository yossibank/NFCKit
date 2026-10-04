import Foundation

// 出典: ISO/IEC 7816-4:2005 5.1 Table 1（Lc・Le は短い長さフィールドのみ扱う）
package struct CommandAPDU: Equatable, Sendable {
    package var encoded: Data {
        var bytes = Data([cla, ins, p1, p2])

        if !data.isEmpty {
            bytes.append(UInt8(data.count))
            bytes.append(data)
        }

        if let expectedLength {
            bytes.append(UInt8(truncatingIfNeeded: expectedLength))
        }

        return bytes
    }

    package let cla: UInt8
    package let ins: UInt8
    package let p1: UInt8
    package let p2: UInt8
    package let data: Data
    package let expectedLength: Int?

    package init(
        cla: UInt8 = 0x00,
        ins: UInt8,
        p1: UInt8,
        p2: UInt8,
        data: Data = Data(),
        expectedLength: Int? = nil
    ) throws(APDUError) {
        guard data.count <= 255 else {
            throw .dataTooLong(data.count)
        }

        if let expectedLength, !(1...256).contains(expectedLength) {
            throw .expectedLengthOutOfRange(expectedLength)
        }

        self.cla = cla
        self.ins = ins
        self.p1 = p1
        self.p2 = p2
        self.data = data
        self.expectedLength = expectedLength
    }
}

package extension CommandAPDU {
    // 出典: ISO/IEC 7816-4:2005 7.1.1
    // Table 39（P1 04 = DF 名で選択）
    // Table 40（P2 0C = 応答データなし）
    static func select(dfName: Data) throws(APDUError) -> CommandAPDU {
        try CommandAPDU(
            ins: 0xA4,
            p1: 0x04,
            p2: 0x0C,
            data: dfName
        )
    }

    // 出典: ISO/IEC 7816-4:2005 7.1.1
    // Table 39（P1 02 = カレント DF 配下の EF を選択）
    // Table 40（P2 0C）
    static func select(efIdentifier: UInt16) throws(APDUError) -> CommandAPDU {
        try CommandAPDU(
            ins: 0xA4,
            p1: 0x02,
            p2: 0x0C,
            data: Data([UInt8(efIdentifier >> 8), UInt8(efIdentifier & 0xFF)])
        )
    }

    // 出典: ISO/IEC 7816-4:2005
    // 7.2.2（P1 の bit 8 が 0 のとき P1-P2 の 15 ビットがオフセット）
    // 7.2.3 Table 42
    static func readBinary(offset: Int, expectedLength: Int) throws(APDUError) -> CommandAPDU {
        guard (0...0x7FFF).contains(offset) else {
            throw .offsetOutOfRange(offset)
        }

        return try CommandAPDU(
            ins: 0xB0,
            p1: UInt8(offset >> 8),
            p2: UInt8(offset & 0xFF),
            expectedLength: expectedLength
        )
    }

    // 出典: ISO/IEC 7816-4:2005
    // 7.5.6 Table 72（データなしで残り試行回数を取得）
    // 7.5.1 Table 65（P2）
    static func verify(
        reference: UInt8,
        verificationData: Data = Data()
    ) throws(APDUError) -> CommandAPDU {
        try CommandAPDU(
            ins: 0x20,
            p1: 0x00,
            p2: reference,
            data: verificationData
        )
    }
}
