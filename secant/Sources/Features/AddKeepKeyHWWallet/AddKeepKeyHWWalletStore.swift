//
//  AddKeepKeyHWWalletStore.swift
//  Zashi
//

import SwiftUI
import ComposableArchitecture
@preconcurrency import ZcashLightClientKit

@Reducer
struct AddKeepKeyHWWallet {
    enum ConnectionStatus: Equatable {
        case idle
        case connecting
        case connected(OrchardFVK)
        case failed(String)
    }

    @ObservableState
    struct State: Equatable {
        var connectionStatus: ConnectionStatus = .idle
        var randomSuccessIconIndex = 0
        @Shared(.inMemory(.selectedWalletAccount)) var selectedWalletAccount: WalletAccount? = nil
        @Shared(.inMemory(.walletAccounts)) var walletAccounts: [WalletAccount] = []

        var fvk: OrchardFVK? {
            if case .connected(let fvk) = connectionStatus { return fvk }
            return nil
        }

        var successIllustration: Image {
            switch randomSuccessIconIndex {
            case 1: return Asset.Assets.Illustrations.success1.image
            default: return Asset.Assets.Illustrations.success2.image
            }
        }

        init() { }
    }

    enum Action: BindableAction, Equatable {
        case accountImported(AccountUUID)
        case accountImportFailed
        case accountImportSucceeded
        case binding(BindingAction<AddKeepKeyHWWallet.State>)
        case closeTapped
        case connectTapped
        case connectionSucceeded(OrchardFVK)
        case connectionFailed(String)
        case forgetThisDeviceTapped
        case loadedWalletAccounts([WalletAccount], AccountUUID)
        case onAppear
        case setBirthdayTapped
        case unlockTapped(BlockHeight?)
    }

    init() { }

    @Dependency(\.keepKeyTransport) var keepKeyTransport
    @Dependency(\.sdkSynchronizer) var sdkSynchronizer

    var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .onAppear:
                state.connectionStatus = .idle
                state.randomSuccessIconIndex = Int.random(in: 1...2)
                return .none

            case .connectTapped:
                state.connectionStatus = .connecting
                return .run { send in
                    do {
                        try await keepKeyTransport.connect()
                        let fvk = try await keepKeyTransport.getOrchardFVK(0)
                        let request = DisplayAddressRequest(
                            account: 0,
                            address: fvk.unifiedAddress,
                            ak: fvk.ak,
                            nk: fvk.nk,
                            rivk: fvk.rivk,
                            seedFingerprint: fvk.seedFingerprint
                        )
                        _ = try await keepKeyTransport.displayAddress(request)
                        await send(.connectionSucceeded(fvk))
                    } catch {
                        await send(.connectionFailed(error.localizedDescription))
                    }
                }

            case .connectionSucceeded(let fvk):
                state.connectionStatus = .connected(fvk)
                return .none

            case .connectionFailed(let reason):
                state.connectionStatus = .failed(reason)
                return .none

            case .binding, .closeTapped, .forgetThisDeviceTapped, .setBirthdayTapped:
                return .none

            case .unlockTapped(let birthday):
                guard let fvk = state.fvk else { return .none }
                return .run { send in
                    do {
                        let uuid = try await sdkSynchronizer.importAccount(
                            fvk.ufvk,
                            Array(fvk.seedFingerprint),
                            Zip32AccountIndex(0),
                            AccountPurpose.spending,
                            String(localizable: .accountsKeepkey),
                            String(localizable: .accountsKeepkey).lowercased(),
                            birthday
                        )
                        if let uuid {
                            await send(.accountImported(uuid))
                        }
                    } catch {
                        await send(.accountImportFailed)
                    }
                }

            case .accountImported(let uuid):
                return .run { send in
                    let walletAccounts = try await sdkSynchronizer.walletAccounts()
                    await send(.loadedWalletAccounts(walletAccounts, uuid))
                    await send(.accountImportSucceeded)
                }

            case .accountImportFailed:
                return .none

            case .accountImportSucceeded:
                return .none

            case let .loadedWalletAccounts(walletAccounts, uuid):
                state.$walletAccounts.withLock { $0 = walletAccounts }
                for walletAccount in walletAccounts {
                    if walletAccount.id == uuid {
                        state.$selectedWalletAccount.withLock { $0 = walletAccount }
                        break
                    }
                }
                return .none
            }
        }
    }
}

extension AddKeepKeyHWWallet.State {
    static let initial = AddKeepKeyHWWallet.State()
}
