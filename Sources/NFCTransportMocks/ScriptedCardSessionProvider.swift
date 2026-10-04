import NFCTransport

package struct ScriptedCardSessionProvider: CardSessionProvider {
    package let transport: ScriptedCardTransport
    package let sessionFailure: TransportError?

    package init(
        transport: ScriptedCardTransport,
        sessionFailure: TransportError? = nil
    ) {
        self.transport = transport
        self.sessionFailure = sessionFailure
    }

    // 「開始 → 検出 → 接続 → 処理 → 切断」をメソッド内に閉じ込める
    // 処理が途中で失敗しても切断を忘れることがない
    package func withSession<T: Sendable, Failure: Error>(
        _ operation: (any CardTransport) async throws(Failure) -> T
    ) async throws(CardSessionError<Failure>) -> T {
        if let sessionFailure {
            throw .transport(sessionFailure)
        }

        do {
            return try await operation(transport)
        } catch {
            throw .operation(error)
        }
    }
}
