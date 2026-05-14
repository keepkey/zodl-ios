//
//  SelectedServersMigrationTests.swift
//  secantTests
//
//  Created by Adam Tucker on 2026-04-05.
//

import XCTest
import ComposableArchitecture
import ZcashLightClientKit
@testable import secant_testnet

private final class UncheckedSendableBox<Value>: @unchecked Sendable {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }
}

class SelectedServersMigrationTests: XCTestCase {

    // MARK: - Custom server user → manual mode

    func testCustomServerUser_migratesToManualMode() throws {
        let customServer = UserPreferencesStorage.ServerConfig(
            host: "my-custom-node.example.com",
            port: 9067,
            isCustom: true
        )

        let capturedSelectedServers = UncheckedSendableBox<UserPreferencesStorage.SelectedServersConfig?>(nil)

        withDependencies {
            $0.userStoredPreferences.server = { customServer }
            $0.userStoredPreferences.selectedServers = { nil }
            $0.userStoredPreferences.setSelectedServers = { config in
                capturedSelectedServers.value = config
            }
        } operation: {
            ZcashSDKEnvironment.initializeSelectedServersIfNeeded(for: .mainnet)
        }

        let result = try XCTUnwrap(capturedSelectedServers.value, "Migration should have persisted a selectedServers config")

        XCTAssertEqual(result.mode, .manual, "Custom server user should be set to manual mode")
        XCTAssertEqual(result.servers.count, 1, "Custom server user should have exactly 1 selected server")
        XCTAssertEqual(result.servers.first?.host, customServer.host)
        XCTAssertEqual(result.servers.first?.port, customServer.port)
        XCTAssertTrue(result.servers.first?.isCustom == true, "The server should be marked as custom")
    }

    func testLegacyInfraServerUser_migratesToManualMode() throws {
        let infraServer = UserPreferencesStorage.ServerConfig(
            host: "lwd1.zcash-infra.com",
            port: 443,
            isCustom: false
        )

        let capturedSelectedServers = UncheckedSendableBox<UserPreferencesStorage.SelectedServersConfig?>(nil)

        withDependencies {
            $0.userStoredPreferences.server = { infraServer }
            $0.userStoredPreferences.selectedServers = { nil }
            $0.userStoredPreferences.setSelectedServers = { config in
                capturedSelectedServers.value = config
            }
        } operation: {
            ZcashSDKEnvironment.initializeSelectedServersIfNeeded(for: .mainnet)
        }

        let result = try XCTUnwrap(capturedSelectedServers.value, "Migration should have persisted a selectedServers config")

        XCTAssertEqual(result.mode, .manual, "Legacy zcash-infra.com server should preserve manual mode")
        XCTAssertEqual(result.servers.count, 1, "Manual mode should preserve the legacy server")
        XCTAssertEqual(result.servers.first?.host, infraServer.host)
        XCTAssertEqual(result.servers.first?.port, infraServer.port)
        XCTAssertTrue(result.servers.first?.isCustom == true, "Legacy infra server should normalize to custom")
    }

    // MARK: - Default server user → automatic mode

    func testDefaultServerUser_migratesToAutomaticMode() throws {
        let defaultEndpoint = ZcashSDKEnvironment.defaultEndpoint(for: .mainnet)
        let defaultServer = UserPreferencesStorage.ServerConfig(
            host: defaultEndpoint.host,
            port: defaultEndpoint.port,
            isCustom: false
        )

        let capturedSelectedServers = UncheckedSendableBox<UserPreferencesStorage.SelectedServersConfig?>(nil)

        withDependencies {
            $0.userStoredPreferences.server = { defaultServer }
            $0.userStoredPreferences.selectedServers = { nil }
            $0.userStoredPreferences.setSelectedServers = { config in
                capturedSelectedServers.value = config
            }
        } operation: {
            ZcashSDKEnvironment.initializeSelectedServersIfNeeded(for: .mainnet)
        }

        let result = try XCTUnwrap(capturedSelectedServers.value, "Migration should have persisted a selectedServers config")

        XCTAssertEqual(result.mode, .automatic, "Default server user should be set to automatic mode")
        XCTAssertTrue(result.servers.isEmpty, "Automatic mode should have empty servers array")
    }

    // MARK: - Non-default known server user → manual mode

