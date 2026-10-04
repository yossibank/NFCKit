public struct CardInfoInputPIN: Sendable {
    let value: String

    public init?(_ digits: String) {
        guard
            digits.utf8.count == 4,
            digits.utf8.allSatisfy({ (0x30...0x39).contains($0) })
        else {
            return nil
        }

        self.value = digits
    }
}

extension CardInfoInputPIN: CustomStringConvertible, CustomReflectable {
    public var description: String {
        "****"
    }

    public var customMirror: Mirror {
        Mirror(self, children: [:])
    }
}
