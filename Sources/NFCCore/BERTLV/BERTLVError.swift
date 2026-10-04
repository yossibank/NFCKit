import Foundation

package enum BERTLVError: Error, Equatable, Sendable {
    case truncatedTag
    case invalidTag
    case truncatedLength
    case invalidLength
    case truncatedValue
    case notConstructed
}