    func testNonDefaultKnownServerUser_migratesToManualMode() throws {
        let knownServer = UserPreferencesStorage.ServerConfig(
            host: "zec.rocks",
            port: 443,
            isCustom: false
        )

        let capturedSelectedServers = UncheckedSendableBox<UserPreferencesStorage.SelectedServersConfig?>(nil)

        withDependencies {
            $0.userStoredPreferences.server = { knownServer }
            $0.userStoredPreferences.selectedServers = { nil }
            $0.userStoredPreferences.setSelectedServers = { config in
                capturedSelectedServers.value = config
            }
        } operation: {
            ZcashSDKEnvironment.initializeSelectedServersIfNeeded(for: .mainnet)
        }

        let result = try XCTUnwrap(capturedSelectedServers.value, "Migration should have persisted a selectedServers config")

        XCTAssertEqual(result.mode, .manual, "Non-default known server user should stay in manual mode")
        XCTAssertEqual(result.servers.count, 1, "Manual mode should preserve the selected known server")
        XCTAssertEqual(result.servers.first?.host, knownServer.host)
        XCTAssertEqual(result.servers.first?.port, knownServer.port)
        XCTAssertTrue(result.servers.first?.isCustom == false, "Known server should not be marked as custom")
    }

    func testUnknownNonCustomServerUser_migratesToManualCustomMode() throws {
        let unknownServer = UserPreferencesStorage.ServerConfig(
            host: "previously-known.example.com",
            port: 443,
            isCustom: false
        )

        let capturedSelectedServers = UncheckedSendableBox<UserPreferencesStorage.SelectedServersConfig?>(nil)

        withDependencies {
            $0.userStoredPreferences.server = { unknownServer }
            $0.userStoredPreferences.selectedServers = { nil }
            $0.userStoredPreferences.setSelectedServers = { config in
                capturedSelectedServers.value = config
            }
        } operation: {
            ZcashSDKEnvironment.initializeSelectedServersIfNeeded(for: .mainnet)
        }

        let result = try XCTUnwrap(capturedSelectedServers.value, "Migration should have persisted a selectedServers config")

        XCTAssertEqual(result.mode, .manual, "Unknown non-default server should preserve manual mode")
        XCTAssertEqual(result.servers.count, 1, "Manual mode should preserve the selected server")
        XCTAssertEqual(result.servers.first?.host, unknownServer.host)
        XCTAssertEqual(result.servers.first?.port, unknownServer.port)
        XCTAssertTrue(result.servers.first?.isCustom == true, "Unknown server should normalize to custom")
    }

    // MARK: - New user → automatic mode

    func testNewUser_defaultsToAutomaticMode() throws {
        let capturedSelectedServers = UncheckedSendableBox<UserPreferencesStorage.SelectedServersConfig?>(nil)

        withDependencies {
            $0.userStoredPreferences.server = { nil }
            $0.userStoredPreferences.selectedServers = { nil }
            $0.userStoredPreferences.setSelectedServers = { config in
                capturedSelectedServers.value = config
            }
        } operation: {
            ZcashSDKEnvironment.initializeSelectedServersIfNeeded(for: .mainnet)
        }

        let result = try XCTUnwrap(capturedSelectedServers.value, "Migration should have persisted a selectedServers config")

        XCTAssertEqual(result.mode, .automatic, "New user should default to automatic mode")
        XCTAssertTrue(result.servers.isEmpty, "Automatic mode should have empty servers array")
    }

    // MARK: - Already migrated user is not re-migrated

    func testAlreadyMigratedUser_noOp() {
        let existingConfig = UserPreferencesStorage.SelectedServersConfig(
            mode: .manual,
            servers: [.init(host: "zec.rocks", port: 443, isCustom: false)]
        )

        let setSelectedServersCalled = UncheckedSendableBox(false)

        withDependencies {
            $0.userStoredPreferences.selectedServers = { existingConfig }
            $0.userStoredPreferences.setSelectedServers = { _ in
                setSelectedServersCalled.value = true
            }
        } operation: {
            ZcashSDKEnvironment.initializeSelectedServersIfNeeded(for: .mainnet)
        }

        XCTAssertFalse(setSelectedServersCalled.value, "Should not overwrite existing selectedServers config")
    }

