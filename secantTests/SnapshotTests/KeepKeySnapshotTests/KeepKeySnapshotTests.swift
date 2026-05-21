//
//  KeepKeySnapshotTests.swift
//  secantTests
//

import XCTest
import SwiftUI
import ComposableArchitecture
@preconcurrency import ZcashLightClientKit
@testable import secant_testnet

// ZI-78: Snapshot tests for KeepKey views (attach as XCTAttachment for manual inspection)
class KeepKeySnapshotTests: XCTestCase {
    // MARK: - ConnectKeepKeyView

    func testConnectKeepKeyView_waitingForPairing() throws {
        let store = Store(initialState: ConnectKeepKey.State()) {
            ConnectKeepKey()
                .dependency(\.keepKeyTransport.connect, { _ in
                    // Suspend indefinitely — we only care about the initial waiting UI
                    try await Task.sleep(for: .seconds(300))
                })
        }

        addAttachments(ConnectKeepKeyView(store: store))
    }

    func testConnectKeepKeyView_showingQR() throws {
        var state = ConnectKeepKey.State()
        state.connectionStatus = .showingQR(pairingURI: "wc:mock-uri@2?relay=wss%3A%2F%2Frelay.walletconnect.com")

        let store = Store(initialState: state) {
            ConnectKeepKey()
                .dependency(\.keepKeyTransport.connect, { _ in
                    try await Task.sleep(for: .seconds(300))
                })
        }

        addAttachments(ConnectKeepKeyView(store: store))
    }

    func testConnectKeepKeyView_failed() throws {
        var state = ConnectKeepKey.State()
        state.connectionStatus = .failed("WalletConnect session rejected by peer")

        let store = Store(initialState: state) {
            ConnectKeepKey()
                .dependency(\.keepKeyTransport.connect, { _ in
                    try await Task.sleep(for: .seconds(300))
                })
        }

        addAttachments(ConnectKeepKeyView(store: store))
    }

    // MARK: - AddKeepKeyHWWalletView

    func testAddKeepKeyHWWalletView_idle() throws {
        let store = Store(initialState: AddKeepKeyHWWallet.State.initial) {
            AddKeepKeyHWWallet()
                .dependency(\.keepKeyTransport, .noOp)
                .dependency(\.sdkSynchronizer, .noOp)
        }

        addAttachments(AddKeepKeyHWWalletView(store: store))
    }

    func testAddKeepKeyHWWalletView_connecting() throws {
        var state = AddKeepKeyHWWallet.State.initial
        state.connectionStatus = .connecting

        let store = Store(initialState: state) {
            AddKeepKeyHWWallet()
                .dependency(\.keepKeyTransport, .noOp)
                .dependency(\.sdkSynchronizer, .noOp)
        }

        addAttachments(AddKeepKeyHWWalletView(store: store))
    }

    func testAddKeepKeyHWWalletView_failed() throws {
        var state = AddKeepKeyHWWallet.State.initial
        state.connectionStatus = .failed("Could not retrieve Orchard FVK from device")

        let store = Store(initialState: state) {
            AddKeepKeyHWWallet()
                .dependency(\.keepKeyTransport, .noOp)
                .dependency(\.sdkSynchronizer, .noOp)
        }

        addAttachments(AddKeepKeyHWWalletView(store: store))
    }

    // MARK: - SignWithKeepKeyView

    func testSignWithKeepKeyView_initial() throws {
        let store = Store(
            initialState: .init(
                address: "u1mockaddress",
                amount: Zatoshi(50_000_000),
                feeRequired: Zatoshi(5_000),
                message: "Sending with KeepKey",
                proposal: nil
            )
        ) {
            SendConfirmation()
                .dependency(\.derivationTool, .live())
                .dependency(\.mainQueue, DispatchQueue.main.eraseToAnyScheduler())
                .dependency(\.numberFormatter, .live())
                .dependency(\.walletStorage, .noOp)
                .dependency(\.sdkSynchronizer, .noOp)
                .dependency(\.localAuthentication, .mockAuthenticationFailed)
                .dependency(\.zcashSDKEnvironment, .testValue)
                .dependency(\.keepKeyTransport, .noOp)
        }

        addAttachments(SignWithKeepKeyView(store: store, tokenName: "ZEC"))
    }
}

// MARK: - KeepKeyTransportClient noOp

private extension KeepKeyTransportClient {
    static let noOp = KeepKeyTransportClient(
        connect: { _ in },
        disconnect: { },
        getOrchardFVK: { _ in
            OrchardFVK(
                ak: Data(repeating: 0, count: 32),
                nk: Data(repeating: 0, count: 32),
                rivk: Data(repeating: 0, count: 32),
                seedFingerprint: Data(repeating: 0, count: 32),
                ufvk: "",
                unifiedAddress: ""
            )
        },
        displayAddress: { _ in "" },
        signPCZT: { _ in SignedPCZT(signatures: [], txid: nil) }
    )
}
