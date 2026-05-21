//
//  AddKeepKeyHWWalletTests.swift
//  secantTests
//

import XCTest
import ComposableArchitecture
@preconcurrency import ZcashLightClientKit
@testable import secant_testnet

// ZI-76: AddKeepKeyHWWallet reducer tests
@MainActor
class AddKeepKeyHWWalletTests: XCTestCase {
    // Reusable mock FVK — all 32-byte fields, plausible but arbitrary values
    private let mockFVK = OrchardFVK(
        ak: Data(repeating: 0x01, count: 32),
        nk: Data(repeating: 0x02, count: 32),
        rivk: Data(repeating: 0x03, count: 32),
        seedFingerprint: Data(repeating: 0x04, count: 32),
        ufvk: "ufvk1mockvalue",
        unifiedAddress: "u1mockaddress"
    )

    // MARK: - onAppear

    func testOnAppear_resetsToIdle() async throws {
        var initialState = AddKeepKeyHWWallet.State()
        initialState.connectionStatus = .failed("previous error")

        let store = TestStore(initialState: initialState) {
            AddKeepKeyHWWallet()
        }

        await store.send(.onAppear) { state in
            state.connectionStatus = .idle
            // randomSuccessIconIndex is set but we can't predict its value
        }

        await store.finish()
    }

    // MARK: - connectTapped

    func testConnectTapped_noSideEffects() async throws {
        let store = TestStore(initialState: AddKeepKeyHWWallet.State.initial) {
            AddKeepKeyHWWallet()
        }

        await store.send(.connectTapped)
        await store.finish()
    }

    // MARK: - wcSessionReady: success path

    func testWCSessionReady_successPath_sendsConnectionSucceeded() async throws {
        let fvk = mockFVK

        let store = TestStore(initialState: AddKeepKeyHWWallet.State.initial) {
            AddKeepKeyHWWallet()
        }

        store.dependencies.keepKeyTransport.getOrchardFVK = { _ in fvk }
        store.dependencies.keepKeyTransport.displayAddress = { _ in fvk.unifiedAddress }

        await store.send(.wcSessionReady) { state in
            state.connectionStatus = .connecting
        }

        await store.receive(.connectionSucceeded(fvk)) { state in
            state.connectionStatus = .connected(fvk)
        }

        await store.finish()
    }

    // MARK: - wcSessionReady: getOrchardFVK failure

    func testWCSessionReady_getFVKThrows_sendsConnectionFailed() async throws {
        let store = TestStore(initialState: AddKeepKeyHWWallet.State.initial) {
            AddKeepKeyHWWallet()
        }

        store.dependencies.keepKeyTransport.getOrchardFVK = { _ in
            throw URLError(.timedOut)
        }

        await store.send(.wcSessionReady) { state in
            state.connectionStatus = .connecting
        }

        await store.receive(.connectionFailed(URLError(.timedOut).localizedDescription)) { state in
            state.connectionStatus = .failed(URLError(.timedOut).localizedDescription)
        }

        await store.finish()
    }

    // MARK: - wcSessionReady: displayAddress failure

    func testWCSessionReady_displayAddressThrows_sendsConnectionFailed() async throws {
        let fvk = mockFVK

        let store = TestStore(initialState: AddKeepKeyHWWallet.State.initial) {
            AddKeepKeyHWWallet()
        }

        store.dependencies.keepKeyTransport.getOrchardFVK = { _ in fvk }
        store.dependencies.keepKeyTransport.displayAddress = { _ in
            throw URLError(.userCancelledAuthentication)
        }

        await store.send(.wcSessionReady) { state in
            state.connectionStatus = .connecting
        }

        await store.receive(.connectionFailed(URLError(.userCancelledAuthentication).localizedDescription)) { state in
            state.connectionStatus = .failed(URLError(.userCancelledAuthentication).localizedDescription)
        }

        await store.finish()
    }

    // MARK: - connectionSucceeded / connectionFailed

    func testConnectionSucceeded_setsConnectedStatus() async throws {
        let fvk = mockFVK
        let store = TestStore(initialState: AddKeepKeyHWWallet.State.initial) {
            AddKeepKeyHWWallet()
        }

        store.exhaustivity = .off

        await store.send(.connectionSucceeded(fvk)) { state in
            state.connectionStatus = .connected(fvk)
        }
    }