    func testManualSelectedServerOverridesLegacyServerConfig() {
        let manualServer = UserPreferencesStorage.ServerConfig(
            host: "manual.example.com",
            port: 9067,
            isCustom: true
        )
        let legacyServer = UserPreferencesStorage.ServerConfig(
            host: "old.example.com",
            port: 443,
            isCustom: false
        )

        withDependencies {
            $0.userStoredPreferences.server = { legacyServer }
            $0.userStoredPreferences.selectedServers = {
                .init(mode: .manual, servers: [manualServer])
            }
        } operation: {
            let result = ZcashSDKEnvironment.serverConfig(for: .mainnet)

            XCTAssertEqual(result, manualServer)
        }
    }

    func testAutomaticModeUsesLegacyServerConfig() {
        let legacyServer = UserPreferencesStorage.ServerConfig(
            host: "eu.zec.stardust.rest",
            port: 443,
            isCustom: false
        )

        withDependencies {
            $0.userStoredPreferences.server = { legacyServer }
            $0.userStoredPreferences.selectedServers = {
                .init(mode: .automatic, servers: [])
            }
        } operation: {
            let result = ZcashSDKEnvironment.serverConfig(for: .mainnet)

            XCTAssertEqual(result, legacyServer)
        }
    }

    func testIsKnownEndpoint_isNetworkAware() {
        let testnetEndpoint = ZcashSDKEnvironment.defaultEndpoint(for: .testnet)

        XCTAssertTrue(ZcashSDKEnvironment.isKnownEndpoint(host: "zec.rocks", port: 443, network: .mainnet))
        XCTAssertFalse(ZcashSDKEnvironment.isKnownEndpoint(host: "zec.rocks", port: 443, network: .testnet))
        XCTAssertTrue(
            ZcashSDKEnvironment.isKnownEndpoint(
                host: testnetEndpoint.host,
                port: testnetEndpoint.port,
                network: .testnet
            )
        )
    }
}

@MainActor
class ServerSetupChangeDetectionTests: XCTestCase {
    func testCustomServerEditMarksStateChangedWhenCustomIsSelected() async {
        let customServer = UserPreferencesStorage.ServerConfig(
            host: "old-custom.example.com",
            port: 9067,
            isCustom: true
        )

        let store = TestStore(
            initialState: ServerSetup.State(
                connectionMode: .manual,
                topKServers: [.default]
            )
        ) {
            ServerSetup()
        }

        store.dependencies.zcashSDKEnvironment = .testValue
        store.dependencies.userStoredPreferences.selectedServers = {
            .init(mode: .manual, servers: [customServer])
        }

        let customLabel = String(localizable: .serverSetupCustom)
        let originalValue = customServer.serverString()
        let updatedValue = "new-custom.example.com:9067"

        await store.send(.onAppear) { state in
            state.network = .testnet
            state.activeSyncServer = ZcashSDKEnvironment.defaultEndpoint(for: .testnet).server()
            state.customServer = originalValue
            state.initialCustomServer = originalValue
            state.connectionMode = .manual
            state.initialConnectionMode = .manual
            state.selectedServer = customLabel
            state.initialSelectedServer = customLabel
            state.servers = [.custom]
        }

        XCTAssertFalse(store.state.hasChanges)

        await store.send(.binding(.set(\.customServer, updatedValue))) { state in
            state.customServer = updatedValue
        }

        XCTAssertTrue(store.state.hasChanges)
    }

    func testSwitchSucceededResetsChangeTracking() async {
        let customServer = UserPreferencesStorage.ServerConfig(
            host: "old-custom.example.com",
            port: 9067,
            isCustom: true
        )

        let store = TestStore(
            initialState: ServerSetup.State(
                connectionMode: .manual,
                topKServers: [.default]
            )
        ) {
            ServerSetup()
        }

        store.dependencies.zcashSDKEnvironment = .testValue
        store.dependencies.userStoredPreferences.selectedServers = {
            .init(mode: .manual, servers: [customServer])
        }

        let customLabel = String(localizable: .serverSetupCustom)
        let originalValue = customServer.serverString()
        let updatedValue = "new-custom.example.com:9067"

        await store.send(.onAppear) { state in
            state.network = .testnet
            state.activeSyncServer = ZcashSDKEnvironment.defaultEndpoint(for: .testnet).server()
            state.customServer = originalValue
            state.initialCustomServer = originalValue
            state.connectionMode = .manual
            state.initialConnectionMode = .manual
            state.selectedServer = customLabel
            state.initialSelectedServer = customLabel
            state.servers = [.custom]
        }

        await store.send(.binding(.set(\.customServer, updatedValue))) { state in
            state.customServer = updatedValue
        }

        XCTAssertTrue(store.state.hasChanges)

        await store.send(.switchSucceeded(updatedValue)) { state in
            state.isUpdatingServer = false
            state.initialConnectionMode = .manual
            state.initialSelectedServer = customLabel
            state.initialCustomServer = updatedValue
            state.activeSyncServer = updatedValue
        }

        XCTAssertFalse(store.state.hasChanges)
    }

