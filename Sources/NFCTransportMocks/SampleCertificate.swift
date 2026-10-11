import Foundation

package enum SampleCertificate {}

package extension SampleCertificate {
    static func der(
        serialNumber: [UInt8] = [0x1A, 0x2B, 0x3C, 0x4D],
        notAfter: (tag: UInt8, value: String) = (0x17, "310101000000Z")
    ) -> Data {
        let signatureAlgorithm = tlv(0x06, [0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x0B])
        let algorithm = tlv(0x30, signatureAlgorithm + tlv(0x05, []))

        let issuer = tlv(
            0x30,
            name([0x55, 0x04, 0x06], "JP")
                + name([0x55, 0x04, 0x0A], "JPKI")
                + name([0x55, 0x04, 0x0B], "JPKI for user authentication")
        )

        let notBefore = tlv(0x17, Array("260101000000Z".utf8))
        let notAfterTime = tlv(notAfter.tag, Array(notAfter.value.utf8))
        let validity = tlv(0x30, notBefore + notAfterTime)
        let version = tlv(0xA0, tlv(0x02, [0x02]))
        let serial = tlv(0x02, serialNumber)
        let subject = tlv(0x30, [])
        let tbsCertificate = tlv(0x30, version + serial + algorithm + issuer + validity + subject)
        let signature = tlv(0x03, [0x00] + Array(repeating: 0x00, count: 256))
        let certificate = tlv(0x30, tbsCertificate + algorithm + signature)

        return Data(certificate)
    }
}

private extension SampleCertificate {
    static func name(
        _ type: [UInt8],
        _ value: String
    ) -> [UInt8] {
        tlv(0x31, tlv(0x30, tlv(0x06, type) + tlv(0x13, Array(value.utf8))))
    }

    static func tlv(
        _ tag: UInt8,
        _ value: [UInt8]
    ) -> [UInt8] {
        let length: [UInt8] = switch value.count {
        case ..<0x80: [UInt8(value.count)]
        case ..<0x100: [0x81, UInt8(value.count)]
        default: [0x82, UInt8(value.count >> 8), UInt8(value.count & 0xFF)]
        }

        return [tag] + length + value
    }
}
