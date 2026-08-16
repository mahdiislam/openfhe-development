#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROTO_FILE="$ROOT_DIR/proto/reranker.proto"
OUT_DIR="$ROOT_DIR/cpp_openfhe_service/generated"

mkdir -p "$OUT_DIR"

protoc -I "$ROOT_DIR/proto" \
  --cpp_out="$OUT_DIR" \
  --grpc_out="$OUT_DIR" \
  --plugin=protoc-gen-grpc="$(which grpc_cpp_plugin)" \
  "$PROTO_FILE"

echo "Generated C++ protobuf files in $OUT_DIR"