    func testConnectionModeChangeMarksStateChanged() async {
        let activeEndpoint = ZcashSDKEnvironment.defaultEndpoint(for: .testnet)
        let store = TestStore(
            initialState: ServerSetup.State(
                connectionMode: .automatic,
                topKServers: [.default]
            )
        ) {
            ServerSetup()
        }

        store.dependencies.zcashSDKEnvironment = .testValue
        store.dependencies.userStoredPreferences.selectedServers = {
            .init(mode: .automatic, servers: [])
        }

        await store.send(.onAppear) { state in
            state.network = .testnet
            state.activeSyncServer = ZcashSDKEnvironment.defaultEndpoint(for: .testnet).server()
            state.connectionMode = .automatic
            state.initialConnectionMode = .automatic
            state.servers = [.custom]
        }

        XCTAssertFalse(store.state.hasChanges)

        await store.send(.connectionModeChanged(.manual)) { state in
            state.connectionMode = .manual
            state.selectedServer = activeEndpoint.server()
        }

        XCTAssertTrue(store.state.hasChanges)
    }

    func testManualModePreselectsKnownActiveEndpoint() async {
        let activeEndpoint = LightWalletEndpoint(
            address: "zec.rocks",
            port: 443,
            secure: true,
            streamingCallTimeoutInMillis: ZcashSDKEnvironment.ZcashSDKConstants.streamingCallTimeoutInMillis
        )
        let store = TestStore(
            initialState: ServerSetup.State(
                connectionMode: .automatic,
                topKServers: [.default]
            )
        ) {
            ServerSetup()
        }
        store.dependencies.zcashSDKEnvironment = testEnvironment {
            activeEndpoint.serverConfig()
        }

        await store.send(.binding(.set(\.activeSyncServer, activeEndpoint.server()))) { state in
            state.activeSyncServer = activeEndpoint.server()
        }

        await store.send(.connectionModeChanged(.manual)) { state in
            state.connectionMode = .manual
            state.selectedServer = activeEndpoint.server()
        }

        XCTAssertTrue(store.state.hasChanges)
    }

    func testManualModePreselectsUnknownActiveEndpointAsCustom() async {
        let customLabel = String(localizable: .serverSetupCustom)
        let activeEndpoint = LightWalletEndpoint(
            address: "custom.example.com",
            port: 9067,
            secure: true,
            streamingCallTimeoutInMillis: ZcashSDKEnvironment.ZcashSDKConstants.streamingCallTimeoutInMillis
        )
        let store = TestStore(
            initialState: ServerSetup.State(
                connectionMode: .automatic,
                topKServers: [.default]
            )
        ) {
            ServerSetup()
        }
        store.dependencies.zcashSDKEnvironment = testEnvironment {
            activeEndpoint.serverConfig(isCustom: true)
        }

        await store.send(.binding(.set(\.activeSyncServer, activeEndpoint.server()))) { state in
            state.activeSyncServer = activeEndpoint.server()
        }

        await store.send(.connectionModeChanged(.manual)) { state in
            state.connectionMode = .manual
            state.selectedServer = customLabel
            state.customServer = activeEndpoint.server()
        }

        XCTAssertTrue(store.state.hasChanges)
    }

