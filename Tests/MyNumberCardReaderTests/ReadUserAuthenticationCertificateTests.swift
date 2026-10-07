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
        let reader = MyNumberCardReader(sessionProvider: ScriptedCardSessionProvider(transport: transport))

        let certificate = try await reader.readUserAuthenticationCertificate()

        #expect(certificate.issuer == "C=JP, O=JPKI, OU=JPKI for user authentication")
        #expect(certificate.notAfter == (try? Date("2031-01-01T00:00:00Z", strategy: .iso8601)))
        #expect(certificate.serialNumber == "1A2B3C4D")
    }

    @Test("AP と EF を選び、先頭 4 バイトの後は 255 バイトずつ読む")
    func commands() async throws {
        let transport = ScriptedCardTransport(responses: successResponses())
        let reader = MyNumberCardReader(sessionProvider: ScriptedCardSessionProvider(transport: transport))

        _ = try await reader.readUserAuthenticationCertificate()

        #expect(await transport.sentCommands == [
            try .select(dfName: Data([0xD3, 0x92, 0xF0, 0x00, 0x26, 0x01, 0x00, 0x00, 0x00, 0x01])),
            try .select(efIdentifier: 0x000A),
            try .readBinary(offset: 0, expectedLength: 4),
            try .readBinary(offset: 4, expectedLength: 255),
            try .readBinary(offset: 259, expectedLength: der.count - 259)
        ])
    }

    @Test("VERIFY を一度も送らない")
    func noVerify() async throws {
        let transport = ScriptedCardTransport(responses: successResponses())
        let reader = MyNumberCardReader(sessionProvider: ScriptedCardSessionProvider(transport: transport))

        _ = try await reader.readUserAuthenticationCertificate()

        #expect(await transport.sentCommands.allSatisfy { $0.ins != 0x20 })
    }

    @Test(
        "ステータスワードを公開エラーに変換する",
        arguments: [
            (StatusWord(sw1: 0x6A, sw2: 0x82), MyNumberCardError.unsupportedCard),
            (StatusWord(sw1: 0x69, sw2: 0x82), MyNumberCardError.unexpectedResponse(statusWord: 0x6982))
        ]
    )
    func statusWord(statusWord: StatusWord, expected: MyNumberCardError) async {
        let transport = ScriptedCardTransport(responses: [
            .success(ResponseAPDU(statusWord: .success)),
            .success(ResponseAPDU(statusWord: .success)),
            .success(ResponseAPDU(statusWord: statusWord))
        ])
        let reader = MyNumberCardReader(sessionProvider: ScriptedCardSessionProvider(transport: transport))

        await #expect(throws: expected) {
            try await reader.readUserAuthenticationCertificate()
        }
    }

    @Test("通信が途中で切れたら connectionLost")
    func connectionLost() async {
        let transport = ScriptedCardTransport(responses: Array(successResponses().prefix(3)) + [.failure(.connectionLost)])
        let reader = MyNumberCardReader(sessionProvider: ScriptedCardSessionProvider(transport: transport))

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
        let transport = ScriptedCardTransport(responses: [
            .success(ResponseAPDU(statusWord: .success)),
            .success(ResponseAPDU(statusWord: .success)),
            .success(ResponseAPDU(data: data.prefix(4), statusWord: .success)),
            .success(ResponseAPDU(data: data.dropFirst(4), statusWord: .success))
        ])
        let reader = MyNumberCardReader(sessionProvider: ScriptedCardSessionProvider(transport: transport))

        await #expect(throws: MyNumberCardError.unsupportedCard) {
            try await reader.readUserAuthenticationCertificate()
        }
    }

    @Test("print や dump に中身を出さない")
    func masked() async throws {
        let transport = ScriptedCardTransport(responses: successResponses())
        let reader = MyNumberCardReader(sessionProvider: ScriptedCardSessionProvider(transport: transport))
        let certificate = try await reader.readUserAuthenticationCertificate()

        var dumped = ""
        dump(certificate, to: &dumped)

        #expect("\(certificate)" == "UserAuthenticationCertificate(****)")
        #expect(!dumped.contains("1A2B3C4D"))
    }

    private func successResponses() -> [Result<ResponseAPDU, TransportError>] {
        [
            .success(ResponseAPDU(statusWord: .success)),
            .success(ResponseAPDU(statusWord: .success)),
            .success(ResponseAPDU(data: der[0..<4], statusWord: .success)),
            .success(ResponseAPDU(data: der[4..<259], statusWord: .success)),
            .success(ResponseAPDU(data: der[259...], statusWord: .success))
        ]
    }
}
