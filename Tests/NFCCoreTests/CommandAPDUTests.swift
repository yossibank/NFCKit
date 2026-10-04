import Foundation
import NFCCore
import Testing

// コマンド APDU のフィールド（ISO/IEC 7816-4:2005 5.1 Table 1）
// - Lc: データのバイト数（Nc）。データがあるときだけ 1 バイト。01〜FF が 1〜255
// - データ: 送る中身。255 バイトまで
// - Le: 期待する応答の最大バイト数（Ne）。1 バイト。01〜FF が 1〜255、00 が 256
//
// Lc と Le の有無による 4 つの形
// - ケース 1: ヘッダだけ（例: データなしの VERIFY ＝ 残り試行回数の問い合わせ）
// - ケース 2: ヘッダ＋Le（例: READ BINARY）
// - ケース 3: ヘッダ＋Lc＋データ（例: SELECT、データ付きの VERIFY）
// - ケース 4: ヘッダ＋Lc＋データ＋Le（例: 応答を受け取る SELECT）
struct CommandAPDUTests {
    @Test("ケース 1: ヘッダだけ")
    func case1() throws {
        let command = try CommandAPDU(
            ins: 0xA4,
            p1: 0x00,
            p2: 0x00
        )

        #expect(command.encoded == Data([0x00, 0xA4, 0x00, 0x00]))
    }

    @Test("ケース 2: Le の 256 は 00 になる")
    func case2() throws {
        let command = try CommandAPDU(
            ins: 0xB0,
            p1: 0x00,
            p2: 0x00,
            expectedLength: 256
        )

        #expect(command.encoded == Data([0x00, 0xB0, 0x00, 0x00, 0x00]))
    }

    @Test("ケース 3: Lc とデータ")
    func case3() throws {
        let command = try CommandAPDU(
            ins: 0x20,
            p1: 0x00,
            p2: 0x80,
            data: Data([0x01, 0x02])
        )

        #expect(command.encoded == Data([0x00, 0x20, 0x00, 0x80, 0x02, 0x01, 0x02]))
    }

    @Test("ケース 4: Lc とデータと Le")
    func case4() throws {
        let command = try CommandAPDU(
            ins: 0xA4,
            p1: 0x04,
            p2: 0x00,
            data: Data([0x01, 0x02]),
            expectedLength: 16
        )

        #expect(command.encoded == Data([0x00, 0xA4, 0x04, 0x00, 0x02, 0x01, 0x02, 0x10]))
    }

    @Test("データは 255 バイトまで")
    func dataLength() throws {
        #expect(throws: Never.self) {
            try CommandAPDU(ins: 0x20, p1: 0x00, p2: 0x00, data: Data(count: 255))
        }

        #expect(throws: APDUError.dataTooLong(256)) {
            try CommandAPDU(ins: 0x20, p1: 0x00, p2: 0x00, data: Data(count: 256))
        }
    }

    @Test("Le は 1 から 256 まで", arguments: [0, 257])
    func expectedLength(length: Int) {
        #expect(throws: APDUError.expectedLengthOutOfRange(length)) {
            try CommandAPDU(ins: 0xB0, p1: 0x00, p2: 0x00, expectedLength: length)
        }
    }

    @Test("SELECT: DF 名で選択")
    func selectDFName() throws {
        let command = try CommandAPDU.select(dfName: Data([0xA0, 0x00]))

        #expect(command.encoded == Data([0x00, 0xA4, 0x04, 0x0C, 0x02, 0xA0, 0x00]))
    }

    @Test("SELECT: EF 識別子で選択")
    func selectEF() throws {
        let command = try CommandAPDU.select(efIdentifier: 0x0011)

        #expect(command.encoded == Data([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x00, 0x11]))
    }

    @Test("READ BINARY: オフセットを P1-P2 に入れる")
    func readBinary() throws {
        let command = try CommandAPDU.readBinary(offset: 0x0102, expectedLength: 256)

        #expect(command.encoded == Data([0x00, 0xB0, 0x01, 0x02, 0x00]))
    }

    @Test("READ BINARY: オフセットは 0 から 32767 まで", arguments: [-1, 0x8000])
    func readBinaryOffset(offset: Int) {
        #expect(throws: APDUError.offsetOutOfRange(offset)) {
            try CommandAPDU.readBinary(offset: offset, expectedLength: 256)
        }
    }

    @Test("VERIFY: データなしは Lc を付けない")
    func verifyWithoutData() throws {
        let command = try CommandAPDU.verify(reference: 0x80)

        #expect(command.encoded == Data([0x00, 0x20, 0x00, 0x80]))
    }

    @Test("VERIFY: データ付き")
    func verifyWithData() throws {
        let command = try CommandAPDU.verify(
            reference: 0x80,
            verificationData: Data([0x31, 0x32, 0x33, 0x34])
        )

        #expect(command.encoded == Data([0x00, 0x20, 0x00, 0x80, 0x04, 0x31, 0x32, 0x33, 0x34]))
    }
}
