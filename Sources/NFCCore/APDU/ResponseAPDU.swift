import Foundation

package struct ResponseAPDU: Equatable, Sendable {
    package let data: Data
    package let statusWord: StatusWord

    package init(data: Data = Data(), statusWord: StatusWord) {
        self.data = data
        self.statusWord = statusWord
    }
}
