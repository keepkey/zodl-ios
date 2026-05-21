//
//  AddKeepKeyHWWalletCoordFlowCoordinator.swift
//  Zashi
//

import ComposableArchitecture

extension AddKeepKeyHWWalletCoordFlow {
    func coordinatorReduce() -> Reduce<AddKeepKeyHWWalletCoordFlow.State, AddKeepKeyHWWalletCoordFlow.Action> {
        Reduce { state, action in
            switch action {

                // MARK: - Root (AddKeepKeyHWWallet)

            case .addKeepKeyHWWallet(.connectionSucceeded(let fvk)):
                var deviceReadyState = AddKeepKeyHWWallet.State.initial
                deviceReadyState.connectionStatus = .connected(fvk)
                state.path.append(.keepKeyDeviceReady(deviceReadyState))
                audioServices.systemSoundVibrate()
                return .none

                // MARK: - KeepKey Device Ready

            case .path(.element(id: _, action: .keepKeyDeviceReady(.accountImportSucceeded))):
                state.path.append(.keepKeyConnected(AddKeepKeyHWWallet.State.initial))
                return .none

            case .path(.element(id: _, action: .keepKeyDeviceReady(.setBirthdayTapped))):
                var birthdayState = WalletBirthday.State.initial
                birthdayState.isKeystoneFlow = true
                state.path.append(.estimateBirthdaysDate(birthdayState))
                return .none

                // MARK: - Estimate Birthday's Date

            case .path(.element(id: _, action: .estimateBirthdaysDate(.enterManuallyTapped))):
                var birthdayState = WalletBirthday.State.initial
                birthdayState.isKeystoneFlow = true
                state.path.append(.walletBirthday(birthdayState))
                return .none

            case .path(.element(id: _, action: .estimateBirthdaysDate(.helpSheetRequested))),
                .path(.element(id: _, action: .estimatedBirthday(.helpSheetRequested))),
                .path(.element(id: _, action: .walletBirthday(.helpSheetRequested))):
                state.isHelpSheetPresented.toggle()
                return .none

            case .path(.element(id: _, action: .estimateBirthdaysDate(.estimateHeightReady))):
                for element in state.path {
                    if case .estimateBirthdaysDate(let estimateState) = element {
                        state.path.append(.estimatedBirthday(estimateState))
                    }
                }
                return .none

                // MARK: - Estimated Birthday

            case .path(.element(id: _, action: .estimatedBirthday(.enterManuallyTapped))):
                var birthdayState = WalletBirthday.State.initial
                birthdayState.isKeystoneFlow = true
                state.path.append(.walletBirthday(birthdayState))
                return .none

            case .path(.element(id: _, action: .estimatedBirthday(.restoreTapped))):
                for element in state.path {
                    if case .estimatedBirthday(let estimatedState) = element {
                        state.birthday = estimatedState.estimatedHeight
                    }
                }
                for id in state.path.ids {
                    if case .keepKeyDeviceReady = state.path[id: id] {
                        return .send(.path(.element(id: id, action: .keepKeyDeviceReady(.unlockTapped(state.birthday)))))
                    }
                }
                return .none

                // MARK: - Wallet Birthday (manual entry)

            case .path(.element(id: _, action: .walletBirthday(.restoreTapped))):
                for element in state.path {
                    if case .walletBirthday(let birthdayState) = element {
                        state.birthday = birthdayState.estimatedHeight
                    }
                }
                for id in state.path.ids {
                    if case .keepKeyDeviceReady = state.path[id: id] {
                        return .send(.path(.element(id: id, action: .keepKeyDeviceReady(.unlockTapped(state.birthday)))))
                    }
                }
                return .none

            default: return .none
            }
        }
    }
}
