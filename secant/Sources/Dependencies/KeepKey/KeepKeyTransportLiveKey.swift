//
//  KeepKeyTransportLiveKey.swift
//  Zashi
//
//  ZI-17/ZI-18: WalletConnect v2 relay transport — configure SDK, create pairing, settle session.
//  ZI-19: getOrchardFVK — ZcashGetOrchardFVK → ZcashOrchardFVK over WC keepkey_request.
//  ZI-20: displayAddress — ZcashDisplayAddress → ZcashAddress over WC keepkey_request.
//  ZI-21: signPCZT — ZcashSignPCZT → action stream → ZcashSignedPCZT (action loop stubbed
//         pending per-action data extraction from PCZT).
//  ZI-22: Keychain session persistence deferred.
//

import Combine
import ComposableArchitecture
import Foundation
import Security
import SwiftProtobuf
import WalletConnectRelay
import WalletConnectSign

// MARK: - Error types

enum KeepKeyTransportError: Error, LocalizedError {
    case missingProjectId
    case sessionSetupTimeout
    case noActiveSession
    case connectionFailed(String)
    case protocolError(String)

    var errorDescription: String? {
        switch self {
        case .missingProjectId:
            return "walletConnectProjectId is missing from PartnerKeys.plist."
        case .sessionSetupTimeout:
            return "KeepKey Desktop did not approve the WalletConnect session in time."
        case .noActiveSession:
            return "No active KeepKey WalletConnect session. Call connect() first."
        case .connectionFailed(let reason):
            return "KeepKey connection failed: \(reason)"
        case .protocolError(let reason):
            return "KeepKey protocol error: \(reason)"
        }
    }
}

// MARK: - URLSession WebSocket factory (no Starscream dependency)

private final class URLSessionWebSocket: NSObject, WebSocketConnecting, URLSessionWebSocketDelegate {
    var isConnected: Bool = false
    var onConnect: (() -> Void)?
    var onDisconnect: ((Error?) -> Void)?
    var onText: ((String) -> Void)?
    var request: URLRequest

    private var task: URLSessionWebSocketTask?
    private var urlSession: URLSession?

    init(url: URL) {
        self.request = URLRequest(url: url)
    }

    func connect() {
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        urlSession = session
        task = session.webSocketTask(with: request)
        task?.resume()
        receiveNext()
    }

    func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    func write(string: String, completion: (() -> Void)?) {
        task?.send(.string(string)) { _ in completion?() }
    }

    private func receiveNext() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(.string(let text)):
                self.onText?(text)
                self.receiveNext()
            case .success:
                self.receiveNext()
            case .failure(let error):
                self.onDisconnect?(error)
            }
        }
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        isConnected = true
        onConnect?()
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        isConnected = false
        onDisconnect?(nil)
    }
}

private struct URLSessionWebSocketFactory: WebSocketFactory {
    func create(with url: URL) -> WebSocketConnecting {
        URLSessionWebSocket(url: url)
    }
}

// MARK: - WalletConnect namespace constants
//
// Zashi uses a custom "keepkey" namespace. KeepKey Desktop must be configured
// with the same namespace and method list. Update here if the Desktop side changes.

private enum WCKeepKey {
    static let namespace = "keepkey"
    static let chainId   = "keepkey:1"           // CAIP-2, namespace 3-8 chars, ref 1-32 chars
    static let methods: Set<String> = [
        "keepkey_request"                         // single multiplex method for all proto messages
    ]
    static let events: Set<String> = []
    static let sessionTimeout: TimeInterval = 300 // 5 minutes for user to approve on Desktop
    static let requestTimeout: TimeInterval = 60  // per-request response timeout
}

// MARK: - One-time SDK configuration

private enum WCConfiguration {
    private static var configured = false
    private static let lock = NSLock()

