# Tiny Reranker Bridge (Python + OpenFHE C++ + Protobuf/REST)

This folder is a concrete minimal layout for a privacy-preserving tiny reranker:

- Python REST bridge: query/doc text -> tiny open model embeddings
- Protobuf contract: request/response boundary
- C++ OpenFHE gRPC service: encrypted scoring boundary

## Layout

- proto/reranker.proto
- python_bridge/
  - app/main.py
  - app/model.py
  - app/grpc_client.py
  - app/schemas.py
  - app/config.py
  - scripts/gen_proto.sh
- cpp_openfhe_service/
  - CMakeLists.txt
  - src/main.cpp
  - src/service_impl.h
  - src/service_impl.cpp
  - src/openfhe_engine.h
  - src/openfhe_engine.cpp
  - scripts_gen_proto_cpp.sh

## Data flow

1. Client sends REST request to Python bridge.
2. Python bridge encodes query/documents with sentence-transformers/all-MiniLM-L6-v2.
3. Python bridge sends protobuf request to C++ gRPC service.
4. C++ service returns encrypted score bytes per doc.
5. Python bridge returns base64-encoded encrypted scores in REST response.

## Important note about this starter

The C++ OpenFHE engine is intentionally a stub in src/openfhe_engine.cpp.
It returns deterministic pseudo-ciphertexts so the system wiring is testable first.
Replace that method with real CKKS context/key loading, encrypted dot-product eval, and ciphertext serialization.

## 1) Generate protobuf code

Python:

    cd python_bridge
    python -m venv .venv
    source .venv/bin/activate
    pip install -r requirements.txt
    bash scripts/gen_proto.sh

C++:

    cd ..
    bash cpp_openfhe_service/scripts_gen_proto_cpp.sh

## 2) Start C++ service

    cd cpp_openfhe_service
    mkdir -p build
    cd build
    cmake ..
    make -j
    ./openfhe_reranker_service

## 3) Start Python REST bridge

In another terminal:

    cd python_bridge
    source .venv/bin/activate
    uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

## 4) Smoke test

    curl -s http://localhost:8000/health

    curl -s -X POST http://localhost:8000/rerank \
      -H "content-type: application/json" \
      -d '{
        "request_id": "demo-1",
        "query": "compact laptop for travel",
        "documents": [
          "ultrabook with long battery life",
          "wireless gaming mouse",
          "lightweight notebook with 16GB RAM"
        ],
        "top_k": 2
      }'

## Next replacement points for real FHE

- Python bridge:
  - Replace fake query encryption in app/grpc_client.py with real CKKS encrypt using client public key and serialization.
- C++ service:
  - Parse serialized_crypto_context / eval keys from protobuf request.
  - Deserialize encrypted_query_ckks into OpenFHE ciphertext.
  - Encode each candidate embedding as CKKS plaintext.
  - EvalMult + EvalSum for encrypted dot product per doc.
  - Serialize each score ciphertext into encrypted_score_ckks.

## Why this minimal split

- REST stays simple for app integration.
- gRPC/protobuf keeps strict typed boundary between Python and C++.
- OpenFHE implementation remains isolated to a single C++ service.
