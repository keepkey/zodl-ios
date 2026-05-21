//
//  SigningInProgressView.swift
//  Zashi
//

import SwiftUI
import ComposableArchitecture

struct SigningInProgressView: View {
    @Perception.Bindable var store: StoreOf<SendConfirmation>
    let tokenName: String

    init(store: StoreOf<SendConfirmation>, tokenName: String) {
        self.store = store
        self.tokenName = tokenName
    }

    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0) {
                Spacer()

                ProgressView()
                    .scaleEffect(2)
                    .padding(.bottom, 32)

                Text(localizable: .keepkeySignWithSigning)
                    .zFont(.semiBold, size: 20, style: Design.Text.primary)

                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .applyScreenBackground()
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .screenTitle(String(localizable: .keepkeySignWithSignTransaction))
    }
}