    func testManualModeRefreshesActiveEndpointBeforePreselecting() async {
        let initialServer = ZcashSDKEnvironment.defaultEndpoint(for: .testnet).serverConfig()
        let latestServer = UserPreferencesStorage.ServerConfig(
            host: "custom.example.com",
            port: 9067,
            isCustom: true
        )
        let activeServer = UncheckedSendableBox(initialServer)
        let customLabel = String(localizable: .serverSetupCustom)
        let store = TestStore(
            initialState: ServerSetup.State(
                connectionMode: .automatic,
                topKServers: [.default]
            )
        ) {
            ServerSetup()
        }

        store.dependencies.zcashSDKEnvironment = testEnvironment {
            activeServer.value
        }
        store.dependencies.userStoredPreferences.selectedServers = {
            .init(mode: .automatic, servers: [])
        }

        await store.send(.onAppear) { state in
            state.network = .testnet
            state.activeSyncServer = initialServer.serverString()
            state.connectionMode = .automatic
            state.initialConnectionMode = .automatic
            state.servers = [.custom]
        }

        activeServer.value = latestServer

        await store.send(.connectionModeChanged(.manual)) { state in
            state.connectionMode = .manual
            state.activeSyncServer = latestServer.serverString()
            state.selectedServer = customLabel
            state.customServer = latestServer.serverString()
        }

        XCTAssertTrue(store.state.hasChanges)
    }

    func testManualModeWithMissingActiveEndpointRequiresSelection() async {
        let store = TestStore(
            initialState: ServerSetup.State(
                connectionMode: .automatic,
                topKServers: [.default]
            )
        ) {
            ServerSetup()
        }

        await store.send(.connectionModeChanged(.manual)) { state in
            state.connectionMode = .manual
        }

        XCTAssertNil(store.state.selectedServer)
        XCTAssertTrue(store.state.connectionMode == .manual && store.state.selectedServer == nil)
    }

    func testSavingManualModeAfterAutomaticPinsActiveEndpoint() async throws {
        let activeEndpoint = ZcashSDKEnvironment.defaultEndpoint(for: .testnet)
        let capturedSelectedServers = UncheckedSendableBox<UserPreferencesStorage.SelectedServersConfig?>(nil)
        let capturedServer = UncheckedSendableBox<UserPreferencesStorage.ServerConfig?>(nil)
        let store = TestStore(
            initialState: ServerSetup.State(
                connectionMode: .automatic,
                topKServers: [.default]
            )
        ) {
            ServerSetup()
        }

        store.dependencies.zcashSDKEnvironment = .testValue
        store.dependencies.mainQueue = .immediate
        store.dependencies.userStoredPreferences.selectedServers = {
            .init(mode: .automatic, servers: [])
        }
        store.dependencies.userStoredPreferences.setSelectedServers = { config in
            capturedSelectedServers.value = config
        }
        store.dependencies.userStoredPreferences.setServer = { config in
            capturedServer.value = config
        }

        await store.send(.onAppear) { state in
            state.network = .testnet
            state.activeSyncServer = activeEndpoint.server()
            state.connectionMode = .automatic
            state.initialConnectionMode = .automatic
            state.servers = [.custom]
        }

        await store.send(.connectionModeChanged(.manual)) { state in
            state.connectionMode = .manual
            state.selectedServer = activeEndpoint.server()
        }

        await store.send(.setServerTapped) { state in
            state.isUpdatingServer = true
        }

        await store.receive(.switchSucceeded(activeEndpoint.server())) { state in
            state.isUpdatingServer = false
            state.initialConnectionMode = .manual
            state.initialSelectedServer = activeEndpoint.server()
            state.activeSyncServer = activeEndpoint.server()
        }

        let selectedServers = try XCTUnwrap(capturedSelectedServers.value)
        XCTAssertEqual(selectedServers.mode, .manual)
        XCTAssertEqual(selectedServers.servers.first?.host, activeEndpoint.host)
        XCTAssertEqual(selectedServers.servers.first?.port, activeEndpoint.port)
        XCTAssertEqual(capturedServer.value?.host, activeEndpoint.host)
        XCTAssertEqual(capturedServer.value?.port, activeEndpoint.port)
    }

