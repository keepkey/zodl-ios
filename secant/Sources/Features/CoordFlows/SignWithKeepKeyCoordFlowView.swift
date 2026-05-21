//
//  SignWithKeepKeyCoordFlowView.swift
//  Zashi
//

import SwiftUI
import ComposableArchitecture

struct SignWithKeepKeyCoordFlowView: View {
    @Environment(\.colorScheme) var colorScheme

    @Perception.Bindable var store: StoreOf<SignWithKeepKeyCoordFlow>
    let tokenName: String

    init(store: StoreOf<SignWithKeepKeyCoordFlow>, tokenName: String) {
        self.store = store
        self.tokenName = tokenName
    }

    var body: some View {
        WithPerceptionTracking {
            NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
                SignWithKeepKeyView(
                    store:
                        store.scope(
                            state: \.sendConfirmationState,
                            action: \.sendConfirmation
                        ),
                    tokenName: tokenName
                )
                .navigationBarHidden(true)
            } destination: { store in
                switch store.case {
                case let .preSendingFailure(store):
                    PreSendingFailureView(store: store, tokenName: tokenName)
                case let .signingInProgress(store):
                    SigningInProgressView(store: store, tokenName: tokenName)
                case let .sending(store):
                    SendingView(store: store, tokenName: tokenName)
                case let .sendResultFailure(store):
                    FailureView(store: store, tokenName: tokenName)
                case let .sendResultPending(store):
                    PendingView(store: store, tokenName: tokenName)
                case let .sendResultSuccess(store):
                    SuccessView(store: store, tokenName: tokenName)
                case let .transactionDetails(store):
                    TransactionDetailsView(store: store, tokenName: tokenName)
                }
            }
            .navigationBarHidden(!store.path.isEmpty)
        }
        .applyScreenBackground()
        .zashiBack()
    }
}

#Preview {
    NavigationView {
        SignWithKeepKeyCoordFlowView(store: SignWithKeepKeyCoordFlow.placeholder, tokenName: "ZEC")
    }
}

// MARK: - Placeholders

extension SignWithKeepKeyCoordFlow.State {
    static let initial = SignWithKeepKeyCoordFlow.State()
}

extension SignWithKeepKeyCoordFlow {
    static let placeholder = StoreOf<SignWithKeepKeyCoordFlow>(
        initialState: .initial
    ) {
        SignWithKeepKeyCoordFlow()
    }
}
