//
//  SignWithKeepKeyView.swift
//  Zashi
//

import SwiftUI
import ComposableArchitecture
@preconcurrency import ZcashLightClientKit

// swiftlint:disable:next type_body_length
struct SignWithKeepKeyView: View {
    @Environment(\.colorScheme) private var colorScheme

    @Perception.Bindable var store: StoreOf<SendConfirmation>

    let tokenName: String

    init(store: StoreOf<SendConfirmation>, tokenName: String) {
        self.store = store
        self.tokenName = tokenName
    }

    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            // TODO [#3]: replace with KeepKey logo asset (ZI-31)
                            Asset.Assets.Partners.keystoneLogo.image
                                .resizable()
                                .frame(width: 24, height: 24)
                                .padding(8)
                                .background {
                                    Circle()
                                        .fill(Design.Surfaces.bgAlt.color(colorScheme))
                                }
                                .padding(.trailing, 12)

                            VStack(alignment: .leading, spacing: 0) {
                                Text(localizable: .accountsKeepkey)
                                    .zFont(.semiBold, size: 16, style: Design.Text.primary)

                                Text(store.selectedWalletAccount?.unifiedAddress?.zip316 ?? "")
                                    .zFont(fontFamily: .robotoMono, size: 12, style: Design.Text.tertiary)
                            }

                            Spacer()

                            Text(localizable: .keepkeySignWithHardware)
                                .zFont(.medium, size: 12, style: Design.Utility.HyperBlue._700)
                                .padding(.vertical, 2)
                                .padding(.horizontal, 8)
                                .background {
                                    RoundedRectangle(cornerRadius: Design.Radius._2xl)
                                        .fill(Design.Utility.HyperBlue._50.color(colorScheme))
                                        .background {
                                            RoundedRectangle(cornerRadius: Design.Radius._2xl)
                                                .stroke(Design.Utility.HyperBlue._200.color(colorScheme))
                                        }
                                }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background {
                            RoundedRectangle(cornerRadius: Design.Radius._2xl)
                                .stroke(Design.Surfaces.strokeSecondary.color(colorScheme))
                        }
                        .padding(.top, 40)

                        ProgressView()
                            .frame(width: 216, height: 216)
                            .padding(24)
                            .background {
                                RoundedRectangle(cornerRadius: Design.Radius._xl)
                                    .fill(Asset.Colors.ZDesign.Base.bone.color)
                                    .background {
                                        RoundedRectangle(cornerRadius: Design.Radius._xl)
                                            .stroke(Design.Surfaces.strokeSecondary.color(colorScheme))
                                    }
                            }
                            .padding(.top, 32)

                        Text(localizable: .keepkeySignWithTitle)
                            .zFont(.medium, size: 16, style: Design.Text.primary)
                            .padding(.top, 32)

                        Text(localizable: .keepkeySignWithDesc)
                            .zFont(size: 14, style: Design.Text.tertiary)
                            .screenHorizontalPadding()
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                    }
                }

                Spacer()

                ZashiButton(
                    String(localizable: .keepkeySignWithReject),
                    type: .destructive1
                ) {
                    store.send(.rejectRequested)
                }
                .padding(.bottom, 8)

                ZashiButton(String(localizable: .keepkeySignWithGetSignature)) {
                    store.send(.getSignatureTapped)
                }
                .padding(.bottom, 24)
            }
            .zashiSheet(isPresented: $store.rejectSendRequest) {
                rejectSendContent(colorScheme: colorScheme)
            }
            .onAppear { store.send(.onAppear) }
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
        }
        .screenHorizontalPadding()
        .applyScreenBackground()
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .screenTitle(String(localizable: .keepkeySignWithSignTransaction))
    }
}

extension SignWithKeepKeyView {
    @ViewBuilder func rejectSendContent(colorScheme: ColorScheme) -> some View {
        VStack(spacing: 0) {
            Asset.Assets.Icons.arrowUp.image
                .zImage(size: 20, style: Design.Utility.ErrorRed._500)
                .background {
                    Circle()
                        .fill(Design.Utility.ErrorRed._100.color(colorScheme))
                        .frame(width: 44, height: 44)
                }
                .padding(.top, 48)
                .padding(.bottom, 20)

            Text(localizable: .keystoneTransactionRejectTitle)
                .zFont(.semiBold, size: 24, style: Design.Text.primary)
                .padding(.bottom, 8)

            Text(localizable: .keystoneTransactionRejectMsg)
                .zFont(size: 14, style: Design.Text.tertiary)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
                .padding(.bottom, 32)

            ZashiButton(String(localizable: .keystoneTransactionRejectGoBack)) {
                store.send(.rejectRequestCanceled)
            }
            .padding(.bottom, 8)

            ZashiButton(
                String(localizable: .keystoneTransactionRejectRejectSig),
                type: .destructive2
            ) {
                store.send(.rejectTapped)
            }
            .padding(.bottom, Design.Spacing.sheetBottomSpace)
        }
    }
}
