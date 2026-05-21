//
//  AddKeepKeyHWWalletView.swift
//  Zashi
//

import SwiftUI
import ComposableArchitecture

struct AddKeepKeyHWWalletView: View {
    @Perception.Bindable var store: StoreOf<AddKeepKeyHWWallet>

    init(store: StoreOf<AddKeepKeyHWWallet>) {
        self.store = store
    }

    var body: some View {
        WithPerceptionTracking {
            VStack(alignment: .leading, spacing: 0) {
                Text(localizable: .keepkeyAddHWWalletTitle)
                    .zFont(.semiBold, size: 24, style: Design.Text.primary)
                    .padding(.top, 24)

                Text(localizable: .keepkeyAddHWWalletDesc)
                    .zFont(size: 14, style: Design.Text.tertiary)
                    .lineSpacing(1.5)
                    .padding(.top, 8)

                Spacer()

                if case .connecting = store.connectionStatus {
                    ProgressView()
                        .padding(.bottom, 12)
                }

                if case .failed(let reason) = store.connectionStatus {
                    Text(reason)
                        .zFont(size: 14, style: Design.Utility.ErrorRed._700)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 12)
                }

                ZashiButton(String(localizable: .keepkeyAddHWWalletConnect)) {
                    store.send(.connectTapped)
                }
                .disabled(store.connectionStatus == .connecting)
                .padding(.bottom, 24)
            }
            .screenHorizontalPadding()
            .onAppear { store.send(.onAppear) }
        }
        .applyScreenBackground()
    }
}
