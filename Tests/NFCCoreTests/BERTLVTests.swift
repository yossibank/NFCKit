import Foundation
import NFCCore
import Testing

// BER-TLV の読み方（ISO/IEC 7816-4:2005 5.2.2）
// - タグ: 1〜3 バイト。先頭バイトの下位 5 ビットがすべて 1 なら続く。2 バイト目の bit 8 が 1 なら 3 バイト目が続く
//   不正: 先頭が 00 または FF、2 バイト目が 00〜1E または 80
// - 長さ: 00〜7F はその値。81〜84 は続く 1〜4 バイトが長さ
//   不正: 80（不定長）と 85〜FF
// - 構造化: 先頭バイトの bit 6（0x20）が 1 なら、値の中身も TLV
struct BERTLVTests {
    @Test("1 バイトのタグ")
    func singleByteTag() throws {
        let objects = try BERTLV.parse(Data([0x80, 0x02, 0xAA, 0xBB]))

        #expect(objects == [BERTLV(tag: 0x80, value: Data([0xAA, 0xBB]))])
    }

    @Test("2 バイトのタグ")
    func twoByteTag() throws {
        let objects = try BERTLV.parse(Data([0x5F, 0x20, 0x01, 0x41]))

        #expect(objects == [BERTLV(tag: 0x5F20, value: Data([0x41]))])
    }

    @Test("3 バイトのタグと長さ 0")
    func threeByteTag() throws {
        let objects = try BERTLV.parse(Data([0x5F, 0x81, 0x01, 0x00]))

        #expect(objects == [BERTLV(tag: 0x5F8101, value: Data())])
    }

    @Test("長さ 81 の形式")
    func longLength81() throws {
        let objects = try BERTLV.parse(Data([0x04, 0x81, 0x80]) + Data(count: 128))

        #expect(objects.first?.value.count == 128)
    }

    @Test("長さ 82 の形式")
    func longLength82() throws {
        let objects = try BERTLV.parse(Data([0x04, 0x82, 0x01, 0x00]) + Data(count: 256))

        #expect(objects.first?.value.count == 256)
    }

    @Test("並んだ複数のデータオブジェクト")
    func sequence() throws {
        let objects = try BERTLV.parse(Data([0x80, 0x01, 0x01, 0x81, 0x01, 0x02]))

        #expect(objects == [
            BERTLV(tag: 0x80, value: Data([0x01])),
            BERTLV(tag: 0x81, value: Data([0x02]))
        ])
    }

    @Test("空のデータは空の配列")
    func empty() throws {
        #expect(try BERTLV.parse(Data()).isEmpty)
    }

    @Test("構造化タグの中身を読む")
    func children() throws {
        let objects = try BERTLV.parse(Data([0x30, 0x06, 0x02, 0x01, 0x05, 0x04, 0x01, 0xFF]))
        let children = try #require(objects.first).children()

        #expect(children == [
            BERTLV(tag: 0x02, value: Data([0x05])),
            BERTLV(tag: 0x04, value: Data([0xFF]))
        ])
    }

    @Test(
        "構造化かどうかは先頭バイトの bit 6 で決まる",
        arguments: [
            (UInt32(0x30), true),
            (UInt32(0x02), false),
            (UInt32(0x7F21), true),
            (UInt32(0x5F20), false)
        ]
    )
    func isConstructed(tag: UInt32, expected: Bool) {
        #expect(BERTLV(tag: tag, value: Data()).isConstructed == expected)
    }

    @Test("構造化出ないタグに children は使えない")
    func childrenOfPrimitive() {
        #expect(throws: BERTLVError.notConstructed) {
            try BERTLV(tag: 0x04, value: Data([0x01, 0x00])).children()
        }
    }

    @Test(
        "不正なデータはクラッシュせずにエラーになる",
        arguments: [
            ([0x00, 0x00], BERTLVError.invalidTag),
            ([0xFF, 0x00], .invalidTag),
            ([0x5F], .truncatedTag),
            ([0x5F, 0x1E, 0x00], .invalidTag),
            ([0x5F, 0x80, 0x00], .invalidTag),
            ([0x5F, 0x81], .truncatedTag),
            ([0x5F, 0x81, 0x81, 0x00], .invalidTag),
            ([0x04], .truncatedLength),
            ([0x04, 0x80], .invalidLength),
            ([0x04, 0x85, 0x00, 0x00, 0x00, 0x00, 0x00], .invalidLength),
            ([0x04, 0x82, 0x01], .truncatedLength),
            ([0x04, 0x03, 0x01], .truncatedValue),
            ([0x04, 0x84, 0xFF, 0xFF, 0xFF, 0xFF], .truncatedValue)
        ]
    )
    func malformed(bytes: [UInt8], expected: BERTLVError) {
        #expect(throws: expected) {
            try BERTLV.parse(Data(bytes))
        }
    }
}
