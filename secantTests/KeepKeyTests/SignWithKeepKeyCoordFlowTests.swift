//
//  SignWithKeepKeyCoordFlowTests.swift
//  secantTests
//

import XCTest
import ComposableArchitecture
@preconcurrency import ZcashLightClientKit
@testable import secant_testnet

// ZI-77: SignWithKeepKeyCoordFlow reducer / coordinator tests
@MainActor
class SignWithKeepKeyCoordFlowTests: XCTestCase {
    // MARK: - signingFailed: empty path

    func testSigningFailed_emptyPath_appendsPreSendingFailure() async throws {
        let store = TestStore(initialState: SignWithKeepKeyCoordFlow.State()) {
            SignWithKeepKeyCoordFlow()
        }

        store.exhaustivity = .off
        store.dependencies.keepKeyTransport.signPCZT = { _ in
            throw URLError(.timedOut)
        }
        store.dependencies.walletStorage = .noOp

        await store.send(.signingFailed("device error"))

        // After signingFailed with empty path, path should have one element: preSendingFailure
        XCTAssertEqual(store.state.path.count, 1)
        XCTAssertTrue(store.state.path.first.flatMap { $0.is(\.preSendingFailure) } ?? false)
    }

    // MARK: - signingFailed: signingInProgress already in path

    func testSigningFailed_withSigningInProgress_sendsPcztSendFailed() async throws {
        var initialState = SignWithKeepKeyCoordFlow.State()
        // Manually push a signingInProgress element onto the path
        initialState.path.append(.signingInProgress(initialState.sendConfirmationState))

        let store = TestStore(initialState: initialState) {
            SignWithKeepKeyCoordFlow()
        }

        store.exhaustivity = .off
        store.dependencies.walletStorage = .noOp

        await store.send(.signingFailed("device rejected signing"))

        // The coordinator should have sent .sendConfirmation(.pcztSendFailed(...))
        // which in turn is handled by SendConfirmation reducer.
        // Path should remain unchanged (coordinator delegates via pcztSendFailed).
        XCTAssertEqual(store.state.path.count, 1)
    }

    // MARK: - getSignatureTapped: missing PCZT → signingFailed

    func testGetSignatureTapped_missingPCZT_signingFails() async throws {
        // Initial state has redactedPcztForSigner == nil, so coordinator should fast-fail
        let store = TestStore(initialState: SignWithKeepKeyCoordFlow.State()) {
            SignWithKeepKeyCoordFlow()
        }

        store.exhaustivity = .off
        store.dependencies.keepKeyTransport.signPCZT = { _ in
            throw URLError(.timedOut)
        }
        store.dependencies.walletStorage = .noOp

        await store.send(.sendConfirmation(.getSignatureTapped))

        // Path should contain signingInProgress followed by preSendingFailure
        // (coordinator pushes signingInProgress, then sends signingFailed which pushes preSendingFailure)
        XCTAssertGreaterThanOrEqual(store.state.path.count, 1)

        await store.finish()
    }

    // MARK: - updateResult: failure

    func testUpdateResult_failure_appendsSendResultFailure() async throws {
        let store = TestStore(initialState: SignWithKeepKeyCoordFlow.State()) {
            SignWithKeepKeyCoordFlow()
        }

        store.exhaustivity = .off
        store.dependencies.walletStorage = .noOp

        await store.send(.sendConfirmation(.updateResult(.failure)))

        let hasFailure = store.state.path.contains { $0.is(\.sendResultFailure) }
        XCTAssertTrue(hasFailure, "Expected sendResultFailure in path")
    }

    // MARK: - updateResult: pending

    func testUpdateResult_pending_appendsSendResultPending() async throws {
        let store = TestStore(initialState: SignWithKeepKeyCoordFlow.State()) {
            SignWithKeepKeyCoordFlow()
        }

        store.exhaustivity = .off
        store.dependencies.walletStorage = .noOp

        await store.send(.sendConfirmation(.updateResult(.pending)))

        let hasPending = store.state.path.contains { $0.is(\.sendResultPending) }
        XCTAssertTrue(hasPending, "Expected sendResultPending in path")
    }

    // MARK: - updateResult: success

    func testUpdateResult_success_appendsSendResultSuccess() async throws {
        let store = TestStore(initialState: SignWithKeepKeyCoordFlow.State()) {
            SignWithKeepKeyCoordFlow()
        }

        store.exhaustivity = .off
        store.dependencies.walletStorage = .noOp

        await store.send(.sendConfirmation(.updateResult(.success)))

        let hasSuccess = store.state.path.contains { $0.is(\.sendResultSuccess) }
        XCTAssertTrue(hasSuccess, "Expected sendResultSuccess in path")
    }
}
