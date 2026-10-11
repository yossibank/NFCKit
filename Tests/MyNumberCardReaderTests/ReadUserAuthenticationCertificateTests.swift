import Foundation
import MyNumberCardReader
import NFCCore
import NFCTransport
import NFCTransportMocks
import Testing

struct ReadUserAuthenticationCertificateTests {
    private let der = SampleCertificate.der()

    @Test("証明書を読み、発行者・有効期限・シリアル番号を返す")
    func read() async throws {
        let transport = ScriptedCardTransport(responses: successResponses())
        let reader = makeReader(transport)
        let notAfter = try? Date("2031-01-01T00:00:00Z", strategy: .iso8601)

        let certificate = try await reader.readUserAuthenticationCertificate()

        #expect(certificate.issuer == "C=JP, O=JPKI, OU=JPKI for user authentication")
        #expect(certificate.notAfter == notAfter)
        #expect(certificate.serialNumber == "1A2B3C4D")
    }

    @Test("AP と EF を選び、先頭 4 バイトの後は 255 バイトずつ読む")
    func commands() async throws {
        let transport = ScriptedCardTransport(responses: successResponses())
        let reader = makeReader(transport)
        let jpki = Data([0xD3, 0x92, 0xF0, 0x00, 0x26, 0x01, 0x00, 0x00, 0x00, 0x01])

        let expected: [CommandAPDU] = try [
            .select(dfName: jpki),
            .select(efIdentifier: 0x000A),
            .readBinary(offset: 0, expectedLength: 4),
            .readBinary(offset: 4, expectedLength: 255),
            .readBinary(offset: 259, expectedLength: der.count - 259)
        ]

        _ = try await reader.readUserAuthenticationCertificate()
        let sent = await transport.sentCommands

        #expect(sent == expected)
    }

    @Test("VERIFY を一度も送らない")
    func noVerify() async throws {
        let transport = ScriptedCardTransport(responses: successResponses())
        let reader = makeReader(transport)

        _ = try await reader.readUserAuthenticationCertificate()
        let sent = await transport.sentCommands

        #expect(sent.allSatisfy { $0.ins != 0x20 })
    }

    @Test(
        "ステータスワードを公開エラーに変換する",
        arguments: [
            (UInt16(0x6A82), MyNumberCardError.unsupportedCard),
            (UInt16(0x6982), MyNumberCardError.unexpectedResponse(statusWord: 0x6982))
        ]
    )
    func statusWord(
        rawValue: UInt16,
        expected: MyNumberCardError
    ) async {
        let statusWord = StatusWord(sw1: UInt8(rawValue >> 8), sw2: UInt8(rawValue & 0xFF))
        let responses = [success(), success(), success(statusWord)]
        let transport = ScriptedCardTransport(responses: responses)
        let reader = makeReader(transport)

        await #expect(throws: expected) {
            try await reader.readUserAuthenticationCertificate()
        }
    }

    @Test("通信が途中で切れたら connectionLost")
    func connectionLost() async {
        let responses = Array(successResponses().prefix(3)) + [.failure(.connectionLost)]
        let transport = ScriptedCardTransport(responses: responses)
        let reader = makeReader(transport)

        await #expect(throws: MyNumberCardError.connectionLost) {
            try await reader.readUserAuthenticationCertificate()
        }
    }

    @Test(
        "証明書として読めないデータは unsupportedCard",
        arguments: [
            Data([0x30, 0x81, 0x01, 0x00]),
            Data([0x30, 0x82]),
            Data([0x30, 0x82, 0x00, 0x02]),
            Data([0x30, 0x82, 0x00, 0x02, 0x05, 0x00])
        ]
    )
    func invalidCertificate(data: Data) async {
        let responses = [success(), success(), success(data.prefix(4)), success(data.dropFirst(4))]
        let transport = ScriptedCardTransport(responses: responses)
        let reader = makeReader(transport)

        await #expect(throws: MyNumberCardError.unsupportedCard) {
            try await reader.readUserAuthenticationCertificate()
        }
    }

    @Test("print や dump に中身を出さない")
    func masked() async throws {
        let transport = ScriptedCardTransport(responses: successResponses())
        let reader = makeReader(transport)
        let certificate = try await reader.readUserAuthenticationCertificate()
        var dumped = ""

        dump(certificate, to: &dumped)
        let text = "\(certificate)"

        #expect(text == "UserAuthenticationCertificate(****)")
        #expect(!dumped.contains("1A2B3C4D"))
    }
}

private extension ReadUserAuthenticationCertificateTests {
    func makeReader(_ transport: ScriptedCardTransport) -> MyNumberCardReader {
        let provider = ScriptedCardSessionProvider(transport: transport)
        return MyNumberCardReader(sessionProvider: provider)
    }

    func successResponses() -> [Result<ResponseAPDU, TransportError>] {
        [
            success(),
            success(),
            success(der[0..<4]),
            success(der[4..<259]),
            success(der[259...])
        ]
    }

    func success(_ data: Data = Data()) -> Result<ResponseAPDU, TransportError> {
        let response = ResponseAPDU(data: data, statusWord: .success)
        return .success(response)
    }

    func success(_ statusWord: StatusWord) -> Result<ResponseAPDU, TransportError> {
        let response = ResponseAPDU(statusWord: statusWord)
        return .success(response)
    }
}
