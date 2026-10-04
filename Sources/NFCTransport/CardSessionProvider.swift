package protocol CardSessionProvider: Sendable {
    func withSession<T: Sendable, Failure: Error>(
        _ operation: (any CardTransport) async throws(Failure) -> T
    ) async throws(CardSessionError<Failure>) -> T
}

package enum CardSessionError<Failure: Error>: Error {
    case transport(TransportError)
    case operation(Failure)
}

extension CardSessionError: Equatable where Failure: Equatable {}
