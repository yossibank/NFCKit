import Foundation

// 出典: ISO/IEC 7816-4:2005 5.2.2(タグは 1~3 バイト、長さは 1~5 バイト、不定長は使わない)
package struct BERTLV: Equatable, Sendable {
    package var isConstructed: Bool {
        var firstByte = tag

        while firstByte > 0xFF {
            firstByte >>= 8
        }

        return firstByte & 0x20 != 0
    }

    package let tag: UInt32
    package let value: Data

    package init(tag: UInt32, value: Data) {
        self.tag = tag
        self.value = value
    }

    package static func parse(_ data: Data) throws(BERTLVError) -> [BERTLV] {
        let bytes = [UInt8](data)

        var index = 0
        var objects: [BERTLV] = []

        while index < bytes.count {
            let tag = try readTag(bytes, at: &index)
            let length = try readLength(bytes, at: &index)

            guard length <= bytes.count - index else {
                throw .truncatedValue
            }

            objects.append(
                BERTLV(
                    tag: tag,
                    value: Data(bytes[index..<index + length])
                )
            )

            index += length
        }

        return objects
    }

    package func children() throws(BERTLVError) -> [BERTLV] {
        guard isConstructed else {
            throw .notConstructed
        }

        return try BERTLV.parse(value)
    }
}

private extension BERTLV {
    static func readTag(_ bytes: [UInt8], at index: inout Int) throws(BERTLVError) -> UInt32 {
        let first = bytes[index]
        index += 1

        guard first != 0x00, first != 0xFF else {
            throw .invalidTag
        }

        guard first & 0x1F == 0x1F else {
            return UInt32(first)
        }

        guard index < bytes.count else {
            throw .truncatedTag
        }

        let second = bytes[index]
        index += 1

        guard second >= 0x1F, second != 0x80 else {
            throw .invalidTag
        }

        guard second & 0x80 != 0 else {
            return UInt32(first) << 8 | UInt32(second)
        }

        guard index < bytes.count else {
            throw .truncatedTag
        }

        let third = bytes[index]
        index += 1

        guard third & 0x80 == 0 else {
            throw .invalidTag
        }

        return UInt32(first) << 16 | UInt32(second) << 8 | UInt32(third)
    }

    static func readLength(_ bytes: [UInt8], at index: inout Int) throws(BERTLVError) -> Int {
        guard index < bytes.count else {
            throw .truncatedLength
        }

        let first = bytes[index]
        index += 1

        guard first & 0x80 != 0 else {
            return Int(first)
        }

        let count = Int(first & 0x7F)

        guard (1...4).contains(count) else {
            throw .invalidLength
        }

        guard count <= bytes.count - index else {
            throw .truncatedLength
        }

        let length = bytes[index..<index + count].reduce(0) { $0 << 8 | Int($1) }
        index += count

        return length
    }
}
