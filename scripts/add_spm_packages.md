# Adding SPM Packages via Xcode UI

The xcodeproj gem does not support adding remote SPM packages via script on this
project layout. Add them once through Xcode:

## Packages to add

Open `secant.xcodeproj` in Xcode, then go to:
**Project → secant → Package Dependencies → +**

### 1. SwiftProtobuf (ZI-2)

- URL: `https://github.com/apple/swift-protobuf`
- Requirement: Up to Next Major Version, `1.38.0`
- Product to add: **SwiftProtobuf**
- Add to targets: secant-testnet, secant-mainnet, secant-distrib, zashi-internal, zashi-testnet

### 2. WalletConnectSwiftV2 (ZI-1)

- URL: `https://github.com/WalletConnect/WalletConnectSwiftV2`
- Requirement: Up to Next Major Version, `1.0.0`
- Products to add: **WalletConnectSign**, **Web3Wallet**
- Add to targets: secant-testnet, secant-mainnet, secant-distrib, zashi-internal, zashi-testnet

## After adding

The proto-generated files (`Generated/Proto/messages-zcash.pb.swift`,
`Generated/Proto/messages.pb.swift`) import `SwiftProtobuf` and will compile
once that package is resolved.

The `KeepKeyTransportLiveKey.swift` stub will import `WalletConnectSign` once
ZI-18 is implemented.
