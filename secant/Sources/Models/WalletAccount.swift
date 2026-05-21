//
//  WalletAccount.swift
//  modules
//
//  Created by Lukáš Korba on 26.11.2024.
//

import SwiftUI
@preconcurrency import ZcashLightClientKit

struct WalletAccount: Equatable, Hashable, Codable, Identifiable {
    enum Vendor: Int, Equatable, Codable, Hashable {
        case keystone = 0
        case zcash
        case keepKey = 2

        func icon() -> Image {
            switch self {
            case .keystone:
                return Asset.Assets.Partners.keystoneLogo.image
            case .keepKey:
                return Asset.Assets.Partners.keystoneLogo.image  // TODO [#3]: replace with KeepKey icon (ZI-31)
            case .zcash:
                return Asset.Assets.Icons.zashiLogoSq.image
            }
        }

        func isDefault() -> Bool {
            self == .zcash
        }

        func isHWWallet() -> Bool {
            self != .zcash
        }

        func name() -> String {
            switch self {
            case .keystone:
                return String(localizable: .accountsKeystone)
            case .keepKey:
                return String(localizable: .accountsKeepkey)
            case .zcash:
                return String(localizable: .accountsZashi)
            }
        }
    }

    let id: AccountUUID
    let vendor: Vendor
    var defaultUA: UnifiedAddress?
    var privateUA: UnifiedAddress?
    var seedFingerprint: [UInt8]?
    var zip32AccountIndex: Zip32AccountIndex?
    let account: Account

    var unifiedAddress: String? {
        defaultUA?.stringEncoded
    }

    var privateUnifiedAddress: String? {
        privateUA?.stringEncoded
    }

    var saplingAddress: String? {
        try? defaultUA?.saplingReceiver().stringEncoded
    }

    var transparentAddress: String? {
        try? defaultUA?.transparentReceiver().stringEncoded
    }

    init(_ account: Account) {
        self.id = account.id
        let source = account.keySource ?? ""
        if source == String(localizable: .accountsKeystone).lowercased() {
            self.vendor = .keystone
        } else if source == String(localizable: .accountsKeepkey).lowercased() {
            self.vendor = .keepKey
        } else {
            self.vendor = .zcash
        }
        self.seedFingerprint = account.seedFingerprint
        self.zip32AccountIndex = account.hdAccountIndex
        self.account = account
    }
}