    func testAutomaticSaveSurfacesPersistenceFailure() async {
        let customLabel = String(localizable: .serverSetupCustom)
        let manualServer = UserPreferencesStorage.ServerConfig(
            host: "manual.example.com",
            port: 9067,
            isCustom: true
        )
        let automaticEndpoint = ZcashSDKEnvironment.defaultEndpoint(for: .testnet)
        let persistenceError = UserPreferencesStorage.UserPreferencesStorageError.selectedServersConfig.toZcashError()
        let store = TestStore(
            initialState: ServerSetup.State(
                connectionMode: .manual,
                topKServers: [.default]
            )
        ) {
            ServerSetup()
        }

        store.dependencies.zcashSDKEnvironment = .testValue
        store.dependencies.mainQueue = .immediate
        store.dependencies.userStoredPreferences.selectedServers = {
            .init(mode: .manual, servers: [manualServer])
        }
        store.dependencies.userStoredPreferences.setSelectedServers = { _ in
            throw UserPreferencesStorage.UserPreferencesStorageError.selectedServersConfig
        }
        store.dependencies.sdkSynchronizer = .mocked(
            switchToEndpoint: { _ in }
        )

        await store.send(.onAppear) { state in
            state.network = .testnet
            state.activeSyncServer = ZcashSDKEnvironment.defaultEndpoint(for: .testnet).server()
            state.customServer = manualServer.serverString()
            state.initialCustomServer = manualServer.serverString()
            state.connectionMode = .manual
            state.initialConnectionMode = .manual
            state.selectedServer = customLabel
            state.initialSelectedServer = customLabel
            state.servers = [.custom]
        }

        await store.send(.connectionModeChanged(.automatic)) { state in
            state.connectionMode = .automatic
        }

        await store.send(.evaluatedServers(0, [automaticEndpoint])) { state in
            state.isEvaluatingServers = false
            state.topKServers = [.default]
            state.servers = [.custom]
            state.recommendedSyncServer = automaticEndpoint.server()
        }

        await store.send(.setServerTapped) { state in
            state.isUpdatingServer = true
        }

        await store.receive(.switchFailed(persistenceError)) { state in
            state.isUpdatingServer = false
            state.alert = AlertState.endpointSwitchFailed(persistenceError)
        }
    }

    func testAutomaticSaveRollsBackEndpointWhenLegacyServerPersistenceFails() async {
        let customLabel = String(localizable: .serverSetupCustom)
        let manualServer = UserPreferencesStorage.ServerConfig(
            host: "manual.example.com",
            port: 9067,
            isCustom: true
        )
        let automaticEndpoint = ZcashSDKEnvironment.defaultEndpoint(for: .testnet)
        let automaticServer = automaticEndpoint.serverConfig()
        let persistenceError = UserPreferencesStorage.UserPreferencesStorageError.serverConfig.toZcashError()
        let activeServer = UncheckedSendableBox(manualServer)
        let storedSelectedServers = UncheckedSendableBox<UserPreferencesStorage.SelectedServersConfig?>(
            .init(mode: .manual, servers: [manualServer])
        )
        let switchedEndpoints = UncheckedSendableBox<[String]>([])
        let store = TestStore(
            initialState: ServerSetup.State(
                connectionMode: .manual,
                topKServers: [.default]
            )
        ) {
            ServerSetup()
        }

        store.dependencies.zcashSDKEnvironment = testEnvironment {
            activeServer.value
        }
        store.dependencies.mainQueue = .immediate
        store.dependencies.userStoredPreferences.selectedServers = {
            storedSelectedServers.value
        }
        store.dependencies.userStoredPreferences.setSelectedServers = { config in
            storedSelectedServers.value = config
        }
        store.dependencies.userStoredPreferences.setServer = { _ in
            throw UserPreferencesStorage.UserPreferencesStorageError.serverConfig
        }
        store.dependencies.sdkSynchronizer = .mocked(
            switchToEndpoint: { endpoint in
                switchedEndpoints.value.append(endpoint.server())
                activeServer.value = endpoint.serverConfig()
            }
        )

        await store.send(.onAppear) { state in
            state.network = .testnet
            state.activeSyncServer = manualServer.serverString()
            state.customServer = manualServer.serverString()
            state.initialCustomServer = manualServer.serverString()
            state.connectionMode = .manual
            state.initialConnectionMode = .manual
            state.selectedServer = customLabel
            state.initialSelectedServer = customLabel
            state.servers = [.custom]
        }

        await store.send(.connectionModeChanged(.automatic)) { state in
            state.connectionMode = .automatic
        }

        await store.send(.evaluatedServers(0, [automaticEndpoint])) { state in
            state.isEvaluatingServers = false
            state.topKServers = [.default]
            state.servers = [.custom]
            state.recommendedSyncServer = automaticServer.serverString()
        }

        await store.send(.setServerTapped) { state in
            state.isUpdatingServer = true
        }

        await store.receive(.switchFailed(persistenceError)) { state in
            state.isUpdatingServer = false
            state.alert = AlertState.endpointSwitchFailed(persistenceError)
        }

        XCTAssertEqual(switchedEndpoints.value, [automaticEndpoint.server(), manualServer.serverString()])
        XCTAssertEqual(storedSelectedServers.value?.mode, .manual)
        XCTAssertEqual(storedSelectedServers.value?.servers.first?.host, manualServer.host)
        XCTAssertEqual(storedSelectedServers.value?.servers.first?.port, manualServer.port)
        XCTAssertEqual(activeServer.value.host, manualServer.host)
        XCTAssertEqual(activeServer.value.port, manualServer.port)
    }

