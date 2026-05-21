//
//  SignWithKeepKeyCoordFlowStore.swift
//  Zashi
//

import SwiftUI
import ComposableArchitecture
@preconcurrency import ZcashLightClientKit

@Reducer
struct SignWithKeepKeyCoordFlow {
    @Reducer
    enum Path {
        case preSendingFailure(SendConfirmation)
        case signingInProgress(SendConfirmation)
        case sending(SendConfirmation)
        case sendResultFailure(SendConfirmation)
        case sendResultPending(SendConfirmation)
        case sendResultSuccess(SendConfirmation)
        case transactionDetails(TransactionDetails)
    }

    @ObservableState
    struct State {
        var path = StackState<Path.State>()
        var sendConfirmationState = SendConfirmation.State.initial
        @Shared(.inMemory(.transactions)) var transactions: IdentifiedArrayOf<TransactionState> = []

        init() { }
    }

    enum Action {
        case path(StackActionOf<Path>)
        case sendConfirmation(SendConfirmation.Action)
        case signingFailed(String)
    }

    @Dependency(\.keepKeyTransport) var keepKeyTransport
    @Dependency(\.walletStorage) var walletStorage

    init() { }

    var body: some Reducer<State, Action> {
        coordinatorReduce()

        Scope(state: \.sendConfirmationState, action: \.sendConfirmation) {
            SendConfirmation()
        }

        Reduce { state, action in
            switch action {
            case .signingFailed:
                return .none
            default: return .none
            }
        }
        .forEach(\.path, action: \.path)
    }
}
