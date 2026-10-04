import Foundation

package enum APDUError: Error, Equatable, Sendable {
    case dataTooLong(Int)
    case expectedLengthOutOfRange(Int)
    case offsetOutOfRange(Int)
}