    static func configureIfNeeded(projectId: String) {
        lock.lock()
        defer { lock.unlock() }
        guard !configured else { return }
        let metadata = AppMetadata(
            name: "Zashi",
            description: "Zashi Zcash Wallet — KeepKey Hardware Wallet Integration",
            url: "https://keepkey.com",
            icons: []
        )
        Networking.configure(projectId: projectId, socketFactory: URLSessionWebSocketFactory())
        Pair.configure(metadata: metadata)
        configured = true
    }
}

// MARK: - ZI-22: Keychain session persistence
//
// Stores the active WalletConnect session topic so the user only needs to
// scan the QR code once per install. The topic is cleared on explicit disconnect.

private enum WCSessionKeychain {
    private static let service = "com.keepkey.wc.session"
    private static let account = "topic"

    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ topic: String) {
        let data = Data(topic.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        if SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary) == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Active session store

private actor SessionStore {
    var topic: String?

    init() {
        self.topic = WCSessionKeychain.load()
    }

    func set(_ topic: String) {
        self.topic = topic
        WCSessionKeychain.save(topic)
    }

    func clear() {
        topic = nil
        WCSessionKeychain.delete()
    }

    func current() -> String? { topic }
}

private let sessionStore = SessionStore()

// MARK: - WC proto wire format
//
// keepkey_request params / response body:
//   { "msgType": <uint32>, "data": "<base64-encoded serialized proto>" }

private struct KKProtoEnvelope: Codable {
    let msgType: UInt32
    let data: String    // standard Base64 encoding of the serialized proto bytes
}

// Message type IDs — mirrors MessageType enum in messages.proto
private enum KKMsgType {
    static let zcashSignPCZT: UInt32       = 1300
    static let zcashPCZTAction: UInt32     = 1301
    static let zcashPCZTActionAck: UInt32  = 1302
    static let zcashSignedPCZT: UInt32     = 1303
    static let zcashGetOrchardFVK: UInt32  = 1304
    static let zcashOrchardFVK: UInt32     = 1305
    static let zcashDisplayAddress: UInt32 = 1308
    static let zcashAddress: UInt32        = 1309
}

// MARK: - Thread-safe one-shot continuation
//
// Prevents double-resume when both the send-failure path (Task) and the
// response-publisher path reach the same CheckedContinuation.

private final class OnceBox<T>: @unchecked Sendable {
    private var continuation: CheckedContinuation<T, Error>?
    private let lock = NSLock()

    init(_ continuation: CheckedContinuation<T, Error>) {
        self.continuation = continuation
    }

    func resume(returning value: T) {
        lock.lock(); defer { lock.unlock() }
        guard let c = continuation else { return }
        continuation = nil
        c.resume(returning: value)
    }

    func resume(throwing error: Error) {
        lock.lock(); defer { lock.unlock() }
        guard let c = continuation else { return }
        continuation = nil
        c.resume(throwing: error)
    }
}

// MARK: - WC request/response helpers

/// Sends a single `keepkey_request` JSON-RPC call and returns the raw response envelope.
/// The caller is responsible for decoding the envelope into the expected proto type.
private func wcRawRequest(topic: String, msgType: UInt32, requestData: Data) async throws -> KKProtoEnvelope {
    guard let chain = Blockchain(WCKeepKey.chainId) else {
        throw KeepKeyTransportError.protocolError("Invalid chain ID: \(WCKeepKey.chainId)")
    }
    let envelope = KKProtoEnvelope(msgType: msgType, data: requestData.base64EncodedString())
    let wcReq = Request(
        topic: topic,
        method: WCKeepKey.methods.first!,
        params: AnyCodable(envelope),
        chainId: chain
    )

    let response: Response = try await withCheckedThrowingContinuation { continuation in
        let box = OnceBox(continuation)
        var cancellables = Set<AnyCancellable>()

        Sign.instance.sessionResponsePublisher
            .filter { $0.id == wcReq.id }
            .first()
            .timeout(.seconds(WCKeepKey.requestTimeout), scheduler: DispatchQueue.global())
            .sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        box.resume(throwing: KeepKeyTransportError.protocolError(
                            "Response timeout (msgType \(msgType))"
                        ))
                    }
                    cancellables.removeAll()
                },
                receiveValue: { resp in
                    box.resume(returning: resp)
                    cancellables.removeAll()
                }
            )
            .store(in: &cancellables)

        Task {
            do {
                try await Sign.instance.request(params: wcReq)
            } catch {
                box.resume(throwing: KeepKeyTransportError.connectionFailed(error.localizedDescription))
                cancellables.removeAll()
            }
        }
    }

    switch response.result {
    case .error(let err):
        throw KeepKeyTransportError.protocolError("WC error \(err.code): \(err.message)")
    case .response(let anyCodable):
        return try anyCodable.get(KKProtoEnvelope.self)
    }
}

