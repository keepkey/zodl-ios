//
//  KeepKeyTransportInterface.swift
//  Zashi
//

import ComposableArchitecture
import Foundation

// MARK: - Supporting Types

struct OrchardFVK: Sendable, Equatable {
    let ak: Data               // 32 bytes — spend authorization key (Pallas point)
    let nk: Data               // 32 bytes — nullifier deriving key
    let rivk: Data             // 32 bytes — randomized internal viewing key
    let seedFingerprint: Data  // 32 bytes — BLAKE2b-256("KeepKey_Seed_FP ", ak||nk||rivk)
    let ufvk: String           // Encoded unified full viewing key
    let unifiedAddress: String
}

struct DisplayAddressRequest: Sendable, Equatable {
    let account: UInt32
    let address: String
    let ak: Data
    let nk: Data
    let rivk: Data
    let seedFingerprint: Data
}

struct PCZTSignRequest: Sendable, Equatable {
    let account: UInt32
    let pcztData: Data
    let nActions: UInt32
    let totalAmount: UInt64
    let fee: UInt64
    let branchId: UInt32
    let headerDigest: Data
    let transparentDigest: Data
    let saplingDigest: Data
    let orchardDigest: Data
    let orchardFlags: UInt32
    let orchardValueBalance: Int64
    let orchardAnchor: Data
    let seedFingerprint: Data
    let nTransparentInputs: UInt32
}

struct SignedPCZT: Sendable, Equatable {
    let signatures: [Data]  // 64-byte RedPallas signatures, one per Orchard action
    let txid: Data?         // 32-byte transaction ID
}

// MARK: - Dependency Client

extension DependencyValues {
    var keepKeyTransport: KeepKeyTransportClient {
        get { self[KeepKeyTransportClient.self] }
        set { self[KeepKeyTransportClient.self] = newValue }
    }
}

@DependencyClient
struct KeepKeyTransportClient {
    /// Initiates WalletConnect pairing. Calls `onPairingURI` with the WC URI to display as a QR
    /// code, then suspends until the KeepKey Desktop peer approves the session.
    var connect: @Sendable (_ onPairingURI: @Sendable (String) -> Void) async throws -> Void
    var disconnect: @Sendable () async throws -> Void
    var getOrchardFVK: @Sendable (_ account: UInt32) async throws -> OrchardFVK
    var displayAddress: @Sendable (_ request: DisplayAddressRequest) async throws -> String
    var signPCZT: @Sendable (_ request: PCZTSignRequest) async throws -> SignedPCZT
}