    func testAutomaticSaveClearsStaleManualSelectionBeforeManualPreselect() async {
        let customLabel = String(localizable: .serverSetupCustom)
        let manualServer = UserPreferencesStorage.ServerConfig(
            host: "manual.example.com",
            port: 9067,
            isCustom: true
        )
        let automaticEndpoint = ZcashSDKEnvironment.defaultEndpoint(for: .testnet)
        let automaticServer = automaticEndpoint.serverConfig()
        let activeServer = UncheckedSendableBox(manualServer)
        let storedSelectedServers = UncheckedSendableBox<UserPreferencesStorage.SelectedServersConfig?>(
            .init(mode: .manual, servers: [manualServer])
        )
        let storedServer = UncheckedSendableBox<UserPreferencesStorage.ServerConfig?>(manualServer)
        let store = TestStore(
            initialState: ServerSetup.State(
                connectionMode: .manual,
                topKServers: [.default]
            )
        ) {
            ServerSetup()
        }

        store.dependencies.zcashSDKEnvironment = testEnvironment {
            activeServer.value
        }
        store.dependencies.mainQueue = .immediate
        store.dependencies.userStoredPreferences.server = {
            storedServer.value
        }
        store.dependencies.userStoredPreferences.selectedServers = {
            storedSelectedServers.value
        }
        store.dependencies.userStoredPreferences.setServer = { config in
            storedServer.value = config
            activeServer.value = config
        }
        store.dependencies.userStoredPreferences.setSelectedServers = { config in
            storedSelectedServers.value = config
        }
        store.dependencies.sdkSynchronizer = .mocked(
            switchToEndpoint: { endpoint in
                activeServer.value = endpoint.serverConfig()
            }
        )

        await store.send(.onAppear) { state in
            state.network = .testnet
            state.activeSyncServer = manualServer.serverString()
            state.customServer = manualServer.serverString()
            state.initialCustomServer = manualServer.serverString()
            state.connectionMode = .manual
            state.initialConnectionMode = .manual
            state.selectedServer = customLabel
            state.initialSelectedServer = customLabel
            state.servers = [.custom]
        }

        await store.send(.connectionModeChanged(.automatic)) { state in
            state.connectionMode = .automatic
        }

        await store.send(.evaluatedServers(0, [automaticEndpoint])) { state in
            state.isEvaluatingServers = false
            state.topKServers = [.default]
            state.servers = [.custom]
            state.recommendedSyncServer = automaticServer.serverString()
        }

        await store.send(.setServerTapped) { state in
            state.isUpdatingServer = true
        }

        await store.receive(.switchSucceeded(automaticServer.serverString())) { state in
            state.isUpdatingServer = false
            state.customServer = ""
            state.initialConnectionMode = .automatic
            state.initialCustomServer = ""
            state.selectedServer = nil
            state.initialSelectedServer = nil
            state.activeSyncServer = automaticServer.serverString()
        }

        await store.send(.connectionModeChanged(.manual)) { state in
            state.connectionMode = .manual
            state.activeSyncServer = automaticServer.serverString()
            state.selectedServer = automaticServer.serverString()
        }

        XCTAssertTrue(store.state.hasChanges)
    }

