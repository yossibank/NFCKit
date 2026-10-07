import Foundation
import NFCCore
import NFCTransportMocks
import Testing

struct X509CertificateTests {
    @Test("シリアル番号・発行者・有効期限の終わりを取り出す")
    func parse() throws {
        let certificate = try X509Certificate(der: SampleCertificate.der())

        #expect(certificate.serialNumber == Data([0x1A, 0x2B, 0x3C, 0x4D]))
        #expect(certificate.issuer == "C=JP, O=JPKI, OU=JPKI for user authentication")
        #expect(certificate.notAfter == date("2031-01-01T00:00:00Z"))
    }

    @Test("シリアル番号の先頭の 00 は取り除く")
    func serialNumberSignByte() throws {
        let certificate = try X509Certificate(der: SampleCertificate.der(serialNumber: [0x00, 0x80]))

        #expect(certificate.serialNumber == Data([0x80]))
    }

    @Test(
        "UTCTime の年は 50 を境に 19XX と 20XX に分かれる",
        arguments: [
            ("491231235959Z", "2049-12-31T23:59:59Z"),
            ("500101000000Z", "1950-01-01T00:00:00Z")
        ]
    )
    func utcTime(value: String, expected: String) throws {
        let certificate = try X509Certificate(der: SampleCertificate.der(notAfter: (0x17, value)))

        #expect(certificate.notAfter == date(expected))
    }

    @Test("GeneralizedTime は 4 桁の年")
    func generalizedTime() throws {
        let certificate = try X509Certificate(der: SampleCertificate.der(notAfter: (0x18, "20500101000000Z")))

        #expect(certificate.notAfter == date("2050-01-01T00:00:00Z"))
    }

    @Test(
        "不正な時刻はエラー",
        arguments: [
            (UInt8(0x17), "310101000000"),
            (UInt8(0x17), "3101010000000Z"),
            (UInt8(0x17), "31A101000000Z"),
            (UInt8(0x17), "311301000000Z"),
            (UInt8(0x04), "310101000000Z")
        ]
    )
    func invalidTime(tag: UInt8, value: String) {
        #expect(throws: X509Error.invalidTime) {
            try X509Certificate(der: SampleCertificate.der(notAfter: (tag, value)))
        }
    }

    @Test(
        "構造が違うときはエラー",
        arguments: [
            Data(),
            Data([0x02, 0x01, 0x00]),
            Data([0x30, 0x03, 0x02, 0x01, 0x00]),
            Data([0x30, 0x82, 0x01])
        ]
    )
    func invalidStructure(der: Data) {
        #expect(throws: X509Error.invalidStructure) {
            try X509Certificate(der: der)
        }
    }

    private func date(_ string: String) -> Date? {
        try? Date(string, strategy: .iso8601)
    }
}
