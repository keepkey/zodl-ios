//
//  KeepKeyConnectedView.swift
//  Zashi
//

import SwiftUI
import ComposableArchitecture

struct KeepKeyConnectedView: View {
    @Perception.Bindable var store: StoreOf<AddKeepKeyHWWallet>

    init(store: StoreOf<AddKeepKeyHWWallet>) {
        self.store = store
    }

    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0) {
                Spacer()

                store.successIllustration
                    .resizable()
                    .frame(width: 148, height: 148)

                Text(localizable: .keepkeyAddHWWalletConnected)
                    .zFont(.semiBold, size: 28, style: Design.Text.primary)
                    .padding(.top, 16)

                Text(localizable: .keepkeyAddHWWalletConnectedDesc)
                    .zFont(size: 14, style: Design.Text.primary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(1.5)
                    .padding(.top, 8)
                    .screenHorizontalPadding()

                Spacer()

                ZashiButton(String(localizable: .keepkeyAddHWWalletClose)) {
                    store.send(.closeTapped)
                }
                .padding(.bottom, 24)
            }
        }
        .navigationBarBackButtonHidden()
        .padding(.vertical, 1)
        .screenHorizontalPadding()
        .applySuccessScreenBackground()
    }
}
