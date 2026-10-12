import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("利用者証明用電子証明書") {
                    CertificateView()
                }
            }
            .navigationTitle("NFCKit")
        }
    }
}
