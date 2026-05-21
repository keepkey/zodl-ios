//
//  ConnectKeepKeyTests.swift
//  secantTests
//

import XCTest
import ComposableArchitecture
@testable import secant_testnet

// ZI-75: KeepKeyTransportClient mock usage, ZI-77: ConnectKeepKey reducer tests
@MainActor
class ConnectKeepKeyTests: XCTestCase {
    // MARK: - onAppear: success path

    func testOnAppear_pairingURIReceivedThenSessionEstablished() async throws {
        let store = TestStore(
            initialState: ConnectKeepKey.State()
        ) {
            ConnectKeepKey()
        }

        store.dependencies.keepKeyTransport.connect = { onPairingURI in
            onPairingURI("wc:test-uri@2?relay=wss%3A%2F%2Frelay.walletconnect.com")
            // return normally — connect() completing triggers .sessionEstablished
        }

        await store.send(.onAppear) { state in
            state.connectionStatus = .waitingForPairingURI
        }

        await store.receive(.pairingURIReceived("wc:test-uri@2?relay=wss%3A%2F%2Frelay.walletconnect.com")) { state in
            state.connectionStatus = .showingQR(pairingURI: "wc:test-uri@2?relay=wss%3A%2F%2Frelay.walletconnect.com")
        }

        await store.receive(.sessionEstablished)

        await store.finish()
    }

    // MARK: - onAppear: failure path

    func testOnAppear_connectionError_setsFailedStatus() async throws {
        let store = TestStore(
            initialState: ConnectKeepKey.State()
        ) {
            ConnectKeepKey()
        }

        store.dependencies.keepKeyTransport.connect = { _ in
            throw URLError(.notConnectedToInternet)
        }

        await store.send(.onAppear) { state in
            state.connectionStatus = .waitingForPairingURI
        }

        await store.receive(.failed(URLError(.notConnectedToInternet).localizedDescription)) { state in
            state.connectionStatus = .failed(URLError(.notConnectedToInternet).localizedDescription)
        }

        await store.finish()
    }

    // MARK: - pairingURIReceived

    func testPairingURIReceived_updatesStatusToShowingQR() async throws {
        let store = TestStore(
            initialState: ConnectKeepKey.State()
        ) {
            ConnectKeepKey()
        }

        // Suppress the default unimplemented connect() assertion — not called in this test
        store.exhaustivity = .off

        await store.send(.pairingURIReceived("wc:some-uri")) { state in
            state.connectionStatus = .showingQR(pairingURI: "wc:some-uri")
        }
    }

    // MARK: - failed

    func testFailed_updatesStatusToFailed() async throws {
        let store = TestStore(
            initialState: ConnectKeepKey.State()
        ) {
            ConnectKeepKey()
        }

        store.exhaustivity = .off

        await store.send(.failed("connection refused")) { state in
            state.connectionStatus = .failed("connection refused")
        }
    }

    // MARK: - retryTapped

    func testRetryTapped_sendsOnAppear() async throws {
        let store = TestStore(
            initialState: ConnectKeepKey.State(
            )
        ) {
            ConnectKeepKey()
        }

        store.dependencies.keepKeyTransport.connect = { _ in
            // hang indefinitely so we can just check the onAppear effect fires
            try await Task.sleep(for: .seconds(60))
        }

        // Put the store in a failed state first
        store.exhaustivity = .off

        await store.send(.retryTapped)
        await store.receive(.onAppear) { state in
            state.connectionStatus = .waitingForPairingURI
        }

        // Cancel pending effect
        await store.send(.cancelTapped)
        await store.finish()
    }

    // MARK: - cancelTapped

    func testCancelTapped_noStateChange() async throws {
        let store = TestStore(
            initialState: ConnectKeepKey.State()
        ) {
            ConnectKeepKey()
        }

        store.exhaustivity = .off

        await store.send(.cancelTapped)
        // no state mutation expected
    }

    // MARK: - sessionEstablished

    func testSessionEstablished_noStateChange() async throws {
        let store = TestStore(
            initialState: ConnectKeepKey.State()
        ) {
            ConnectKeepKey()
        }

        store.exhaustivity = .off

        await store.send(.sessionEstablished)
        // coordinator handles navigation; reducer does nothing
    }

    // MARK: - pairingURI computed property

    func testPairingURI_nilWhenWaiting() {
        let state = ConnectKeepKey.State()
        XCTAssertNil(state.pairingURI)
    }

    func testPairingURI_presentWhenShowingQR() {
        var state = ConnectKeepKey.State()
        state.connectionStatus = .showingQR(pairingURI: "wc:abc")
        XCTAssertEqual(state.pairingURI, "wc:abc")
    }

    func testPairingURI_presentWhenWaitingForApproval() {
        var state = ConnectKeepKey.State()
        state.connectionStatus = .waitingForApproval(pairingURI: "wc:xyz")
        XCTAssertEqual(state.pairingURI, "wc:xyz")
    }

    func testPairingURI_nilWhenFailed() {
        var state = ConnectKeepKey.State()
        state.connectionStatus = .failed("err")
        XCTAssertNil(state.pairingURI)
    }
}
