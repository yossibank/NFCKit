import MyNumberCardReader
import Observation

@MainActor
@Observable
final class CertificateViewModel {
    enum State: Equatable {
        case idle
        case reading
        case loaded(UserAuthenticationCertificate)
        case failed(String)
    }

    private(set) var state = State.idle

    private let reader = MyNumberCardReader()

    func read() async {
        state = .reading

        do {
            state = try await .loaded(reader.readUserAuthenticationCertificate())
        } catch {
            state = .failed(message(for: error))
        }
    }

    private func message(for error: MyNumberCardError) -> String {
        switch error {
        case .nfcUnavailable:
            "この端末は NFC を使えません"

        case .tagNotFound, .unsupportedCard:
            "マイナンバーカードを読み取れませんでした"

        case .connectionLost:
            "カードとの通信が切れました。カードを動かさずにもう一度お試しください"

        case .userCancelled:
            "キャンセルしました"

        case .timeout:
            "時間切れです。もう一度お試しください"

        case let .unexpectedResponse(statusWord):
            "予期しない応答です（\(String(statusWord, radix: 16, uppercase: true))）"

        case .incorrectPIN, .pinLocked, .pinAttemptsTooFew:
            "暗証番号のエラーです"

        @unknown default:
            "不明なエラーです"
        }
    }
}
