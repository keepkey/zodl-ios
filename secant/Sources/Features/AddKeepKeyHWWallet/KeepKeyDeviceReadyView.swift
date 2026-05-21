//
//  KeepKeyDeviceReadyView.swift
//  Zashi
//

import SwiftUI
import ComposableArchitecture

struct KeepKeyDeviceReadyView: View {
    @Perception.Bindable var store: StoreOf<AddKeepKeyHWWallet>

    init(store: StoreOf<AddKeepKeyHWWallet>) {
        self.store = store
    }

    var body: some View {
        WithPerceptionTracking {
            VStack(alignment: .leading, spacing: 0) {
                Text(localizable: .keepkeyAddHWWalletDeviceQuestion)
                    .zFont(.semiBold, size: 24, style: Design.Text.primary)
                    .padding(.top, 24)

                Text(localizable: .keepkeyAddHWWalletDeviceDesc)
                    .zFont(size: 14, style: Design.Text.tertiary)
                    .lineSpacing(1.5)
                    .padding(.top, 8)

                Spacer()

                ZashiButton(
                    String(localizable: .keepkeyAddHWWalletConnectActive),
                    type: .ghost
                ) {
                    store.send(.setBirthdayTapped)
                }
                .padding(.bottom, 12)

                ZashiButton(String(localizable: .keepkeyAddHWWalletConnectNew)) {
                    store.send(.unlockTapped(nil))
                }
                .padding(.bottom, 24)
            }
            .screenHorizontalPadding()
            .zashiBackV2(background: false) {
                store.send(.forgetThisDeviceTapped)
            }
        }
        .applyScreenBackground()
    }
}
