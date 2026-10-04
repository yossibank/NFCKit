internal import NFCTransport

public enum MyNumberCardError: Error, Equatable, Sendable {
    case nfcUnavailable
    case tagNotFound
    case unsupportedCard
    case incorrectPIN(remainingAttempts: Int)
    case pinLocked
    case pinAttemptsTooFew(remainingAttempts: Int)
    case connectionLost
    case userCancelled
    case timeout
    case unexpectedResponse(statusWord: UInt16)
}

extension MyNumberCardError {
    init(_ error: TransportError) {
        switch error {
        case .readingUnavailable:
            self = .nfcUnavailable

        case .userCancelled:
            self = .userCancelled

        case .tagNotFound:
            self = .tagNotFound

        case .sessionTimedOut:
            self = .timeout

        case .connectionLost:
            self = .connectionLost

        case .unsupportedTag:
            self = .unsupportedCard
        }
    }

    init(_ error: CardSessionError<MyNumberCardError>) {
        switch error {
        case let .transport(error):
            self.init(error)

        case let .operation(error):
            self = error
        }
    }
}
