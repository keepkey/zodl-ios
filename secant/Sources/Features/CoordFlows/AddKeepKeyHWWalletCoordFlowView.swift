//
//  AddKeepKeyHWWalletCoordFlowView.swift
//  Zashi
//

import SwiftUI
import ComposableArchitecture

struct AddKeepKeyHWWalletCoordFlowView: View {
    @Environment(\.colorScheme) var colorScheme

    @Perception.Bindable var store: StoreOf<AddKeepKeyHWWalletCoordFlow>
    let tokenName: String

    init(store: StoreOf<AddKeepKeyHWWalletCoordFlow>, tokenName: String) {
        self.store = store
        self.tokenName = tokenName
    }

    var body: some View {
        WithPerceptionTracking {
            NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
                AddKeepKeyHWWalletView(
                    store:
                        store.scope(
                            state: \.addKeepKeyHWWalletState,
                            action: \.addKeepKeyHWWallet
                        )
                )
                .zashiSheet(isPresented: $store.isHelpSheetPresented) {
                    helpSheetContent()
                }
            } destination: { store in
                switch store.case {
                case let .estimateBirthdaysDate(store):
                    WalletBirthdayEstimateDateView(store: store)
                case let .estimatedBirthday(store):
                    WalletBirthdayEstimatedHeightView(store: store)
                case let .keepKeyConnected(store):
                    KeepKeyConnectedView(store: store)
                case let .keepKeyDeviceReady(store):
                    KeepKeyDeviceReadyView(store: store)
                case let .walletBirthday(store):
                    WalletBirthdayView(store: store)
                }
            }
        }
        .applyScreenBackground()
        .zashiBack()
    }

    @ViewBuilder private func helpSheetContent() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(localizable: .restoreWalletHelpTitle)
                .zFont(.semiBold, size: 24, style: Design.Text.primary)
                .padding(.top, 24)
                .padding(.bottom, 12)

            HStack(alignment: .top, spacing: 8) {
                Asset.Assets.infoCircle.image
                    .zImage(size: 20, style: Design.Text.primary)

                if let attrText = try? AttributedString(
                    markdown: String(localizable: .walletBirthdayHelpDesc),
                    including: \.zashiApp
                ) {
                    ZashiText(withAttributedString: attrText, colorScheme: colorScheme)
                        .zFont(size: 14, style: Design.Text.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.bottom, 32)

            ZashiButton(String(localizable: .restoreInfoGotIt)) {
                store.send(.closeHelpSheetTapped)
            }
            .padding(.bottom, Design.Spacing.sheetBottomSpace)
        }
    }
}

#Preview {
    NavigationView {
        AddKeepKeyHWWalletCoordFlowView(store: AddKeepKeyHWWalletCoordFlow.placeholder, tokenName: "ZEC")
    }
}

// MARK: - Placeholders

extension AddKeepKeyHWWalletCoordFlow.State {
    static let initial = AddKeepKeyHWWalletCoordFlow.State()
}

extension AddKeepKeyHWWalletCoordFlow {
    static let placeholder = StoreOf<AddKeepKeyHWWalletCoordFlow>(
        initialState: .initial
    ) {
        AddKeepKeyHWWalletCoordFlow()
    }
}
