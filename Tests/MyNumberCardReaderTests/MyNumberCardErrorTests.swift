@testable import MyNumberCardReader
import NFCTransport
import Testing

struct MyNumberCardErrorTests {
    @Test(
        "通信層のエラーを公開エラーに変換する",
        arguments: [
            (TransportError.readingUnavailable, MyNumberCardError.nfcUnavailable),
            (.userCancelled, .userCancelled),
            (.tagNotFound, .tagNotFound),
            (.sessionTimedOut, .timeout),
            (.connectionLost, .connectionLost),
            (.unsupportedTag, .unsupportedCard)
        ]
    )
    func fromTransport(error: TransportError, expected: MyNumberCardError) {
        #expect(MyNumberCardError(error) == expected)
    }

    @Test("セッションエラーを公開エラーに変換する")
    func fromSession() {
        #expect(
            MyNumberCardError(CardSessionError<MyNumberCardError>.transport(.connectionLost)) == .connectionLost
        )

        #expect(
            MyNumberCardError(CardSessionError.operation(MyNumberCardError.pinLocked)) == .pinLocked
        )
    }
}
