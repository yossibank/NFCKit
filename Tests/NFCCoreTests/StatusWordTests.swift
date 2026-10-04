import NFCCore
import Testing

// ステータスワード（SW1-SW2）の意味（ISO/IEC 7816-4:2005 5.1.3 Table 5、Table 6）
// - 9000: 正常終了（全般）
// - 63CX: X（0〜15）をカウンタとして取り出す（VERIFY の残り試行回数）
// - 6983: 認証方法がブロックされている（PIN ロック）
// - 6A82: ファイルまたはアプリが見つからない（非対応カード）
// - それ以外: .other（予期しない応答）
struct StatusWordTests {
    @Test("9000 は正常終了")
    func success() {
        #expect(StatusWord(sw1: 0x90, sw2: 0x00).condition == .success)
    }

    @Test(
        "63CX は `X` をカウンタとして取り出す",
        arguments: [
            (UInt8(0xC0), 0),
            (UInt8(0xC3), 3),
            (UInt8(0xCF), 15)
        ]
    )
    func counter(sw2: UInt8, expected: Int) {
        #expect(StatusWord(sw1: 0x63, sw2: sw2).condition == .counter(expected))
    }

    @Test(
        "63CX の範囲外はカウンタにしない",
        arguments: [
            UInt8(0xBF),
            UInt8(0xD0)
        ]
    )
    func outsideCounter(sw2: UInt8) {
        #expect(StatusWord(sw1: 0x63, sw2: sw2).condition == .other)
    }

    @Test("6983 は認証方法のブロック")
    func blocked() {
        #expect(StatusWord(sw1: 0x69, sw2: 0x83).condition == .authenticationMethodBlocked)
    }

    @Test("6A82 はファイルかアプリが見つからない")
    func notFound() {
        #expect(StatusWord(sw1: 0x6A, sw2: 0x82).condition == .fileOrApplicationNotFound)
    }

    @Test("SW1 と SW2 を 16 ビットにまとめる")
    func rawValue() {
        #expect(StatusWord(sw1: 0x63, sw2: 0xC2).rawValue == 0x63C2)
    }
}