/// Typed WC request — sends a serialized proto message and decodes the response as `Resp`.
private func wcProtoRequest<Resp: SwiftProtobuf.Message>(
    topic: String,
    msgType: UInt32,
    requestData: Data,
    expectedMsgType: UInt32
) async throws -> Resp {
    let envelope = try await wcRawRequest(topic: topic, msgType: msgType, requestData: requestData)
    guard envelope.msgType == expectedMsgType else {
        throw KeepKeyTransportError.protocolError(
            "Expected msgType \(expectedMsgType), got \(envelope.msgType)"
        )
    }
    guard let protoData = Data(base64Encoded: envelope.data) else {
        throw KeepKeyTransportError.protocolError("Invalid Base64 in WC response")
    }
    return try Resp(serializedBytes: protoData)
}

// MARK: - liveValue

extension KeepKeyTransportClient: DependencyKey {
    static let liveValue = KeepKeyTransportClient(
        // ZI-18: configure WC SDK, create pairing URI, propose session, wait for settlement
        connect: { onPairingURI in
            guard !keepKeyWCProjectId.isEmpty else { throw KeepKeyTransportError.missingProjectId }
            WCConfiguration.configureIfNeeded(projectId: keepKeyWCProjectId)

            // Create the pairing and immediately hand the URI to the caller for QR display
            let uri = try await Pair.instance.create()
            onPairingURI(uri.absoluteString)

            // Propose a session on that pairing topic
            guard let chain = Blockchain(WCKeepKey.chainId) else {
                throw KeepKeyTransportError.protocolError("Invalid chain ID: \(WCKeepKey.chainId)")
            }
            let namespace = ProposalNamespace(
                chains: [chain],
                methods: WCKeepKey.methods,
                events: WCKeepKey.events
            )
            try await Sign.instance.connect(
                requiredNamespaces: [WCKeepKey.namespace: namespace],
                topic: uri.topic
            )

            // Wait until KeepKey Desktop approves (sessionSettlePublisher fires)
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                var cancellables = Set<AnyCancellable>()

                Sign.instance.sessionSettlePublisher
                    .first()
                    .timeout(.seconds(WCKeepKey.sessionTimeout), scheduler: DispatchQueue.global())
                    .sink(
                        receiveCompletion: { completion in
                            if case .failure = completion {
                                continuation.resume(throwing: KeepKeyTransportError.sessionSetupTimeout)
                            }
                            cancellables.removeAll()
                        },
                        receiveValue: { session in
                            Task { await sessionStore.set(session.topic) }
                            continuation.resume()
                        }
                    )
                    .store(in: &cancellables)
            }
        },

        disconnect: {
            guard let topic = await sessionStore.current() else { return }
            try await Sign.instance.disconnect(topic: topic)
            await sessionStore.clear()
        },

        // ZI-19: ZcashGetOrchardFVK → ZcashOrchardFVK
        //
        // Returns ak, nk, rivk from the device. seedFingerprint, ufvk, and
        // unifiedAddress are left empty — deriving them from the raw FVK
        // components requires BLAKE2b and ZcashLightClientKit key-encoding
        // APIs and belongs in the feature store, not the transport layer.
        getOrchardFVK: { account in
            guard let topic = await sessionStore.current() else {
                throw KeepKeyTransportError.noActiveSession
            }
            var req = ZcashGetOrchardFVK()
            req.account = account
            let resp: ZcashOrchardFVK = try await wcProtoRequest(
                topic: topic,
                msgType: KKMsgType.zcashGetOrchardFVK,
                requestData: try req.serializedData(),
                expectedMsgType: KKMsgType.zcashOrchardFVK
            )
            return OrchardFVK(
                ak: resp.ak,
                nk: resp.nk,
                rivk: resp.rivk,
                seedFingerprint: Data(),
                ufvk: "",
                unifiedAddress: ""
            )
        },

