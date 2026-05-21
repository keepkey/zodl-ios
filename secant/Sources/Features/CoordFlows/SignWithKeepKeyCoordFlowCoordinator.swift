//
//  SignWithKeepKeyCoordFlowCoordinator.swift
//  Zashi
//

import ComposableArchitecture
import Foundation
@preconcurrency import ZcashLightClientKit

extension SignWithKeepKeyCoordFlow {
    func coordinatorReduce() -> Reduce<SignWithKeepKeyCoordFlow.State, SignWithKeepKeyCoordFlow.Action> {
        Reduce { state, action in
            switch action {

                // MARK: - Self

            case .sendConfirmation(.getSignatureTapped):
                state.path.append(.signingInProgress(state.sendConfirmationState))
                guard let redactedPczt = state.sendConfirmationState.redactedPcztForSigner,
                      let seedFP = state.sendConfirmationState.selectedWalletAccount?.seedFingerprint
                else {
                    return .send(.signingFailed("Missing PCZT or seed fingerprint"))
                }
                // Build a minimal sign request. Full field population (digest fields, amounts, etc.)
                // requires additional SendConfirmation state that will be wired in a follow-up.
                // TODO: [#1] Populate all PCZTSignRequest fields from sendConfirmationState
                let request = PCZTSignRequest(
                    account: 0,
                    pcztData: Data(redactedPczt),
                    nActions: 0,
                    totalAmount: 0,
                    fee: 0,
                    branchId: 0,
                    headerDigest: Data(),
                    transparentDigest: Data(),
                    saplingDigest: Data(),
                    orchardDigest: Data(),
                    orchardFlags: 0,
                    orchardValueBalance: 0,
                    orchardAnchor: Data(),
                    seedFingerprint: Data(seedFP),
                    nTransparentInputs: 0
                )
                return .run { send in
                    do {
                        // TODO: [#1] Insert signatures into PCZT — blocked on addSpendAuthSigsToPczt
                        //       in ZcashLightClientKit (mirrors Android TODO [#2]).
                        let _ = try await keepKeyTransport.signPCZT(request)
                        // When addSpendAuthSigsToPczt is available:
                        //   let pcztWithSigs = try await sdkSynchronizer.addSpendAuthSigsToPczt(redactedPczt, signatures)
                        //   await send(.sendConfirmation(.foundPCZT(pcztWithSigs)))
                        await send(.signingFailed("addSpendAuthSigsToPczt not yet in ZcashLightClientKit"))
                    } catch {
                        await send(.signingFailed(error.localizedDescription))
                    }
                }

            case .signingFailed(let reason):
                if state.path.ids.isEmpty {
                    state.path.append(.preSendingFailure(state.sendConfirmationState))
                    return .none
                }
                for element in state.path.reversed() {
                    if element.is(\.signingInProgress) {
                        return .send(.sendConfirmation(.pcztSendFailed(reason.toZcashError())))
                    }
                }
                state.path.append(.preSendingFailure(state.sendConfirmationState))
                return .none

            case .sendConfirmation(.updateResult(let result)):
                switch result {
                case .failure:
                    state.path.append(.sendResultFailure(state.sendConfirmationState))
                case .pending:
                    state.path.append(.sendResultPending(state.sendConfirmationState))
                case .success:
                    if state.sendConfirmationState.isShielding {
                        walletStorage.resetShieldingReminder(WalletAccount.Vendor.keepKey.name())
                    }
                    state.path.append(.sendResultSuccess(state.sendConfirmationState))
                default: break
                }
                return .none

            case .path(.element(id: _, action: .sendResultSuccess(.viewTransactionTapped))),
                    .path(.element(id: _, action: .sendResultFailure(.viewTransactionTapped))),
                    .path(.element(id: _, action: .sendResultPending(.viewTransactionTapped))):
                if let txid = state.sendConfirmationState.txIdToExpand {
                    var transactionDetailsState = TransactionDetails.State.initial
                    if let index = state.transactions.index(id: txid) {
                        transactionDetailsState.transaction = state.transactions[index]
                    } else {
                        transactionDetailsState.transaction = TransactionState(
                            pendingSendId: txid,
                            zecAmount: state.sendConfirmationState.amount
                        )
                    }
                    transactionDetailsState.isCloseButtonRequired = true
                    state.path.append(.transactionDetails(transactionDetailsState))
                }
                return .none

            case .sendConfirmation(.pcztSendFailed(let error)):
                if state.path.ids.isEmpty {
                    state.path.append(.preSendingFailure(state.sendConfirmationState))
                    return .none
                }
                for element in state.path.reversed() {
                    if element.is(\.signingInProgress) {
                        return .send(.sendConfirmation(.sendFailed(error?.toZcashError(), true)))
                    } else if element.is(\.preSendingFailure) {
                        state.path.append(.preSendingFailure(state.sendConfirmationState))
                        break
                    }
                }
                return .none

            default: return .none
            }
        }
    }
}
