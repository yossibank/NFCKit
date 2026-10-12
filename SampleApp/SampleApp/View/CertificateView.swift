import MyNumberCardReader
import SwiftUI

struct CertificateView: View {
    @State private var viewModel = CertificateViewModel()

    var body: some View {
        List {
            switch viewModel.state {
            case .idle:
                Text("カードをかざすと、発行者・有効期限・シリアル番号を表示します")

            case .reading:
                ProgressView()

            case let .loaded(certificate):
                LabeledContent("発行者", value: certificate.issuer)
                LabeledContent(
                    "有効期限",
                    value: certificate.notAfter.formatted(date: .long, time: .omitted)
                )
                LabeledContent("シリアル番号", value: certificate.serialNumber)

            case let .failed(message):
                Text(message)
                    .foregroundStyle(.red)
            }
        }
        .navigationTitle("利用者証明用電子証明書")
        .toolbar {
            Button("読み取る") {
                Task {
                    await viewModel.read()
                }
            }
            .disabled(viewModel.state == .reading)
        }
    }
}
