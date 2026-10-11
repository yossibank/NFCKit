internal import NFCCore
import Foundation

public struct UserAuthenticationCertificate: Equatable, Sendable {
    public let issuer: String
    public let notAfter: Date
    public let serialNumber: String
}

extension UserAuthenticationCertificate {
    init(_ certificate: X509Certificate) {
        self.issuer = certificate.issuer
        self.notAfter = certificate.notAfter
        self.serialNumber = certificate.serialNumber
            .map { String(format: "%02X", $0) }
            .joined()
    }
}

extension UserAuthenticationCertificate: CustomStringConvertible {
    public var description: String {
        "UserAuthenticationCertificate(****)"
    }
}

extension UserAuthenticationCertificate: CustomReflectable {
    public var customMirror: Mirror {
        Mirror(self, children: [:])
    }
}
