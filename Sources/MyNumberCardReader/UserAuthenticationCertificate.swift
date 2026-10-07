import Foundation
internal import NFCCore

public struct UserAuthenticationCertificate: Equatable, Sendable {
    public let issuer: String
    public let notAfter: Date
    public let serialNumber: String

    init(_ certificate: X509Certificate) {
        self.issuer = certificate.issuer
        self.notAfter = certificate.notAfter
        self.serialNumber = certificate.serialNumber
            .map { String(format: "%02X", $0) }
            .joined()
    }
}

extension UserAuthenticationCertificate: CustomStringConvertible, CustomReflectable {
    public var description: String {
        "UserAuthenticationCertificate(****)"
    }

    public var customMirror: Mirror {
        Mirror(self, children: [:])
    }
}
