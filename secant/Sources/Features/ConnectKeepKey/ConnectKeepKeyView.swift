//
//  ConnectKeepKeyView.swift
//  Zashi
//

import SwiftUI
import ComposableArchitecture

struct ConnectKeepKeyView: View {
    @Environment(\.colorScheme) private var colorScheme

    @Perception.Bindable var store: StoreOf<ConnectKeepKey>

    init(store: StoreOf<ConnectKeepKey>) {
        self.store = store
    }

    var body: some View {
        WithPerceptionTracking {
            VStack(alignment: .center, spacing: 0) {
                Text(localizable: .keepkeyAddHWWalletWalletConnectPairing)
                    .zFont(.semiBold, size: 24, style: Design.Text.primary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 40)
                    .padding(.bottom, 12)

                switch store.connectionStatus {
                case .waitingForPairingURI:
                    waitingView()

                case .showingQR(let uri), .waitingForApproval(let uri):
                    qrView(uri: uri)

                case .failed(let reason):
                    failedView(reason: reason)
                }

                Spacer()

                ZashiButton(String(localizable: .generalCancel)) {
                    store.send(.cancelTapped)
                }
                .padding(.bottom, 24)
            }
            .screenHorizontalPadding()
            .applyScreenBackground()
            .onAppear { store.send(.onAppear) }
            .navigationBarTitleDisplayMode(.inline)
            .zashiBack()
            .screenTitle(String(localizable: .keepkeyAddHWWalletTitle))
        }
    }

    @ViewBuilder private func waitingView() -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .padding(.top, 60)

            Text(localizable: .keepkeyAddHWWalletWalletConnectDesc)
                .zFont(size: 14, style: Design.Text.tertiary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder private func qrView(uri: String) -> some View {
        VStack(spacing: 0) {
            QRCodeViewRepresentable(qrText: uri)
                .frame(width: 220, height: 220)
                .padding(.top, 32)
                .padding(.bottom, 16)

            Text(localizable: .keepkeyAddHWWalletWalletConnectDesc)
                .zFont(size: 14, style: Design.Text.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            Text(localizable: .keepkeyAddHWWalletWaitingForApproval)
                .zFont(.semiBold, size: 14, style: Design.Text.primary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
    }

    @ViewBuilder private func failedView(reason: String) -> some View {
        VStack(spacing: 16) {
            Asset.Assets.Icons.alertOutline.image
                .zImage(size: 40, style: Design.Utility.ErrorRed._500)
                .padding(.top, 40)

            Text(reason)
                .zFont(size: 14, style: Design.Text.tertiary)
                .multilineTextAlignment(.center)

            ZashiButton(String(localizable: .disconnectHWWalletTryAgain), type: .secondary) {
                store.send(.retryTapped)
            }
        }
    }
}

// MARK: - QR Code helper

private struct QRCodeViewRepresentable: UIViewRepresentable {
    let qrText: String

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        return view
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return }
        let data = Data(qrText.utf8)
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let outputImage = filter.outputImage else { return }
        let scale = 10.0
        let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let cgImage = CIContext().createCGImage(transformed, from: transformed.extent)
        uiView.image = cgImage.map(UIImage.init)
    }
}

// MARK: - Previews

#Preview {
    NavigationView {
        ConnectKeepKeyView(store: .initial)
    }
}

// MARK: - Placeholders

extension ConnectKeepKey.State {
    static let initial = ConnectKeepKey.State()
}

extension StoreOf<ConnectKeepKey> {
    @MainActor static let initial = StoreOf<ConnectKeepKey>(
        initialState: .initial
    ) {
        ConnectKeepKey()
    }
}
