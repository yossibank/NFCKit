import Foundation
import NFCCore
import NFCTransport
import NFCTransportMocks
import Testing

struct ScriptedCardTransportTests {
    @Test("台本の順に応答し、送ったコマンドを記録する")
    func respondsInOrder() async throws {
        let first = ResponseAPDU(data: Data([0x01]), statusWord: .success)
        let second = ResponseAPDU(statusWord: StatusWord(sw1: 0x63, sw2: 0xC3))
        let transport = ScriptedCardTransport(responses: [.success(first), .success(second)])
        let select = try CommandAPDU.select(efIdentifier: 0x0011)
        let verify = try CommandAPDU.verify(reference: 0x80)

        #expect(try await transport.transmit(select) == first)
        #expect(try await transport.transmit(verify) == second)
        #expect(await transport.sentCommands == [select, verify])
    }

    @Test("台本のエラーを投げる")
    func throwsScriptedError() async throws {
        let transport = ScriptedCardTransport(responses: [.failure(.userCancelled)])
        let command = try CommandAPDU.verify(reference: 0x80)

        await #expect(throws: TransportError.userCancelled) {
            try await transport.transmit(command)
        }
    }

    @Test("台本を使い切ったら通信切断")
    func exhausted() async throws {
        let transport = ScriptedCardTransport(responses: [])
        let command = try CommandAPDU.verify(reference: 0x80)

        await #expect(throws: TransportError.connectionLost) {
            try await transport.transmit(command)
        }

        #expect(await transport.sentCommands == [command])
    }
}

struct ScriptedCardSessionProviderTests {
    enum Failure: Error, Equatable {
        case aborted
    }

    @Test("処理の戻り値をそのまま返す")
    func returnsValue() async throws {
        let provider = ScriptedCardSessionProvider(
            transport: ScriptedCardTransport(
                responses: []
            )
        )

        let value = try await provider.withSession { _ throws(Failure) in
            42
        }

        #expect(value == 42)
    }

    @Test("セッションの失敗は transport を包む")
    func sessionFailure() async {
        let provider = ScriptedCardSessionProvider(
            transport: ScriptedCardTransport(responses: []),
            sessionFailure: .tagNotFound
        )

        await #expect(throws: CardSessionError<Failure>.transport(.tagNotFound)) {
            try await provider.withSession { _ throws(Failure) in
                42
            }
        }
    }

    @Test("処理のエラーは operation で包む")
    func operationFailure() async {
        let provider = ScriptedCardSessionProvider(
            transport: ScriptedCardTransport(
                responses: []
            )
        )

        await #expect(throws: CardSessionError<Failure>.operation(.aborted)) {
            try await provider.withSession { _ throws(Failure) in
                throw .aborted
            }
        }
    }
}
