import Foundation

// 出典: RFC 5280 4.1（Certificate と TBSCertificate の構造）
package struct X509Certificate: Equatable, Sendable {
    package let serialNumber: Data
    package let issuer: String
    package let notAfter: Date

    package init(der: Data) throws(X509Error) {
        let objects = try Self.parse(der)

        guard
            objects.count == 1,
            let certificate = objects.first,
            certificate.tag == 0x30
        else {
            throw .invalidStructure
        }

        guard
            let tbsCertificate = try Self.children(of: certificate).first,
            tbsCertificate.tag == 0x30
        else {
            throw .invalidStructure
        }

        var fields = try Self.children(of: tbsCertificate)

        // 4.1.2.1（version は [0] で省略できる）
        if fields.first?.tag == 0xA0 {
            fields.removeFirst()
        }

        guard
            fields.count >= 4,
            fields[0].tag == 0x02,
            fields[2].tag == 0x30,
            fields[3].tag == 0x30
        else {
            throw .invalidStructure
        }

        let validity = try Self.children(of: fields[3])

        guard validity.count == 2 else {
            throw .invalidStructure
        }

        // 4.1.2.2（INTEGER の先頭の 00 は符号のためのもの）
        self.serialNumber = fields[0].value.count > 1 && fields[0].value.first == 0x00
            ? Data(fields[0].value.dropFirst())
            : fields[0].value

        self.issuer = try Self.distinguishedName(fields[2])
        self.notAfter = try Self.time(validity[1])
    }
}

private extension X509Certificate {
    static func parse(_ data: Data) throws(X509Error) -> [BERTLV] {
        do {
            return try BERTLV.parse(data)
        } catch {
            throw .invalidStructure
        }
    }

    static func children(of object: BERTLV) throws(X509Error) -> [BERTLV] {
        do {
            return try object.children()
        } catch {
            throw .invalidStructure
        }
    }

    // 4.1.2.4（Name は RDN の SET の並び。RDN は属性の種類（OID）と値の SEQUENCE）
    static func distinguishedName(_ name: BERTLV) throws(X509Error) -> String {
        var attributes: [String] = []

        for relativeName in try children(of: name) {
            for attribute in try children(of: relativeName) {
                let pair = try children(of: attribute)

                guard
                    pair.count == 2,
                    pair[0].tag == 0x06
                else {
                    throw .invalidStructure
                }

                // 出典: RFC 5280 Appendix A.1（id-at-countryName など）
                let type = switch pair[0].value {
                case Data([0x55, 0x04, 0x03]): "CN"
                case Data([0x55, 0x04, 0x06]): "C"
                case Data([0x55, 0x04, 0x0A]): "O"
                case Data([0x55, 0x04, 0x0B]): "OU"
                default: String?.none
                }

                if let type {
                    attributes.append("\(type)=\(String(decoding: pair[1].value, as: UTF8.self))")
                }
            }
        }

        return attributes.joined(separator: ", ")
    }

    // 4.1.2.5.1（UTCTime: YYMMDDHHMMSSZ、YY が 50 以上なら 19YY、未満なら 20YY）
    // 4.1.2.5.2（GeneralizedTime: YYYYMMDDHHMMSSZ）
    static func time(_ object: BERTLV) throws(X509Error) -> Date {
        let bytes = [UInt8](object.value)

        let yearDigits = switch (object.tag, bytes.count) {
        case (0x17, 13): 2
        case (0x18, 15): 4
        default: 0
        }

        guard
            yearDigits > 0,
            bytes.last == 0x5A,
            bytes.dropLast().allSatisfy({ (0x30...0x39).contains($0) })
        else {
            throw .invalidTime
        }

        let numbers = bytes.dropLast().map { Int($0 - 0x30) }

        func number(_ range: Range<Int>) -> Int {
            numbers[range].reduce(0) { $0 * 10 + $1 }
        }

        var year = number(0..<yearDigits)

        if yearDigits == 2 {
            year += year >= 50 ? 1900 : 2000
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt

        let components = DateComponents(
            calendar: calendar,
            year: year,
            month: number(yearDigits..<yearDigits + 2),
            day: number(yearDigits + 2..<yearDigits + 4),
            hour: number(yearDigits + 4..<yearDigits + 6),
            minute: number(yearDigits + 6..<yearDigits + 8),
            second: number(yearDigits + 8..<yearDigits + 10)
        )

        guard
            components.isValidDate,
            let date = components.date
        else {
            throw .invalidTime
        }

        return date
    }
}