    func testConnectionFailed_setsFailedStatus() async throws {
        let store = TestStore(initialState: AddKeepKeyHWWallet.State.initial) {
            AddKeepKeyHWWallet()
        }

        store.exhaustivity = .off

        await store.send(.connectionFailed("device rejected")) { state in
            state.connectionStatus = .failed("device rejected")
        }
    }

    // MARK: - closeTapped / forgetThisDeviceTapped / setBirthdayTapped

    func testCloseTapped_noSideEffects() async throws {
        let store = TestStore(initialState: AddKeepKeyHWWallet.State.initial) {
            AddKeepKeyHWWallet()
        }

        await store.send(.closeTapped)
        await store.finish()
    }

    func testForgetThisDeviceTapped_noSideEffects() async throws {
        let store = TestStore(initialState: AddKeepKeyHWWallet.State.initial) {
            AddKeepKeyHWWallet()
        }

        await store.send(.forgetThisDeviceTapped)
        await store.finish()
    }

    func testSetBirthdayTapped_noSideEffects() async throws {
        let store = TestStore(initialState: AddKeepKeyHWWallet.State.initial) {
            AddKeepKeyHWWallet()
        }

        await store.send(.setBirthdayTapped)
        await store.finish()
    }

    // MARK: - unlockTapped: no fvk in state

    func testUnlockTapped_whenNotConnected_doesNothing() async throws {
        // connectionStatus is .idle so state.fvk == nil
        let store = TestStore(initialState: AddKeepKeyHWWallet.State.initial) {
            AddKeepKeyHWWallet()
        }

        await store.send(.unlockTapped(nil))
        await store.finish()
    }

    // MARK: - unlockTapped: importAccount returns nil

    func testUnlockTapped_importAccountReturnsNil_noAccountImported() async throws {
        let fvk = mockFVK
        var initialState = AddKeepKeyHWWallet.State.initial
        initialState.connectionStatus = .connected(fvk)

        let store = TestStore(initialState: initialState) {
            AddKeepKeyHWWallet()
        }

        store.dependencies.sdkSynchronizer = .noOp
        store.dependencies.sdkSynchronizer.importAccount = { _, _, _, _, _, _, _ in nil }

        // importAccount returns nil → .accountImported is never sent
        await store.send(.unlockTapped(nil))
        await store.finish()
    }

    // MARK: - unlockTapped: importAccount succeeds

    func testUnlockTapped_importAccountSucceeds_sendsAccountImported() async throws {
        let fvk = mockFVK
        let testUUID = AccountUUID(id: [UInt8](repeating: 0xAB, count: 16))

        var initialState = AddKeepKeyHWWallet.State.initial
        initialState.connectionStatus = .connected(fvk)

        let store = TestStore(initialState: initialState) {
            AddKeepKeyHWWallet()
        }

        store.dependencies.sdkSynchronizer = .noOp
        store.dependencies.sdkSynchronizer.importAccount = { _, _, _, _, _, _, _ in testUUID }
        store.dependencies.sdkSynchronizer.walletAccounts = { [] }

        await store.send(.unlockTapped(nil))

        await store.receive(.accountImported(testUUID))

        await store.receive(.loadedWalletAccounts([], testUUID))

        await store.receive(.accountImportSucceeded)

        await store.finish()
    }

    // MARK: - accountImportFailed

    func testAccountImportFailed_noSideEffects() async throws {
        let store = TestStore(initialState: AddKeepKeyHWWallet.State.initial) {
            AddKeepKeyHWWallet()
        }

        await store.send(.accountImportFailed)
        await store.finish()
    }

    // MARK: - fvk computed property

    func testFVKProperty_nilWhenNotConnected() {
        let state = AddKeepKeyHWWallet.State.initial
        XCTAssertNil(state.fvk)
    }

    func testFVKProperty_presentWhenConnected() {
        var state = AddKeepKeyHWWallet.State.initial
        state.connectionStatus = .connected(mockFVK)
        XCTAssertEqual(state.fvk, mockFVK)
    }
}
