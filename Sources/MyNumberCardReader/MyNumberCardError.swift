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
        self = switch error {
        case .readingUnavailable: .nfcUnavailable
        case .userCancelled: .userCancelled
        case .tagNotFound: .tagNotFound
        case .sessionTimedOut: .timeout
        case .connectionLost: .connectionLost
        case .unsupportedTag: .unsupportedCard
        }
    }

    init(_ error: CardSessionError<MyNumberCardError>) {
        self = switch error {
        case let .transport(error): MyNumberCardError(error)
        case let .operation(error): error
        }
    }
}
