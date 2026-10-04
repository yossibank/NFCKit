package import NFCTransport

public struct MyNumberCardReader: Sendable {
    let sessionProvider: any CardSessionProvider

    package init(sessionProvider: any CardSessionProvider) {
        self.sessionProvider = sessionProvider
    }
}