    func testOnAppearClearsUnsavedManualSelectionWhenStoredModeIsAutomatic() async {
        let customLabel = String(localizable: .serverSetupCustom)
        let store = TestStore(
            initialState: ServerSetup.State(
                connectionMode: .manual,
                customServer: "unsaved.example.com:9067",
                selectedServer: customLabel,
                topKServers: [.default]
            )
        ) {
            ServerSetup()
        }

        store.dependencies.zcashSDKEnvironment = .testValue
        store.dependencies.userStoredPreferences.selectedServers = {
            .init(mode: .automatic, servers: [])
        }

        await store.send(.onAppear) { state in
            state.network = .testnet
            state.activeSyncServer = ZcashSDKEnvironment.defaultEndpoint(for: .testnet).server()
            state.connectionMode = .automatic
            state.customServer = ""
            state.initialCustomServer = ""
            state.selectedServer = nil
            state.initialSelectedServer = nil
            state.initialConnectionMode = .automatic
            state.servers = [.custom]
        }

        XCTAssertFalse(store.state.hasChanges)
    }

    func testAutomaticEvaluationKeepsActiveSyncServerTruthful() async {
        let store = TestStore(
            initialState: ServerSetup.State(
                connectionMode: .automatic,
                topKServers: [.default]
            )
        ) {
            ServerSetup()
        }

        store.dependencies.zcashSDKEnvironment = .testValue

        await store.send(.onAppear) { state in
            state.network = .testnet
            state.activeSyncServer = ZcashSDKEnvironment.defaultEndpoint(for: .testnet).server()
            state.connectionMode = .automatic
            state.initialConnectionMode = .automatic
            state.servers = [.custom]
        }

        let evaluatedEndpoint = LightWalletEndpoint(
            address: "faster.example.com",
            port: 443,
            secure: true,
            streamingCallTimeoutInMillis: ZcashSDKEnvironment.ZcashSDKConstants.streamingCallTimeoutInMillis
        )

        await store.send(.evaluatedServers(0, [evaluatedEndpoint])) { state in
            state.isEvaluatingServers = false
            state.topKServers = [.hardcoded("faster.example.com:443")]
            state.servers = [.default, .custom]
            state.recommendedSyncServer = "faster.example.com:443"
        }

        XCTAssertEqual(
            store.state.activeSyncServer,
            ZcashSDKEnvironment.defaultEndpoint(for: .testnet).server(),
            "Benchmarking should not relabel the active sync endpoint before an actual switch"
        )
        XCTAssertEqual(store.state.recommendedSyncServer, "faster.example.com:443")
    }

    func testStaleEvaluatedServersResultIsIgnored() async {
        let store = TestStore(
            initialState: ServerSetup.State(
                connectionMode: .automatic,
                isEvaluatingServers: true,
                serverEvaluationRequestID: 2
            )
        ) {
            ServerSetup()
        }

        store.dependencies.zcashSDKEnvironment = .testValue

        let staleEndpoint = LightWalletEndpoint(
            address: "stale.example.com",
            port: 443,
            secure: true,
            streamingCallTimeoutInMillis: ZcashSDKEnvironment.ZcashSDKConstants.streamingCallTimeoutInMillis
        )

        await store.send(.evaluatedServers(1, [staleEndpoint]))

        XCTAssertTrue(store.state.isEvaluatingServers, "Older evaluation should not finish the latest request")
        XCTAssertTrue(store.state.topKServers.isEmpty, "Stale evaluation results should be ignored")
        XCTAssertNil(store.state.recommendedSyncServer, "Ignored stale results should not update recommendations")
    }

    private func testEnvironment(
        serverConfig: @escaping @Sendable () -> UserPreferencesStorage.ServerConfig
    ) -> ZcashSDKEnvironment {
        ZcashSDKEnvironment(
            latestCheckpoint: 0,
            endpoint: {
                serverConfig().endpoint(
                    streamingCallTimeoutInMillis: ZcashSDKEnvironment.ZcashSDKConstants.streamingCallTimeoutInMillis
                )
            },
            exchangeRateIPRateLimit: 120,
            exchangeRateStaleLimit: 15 * 60,
            memoCharLimit: MemoBytes.capacity,
            mnemonicWordsMaxCount: ZcashSDKEnvironment.ZcashSDKConstants.mnemonicWordsMaxCount,
            network: ZcashNetworkBuilder.network(for: .testnet),
            requiredTransactionConfirmations: ZcashSDKEnvironment.ZcashSDKConstants.requiredTransactionConfirmations,
            sdkVersion: "test",
            serverConfig: serverConfig,
            servers: ZcashSDKEnvironment.servers(for: .testnet),
            shieldingThreshold: Zatoshi(100_000),
            tokenName: "TAZ"
        )
    }
}
