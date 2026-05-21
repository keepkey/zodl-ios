//
//  ConnectKeepKeyStore.swift
//  Zashi
//

import ComposableArchitecture

@Reducer
struct ConnectKeepKey {
    enum ConnectionStatus: Equatable {
        case waitingForPairingURI
        case showingQR(pairingURI: String)
        case waitingForApproval(pairingURI: String)
        case failed(String)
    }

    @ObservableState
    struct State: Equatable {
        var connectionStatus: ConnectionStatus = .waitingForPairingURI

        var pairingURI: String? {
            switch connectionStatus {
            case .showingQR(let uri), .waitingForApproval(let uri):
                return uri
            default:
                return nil
            }
        }
    }

    enum Action: Equatable {
        case cancelTapped
        case failed(String)
        case onAppear
        case pairingURIReceived(String)
        case retryTapped
        case sessionEstablished
    }

    @Dependency(\.keepKeyTransport) var keepKeyTransport

    init() { }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.connectionStatus = .waitingForPairingURI
                return .run { send in
                    do {
                        try await keepKeyTransport.connect { uri in
                            Task { await send(.pairingURIReceived(uri)) }
                        }
                        await send(.sessionEstablished)
                    } catch {
                        await send(.failed(error.localizedDescription))
                    }
                }

            case .pairingURIReceived(let uri):
                state.connectionStatus = .showingQR(pairingURI: uri)
                return .none

            case .sessionEstablished:
                return .none

            case .failed(let reason):
                state.connectionStatus = .failed(reason)
                return .none

            case .retryTapped:
                return .send(.onAppear)

            case .cancelTapped:
                return .none
            }
        }
    }
}
