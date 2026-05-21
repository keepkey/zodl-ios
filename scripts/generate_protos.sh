#!/usr/bin/env bash
# Regenerates Swift proto bindings from the KeepKey proto files.
# Requires: protoc, protoc-gen-swift (brew install swift-protobuf)
# Run from the zodl-ios root directory.

set -euo pipefail

PROTO_DIR="$(dirname "$0")/../proto"
OUT_DIR="$(dirname "$0")/../secant/Sources/Generated/Proto"

mkdir -p "$OUT_DIR"

# messages-zcash.proto — standalone, no imports
protoc \
  --swift_out="$OUT_DIR" \
  --proto_path="$PROTO_DIR" \
  messages-zcash.proto

# types.proto — imports google/protobuf/descriptor.proto for wire annotations
protoc \
  --swift_out="$OUT_DIR" \
  --proto_path="$PROTO_DIR" \
  --proto_path="/opt/homebrew/include" \
  types.proto

# messages.proto — imports types.proto
protoc \
  --swift_out="$OUT_DIR" \
  --proto_path="$PROTO_DIR" \
  --proto_path="/opt/homebrew/include" \
  messages.proto

echo "Generated:"
ls -1 "$OUT_DIR"/*.pb.swift