        // ZI-20: ZcashDisplayAddress → ZcashAddress
        displayAddress: { request in
            guard let topic = await sessionStore.current() else {
                throw KeepKeyTransportError.noActiveSession
            }
            var req = ZcashDisplayAddress()
            req.account = request.account
            req.address = request.address
            req.ak = request.ak
            req.nk = request.nk
            req.rivk = request.rivk
            let resp: ZcashAddress = try await wcProtoRequest(
                topic: topic,
                msgType: KKMsgType.zcashDisplayAddress,
                requestData: try req.serializedData(),
                expectedMsgType: KKMsgType.zcashAddress
            )
            return resp.address
        },

        // ZI-21: ZcashSignPCZT → ZcashPCZTActionAck × N → ZcashSignedPCZT
        //
        // Protocol is two-phase:
        //   1. Send ZcashSignPCZT with PCZT data and digest fields.
        //   2. For each Orchard action the device requests, send ZcashPCZTAction
        //      with the per-action randomizers (alpha, cv_net, sighash, etc.).
        //
        // The action loop is stubbed: per-action fields (alpha, cv_net, …) must be
        // extracted from the PCZT by the caller or the PCZT parser. PCZTSignRequest
        // does not yet carry per-action data; that extension is deferred to a
        // follow-on task once the PCZT parsing layer is in place.
        signPCZT: { request in
            guard let topic = await sessionStore.current() else {
                throw KeepKeyTransportError.noActiveSession
            }

            var signReq = ZcashSignPCZT()
            signReq.account = request.account
            signReq.pcztData = request.pcztData
            signReq.nActions = request.nActions
            signReq.totalAmount = request.totalAmount
            signReq.fee = request.fee
            signReq.branchID = request.branchId
            signReq.headerDigest = request.headerDigest
            signReq.transparentDigest = request.transparentDigest
            signReq.saplingDigest = request.saplingDigest
            signReq.orchardDigest = request.orchardDigest
            signReq.orchardFlags = request.orchardFlags
            signReq.orchardValueBalance = request.orchardValueBalance
            signReq.orchardAnchor = request.orchardAnchor
            signReq.nTransparentInputs = request.nTransparentInputs

            // Round 1: ZcashSignPCZT → ZcashPCZTActionAck
            let firstAck: ZcashPCZTActionAck = try await wcProtoRequest(
                topic: topic,
                msgType: KKMsgType.zcashSignPCZT,
                requestData: try signReq.serializedData(),
                expectedMsgType: KKMsgType.zcashPCZTActionAck
            )

            // Round 2+: stream per-action data until ZcashSignedPCZT
            var nextIndex = firstAck.nextIndex
            while nextIndex < request.nActions {
                // TODO [ZI-21]: build ZcashPCZTAction from PCZT-parsed per-action fields.
                // alpha, cv_net, sighash, nullifier, cmx, epk, etc. must be supplied
                // by the PCZT parser layer. Stubbing with an error until that exists.
                _ = nextIndex
                throw KeepKeyTransportError.protocolError(
                    "signPCZT action streaming not yet implemented — per-action data " +
                    "extraction from PCZT is required (ZI-21)"
                )
            }

            // Unreachable until action loop is implemented; satisfies return type.
            return SignedPCZT(signatures: [], txid: nil)
        }
    )
}

// Resolved once at app startup. Fails loudly at connect() if absent from PartnerKeys.plist.
let keepKeyWCProjectId: String = PartnerKeys.walletConnectProjectId ?? ""
