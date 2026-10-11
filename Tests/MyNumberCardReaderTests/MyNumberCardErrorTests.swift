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
    func fromTransport(
        error: TransportError,
        expected: MyNumberCardError
    ) {
        let converted = MyNumberCardError(error)
        #expect(converted == expected)
    }

    @Test("セッションエラーを公開エラーに変換する")
    func fromSession() {
        let transportError = CardSessionError<MyNumberCardError>.transport(.connectionLost)
        let operationError = CardSessionError<MyNumberCardError>.operation(.pinLocked)

        let fromTransport = MyNumberCardError(transportError)
        let fromOperation = MyNumberCardError(operationError)

        #expect(fromTransport == .connectionLost)
        #expect(fromOperation == .pinLocked)
    }
}
