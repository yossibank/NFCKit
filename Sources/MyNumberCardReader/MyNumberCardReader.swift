import Foundation
internal import NFCCore
package import NFCTransport

public struct MyNumberCardReader: Sendable {
    let sessionProvider: any CardSessionProvider

    package init(sessionProvider: any CardSessionProvider) {
        self.sessionProvider = sessionProvider
    }

    #if canImport(CoreNFC)
    public init() {
        self.init(
            sessionProvider: CoreNFCSessionProvider(
                alertMessage: "マイナンバーカードを iPhone の上部にかざしてください"
            )
        )
    }
    #endif

    public func readUserAuthenticationCertificate() async throws(MyNumberCardError) -> UserAuthenticationCertificate {
        let der: Data

        do {
            der = try await sessionProvider.withSession { transport throws(MyNumberCardError) in
                // 出典: OpenSC src/libopensc/jpki.h（AID_JPKI）、pkcs15-jpki.c（User Authentication Certificate = 000A）
                // TODO: J-LIS の公開仕様では未確認
                try await select(dfName: Data([0xD3, 0x92, 0xF0, 0x00, 0x26, 0x01, 0x00, 0x00, 0x00, 0x01]), via: transport)
                try await select(efIdentifier: 0x000A, via: transport)

                return try await readCertificate(via: transport)
            }
        } catch {
            throw MyNumberCardError(error)
        }

        do {
            return UserAuthenticationCertificate(try X509Certificate(der: der))
        } catch {
            throw .unsupportedCard
        }
    }
}

private extension MyNumberCardReader {
    func select(dfName: Data, via transport: any CardTransport) async throws(MyNumberCardError) {
        try await send(command { () throws(APDUError) in try .select(dfName: dfName) }, via: transport)
    }

    func select(efIdentifier: UInt16, via transport: any CardTransport) async throws(MyNumberCardError) {
        try await send(command { () throws(APDUError) in try .select(efIdentifier: efIdentifier) }, via: transport)
    }

    func readCertificate(via transport: any CardTransport) async throws(MyNumberCardError) -> Data {
        let header = [UInt8](try await readBinary(offset: 0, length: 4, via: transport))

        guard
            header.count == 4,
            header[0] == 0x30,
            header[1] == 0x82
        else {
            throw .unsupportedCard
        }

        let total = 4 + (Int(header[2]) << 8 | Int(header[3]))
        var data = Data(header)

        while data.count < total {
            let chunk = try await readBinary(
                offset: data.count,
                length: min(255, total - data.count),
                via: transport
            )

            guard !chunk.isEmpty else {
                throw .unsupportedCard
            }

            data.append(chunk)
        }

        return data
    }

    func readBinary(offset: Int, length: Int, via transport: any CardTransport) async throws(MyNumberCardError) -> Data {
        let readBinary = try command { () throws(APDUError) in
            try .readBinary(offset: offset, expectedLength: length)
        }

        return try await send(readBinary, via: transport).data
    }

    func command(_ make: () throws(APDUError) -> CommandAPDU) throws(MyNumberCardError) -> CommandAPDU {
        do {
            return try make()
        } catch {
            throw .unsupportedCard
        }
    }

    @discardableResult
    func send(_ command: CommandAPDU, via transport: any CardTransport) async throws(MyNumberCardError) -> ResponseAPDU {
        let response: ResponseAPDU

        do {
            response = try await transport.transmit(command)
        } catch {
            throw MyNumberCardError(error)
        }

        switch response.statusWord.condition {
        case .success:
            return response

        case .fileOrApplicationNotFound:
            throw .unsupportedCard

        default:
            throw .unexpectedResponse(statusWord: response.statusWord.rawValue)
        }
    }
}
