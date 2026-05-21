//
//  KeepKeyTransportLiveKey.swift
//  Zashi
//
//  WalletConnect relay implementation is tracked in ZI-17 through ZI-22.
//  This stub throws until the WalletConnect Swift SDK is integrated.
//

import ComposableArchitecture
import Foundation

enum KeepKeyTransportError: Error, LocalizedError {
    case notImplemented
    case connectionFailed(String)
    case protocolError(String)

    var errorDescription: String? {
        switch self {
        case .notImplemented:
            return "KeepKey WalletConnect transport is not yet implemented on iOS (see ZI-17)."
        case .connectionFailed(let reason):
            return "KeepKey connection failed: \(reason)"
        case .protocolError(let reason):
            return "KeepKey protocol error: \(reason)"
        }
    }
}

extension KeepKeyTransportClient: DependencyKey {
    // TODO [#3]: Implement WalletConnect relay transport (ZI-17 through ZI-22).
    static let liveValue: KeepKeyTransportClient = .init(
        connect: { throw KeepKeyTransportError.notImplemented },
        disconnect: { throw KeepKeyTransportError.notImplemented },
        getOrchardFVK: { _ in throw KeepKeyTransportError.notImplemented },
        displayAddress: { _ in throw KeepKeyTransportError.notImplemented },
        signPCZT: { _ in throw KeepKeyTransportError.notImplemented }
    )
}
