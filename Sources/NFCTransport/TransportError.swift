import Foundation

package enum TransportError: Error, Equatable, Sendable {
    case readingUnavailable
    case userCancelled
    case tagNotFound
    case sessionTimedOut
    case connectionLost
    case unsupportedTag
}
