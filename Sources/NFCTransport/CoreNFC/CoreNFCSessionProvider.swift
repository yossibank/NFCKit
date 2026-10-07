#if canImport(CoreNFC)
import CoreNFC
import NFCCore

package struct CoreNFCSessionProvider: CardSessionProvider {
    let alertMessage: String

    package init(alertMessage: String) {
        self.alertMessage = alertMessage
    }

    package func withSession<T: Sendable, Failure: Error>(
        _ operation: (any CardTransport) async throws(Failure) -> T
    ) async throws(CardSessionError<Failure>) -> T {
        guard NFCTagReaderSession.readingAvailable else {
            throw .transport(.readingUnavailable)
        }

        let connection = await NFCConnection()

        do {
            try await connection.begin(alertMessage: alertMessage)
        } catch {
            await connection.end(errorMessage: "マイナンバーカードを読み取れませんでした")
            throw .transport(error)
        }

        do {
            let value = try await operation(CoreNFCTransport(connection: connection))
            await connection.end(errorMessage: nil)
            return value
        } catch {
            await connection.end(errorMessage: "読み取りに失敗しました")
            throw .operation(error)
        }
    }
}

struct CoreNFCTransport: CardTransport {
    let connection: NFCConnection

    func transmit(_ command: CommandAPDU) async throws(TransportError) -> ResponseAPDU {
        try await connection.transmit(command)
    }
}

#endif

