//
//  AddKeepKeyHWWalletCoordFlowStore.swift
//  Zashi
//

import SwiftUI
import ComposableArchitecture
@preconcurrency import ZcashLightClientKit

@Reducer
struct AddKeepKeyHWWalletCoordFlow {
    @Reducer
    enum Path {
        case estimateBirthdaysDate(WalletBirthday)
        case estimatedBirthday(WalletBirthday)
        case keepKeyConnected(AddKeepKeyHWWallet)
        case keepKeyDeviceReady(AddKeepKeyHWWallet)
        case walletBirthday(WalletBirthday)
    }

    @ObservableState
    struct State {
        var addKeepKeyHWWalletState = AddKeepKeyHWWallet.State.initial
        var birthday: BlockHeight? = nil
        var isHelpSheetPresented = false
        var path = StackState<Path.State>()

        init() { }
    }

    enum Action: BindableAction {
        case addKeepKeyHWWallet(AddKeepKeyHWWallet.Action)
        case binding(BindingAction<AddKeepKeyHWWalletCoordFlow.State>)
        case closeHelpSheetTapped
        case path(StackActionOf<Path>)
    }

    @Dependency(\.audioServices) var audioServices
    @Dependency(\.zcashSDKEnvironment) var zcashSDKEnvironment

    init() { }

    var body: some Reducer<State, Action> {
        coordinatorReduce()

        BindingReducer()

        Scope(state: \.addKeepKeyHWWalletState, action: \.addKeepKeyHWWallet) {
            AddKeepKeyHWWallet()
        }

        Reduce { state, action in
            switch action {
            case .closeHelpSheetTapped:
                state.isHelpSheetPresented = false
                return .none
            default: return .none
            }
        }
        .forEach(\.path, action: \.path)
    }
}
