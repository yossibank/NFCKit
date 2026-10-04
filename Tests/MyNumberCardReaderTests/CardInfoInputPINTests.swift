import MyNumberCardReader
import Testing

struct CardInfoInputPINTests {
    @Test("4 桁の半角数字だけ受け付ける")
    func valid() {
        #expect(CardInfoInputPIN("0123") != nil)
    }

    @Test(
        "4 桁の半角数字以外は受け付けない",
        arguments: [
            "123",
            "12345",
            "12a4",
            "1 2 3 4",
            "1\u{0301}234"
        ]
    )
    func invalid(digits: String) {
        #expect(CardInfoInputPIN(digits) == nil)
    }

    @Test("文字列にしても値が出ない")
    func description() throws {
        let pin = try #require(CardInfoInputPIN("1234"))

        #expect("\(pin)" == "****")
        #expect(String(reflecting: pin) == "****")
    }

    @Test("dump しても値が出ない")
    func dumpOutput() throws {
        let pin = try #require(CardInfoInputPIN("1234"))

        var output = ""

        dump(pin, to: &output)

        #expect(!output.contains("1234"))
    }
}
