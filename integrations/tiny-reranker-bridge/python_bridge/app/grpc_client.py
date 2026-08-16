from __future__ import annotations

import base64

import grpc

from .config import settings


def _fake_encrypt_query_for_stub(query_embedding: list[float]) -> bytes:
    # Replace this with real OpenFHE CKKS encryption in a production client.
    packed = ",".join(f"{x:.8f}" for x in query_embedding)
    return packed.encode("utf-8")


def score_encrypted_query(
    request_id: str,
    top_k: int,
    query_embedding: list[float],
    doc_embeddings: list[list[float]],
) -> tuple[list[tuple[str, str]], str]:
    try:
        from .generated import reranker_pb2
        from .generated import reranker_pb2_grpc
    except Exception as exc:
        raise RuntimeError(
            "Missing generated protobuf files. Run python_bridge/scripts/gen_proto.sh first."
        ) from exc

    candidates = []
    for idx, emb in enumerate(doc_embeddings):
        candidates.append(
            reranker_pb2.CandidateVector(doc_id=f"doc-{idx}", embedding=emb)
        )

    req = reranker_pb2.ScoreEncryptedQueryRequest(
        request_id=request_id,
        top_k=top_k,
        serialized_crypto_context=b"",
        serialized_eval_mult_key=b"",
        serialized_eval_sum_key=b"",
        encrypted_query_ckks=_fake_encrypt_query_for_stub(query_embedding),
        candidates=candidates,
    )

    with grpc.insecure_channel(settings.grpc_target) as channel:
        stub = reranker_pb2_grpc.RerankServiceStub(channel)
        resp = stub.ScoreEncryptedQuery(req)

    items = []
    for score in resp.encrypted_scores:
        items.append((score.doc_id, base64.b64encode(score.encrypted_score_ckks).decode("ascii")))

    return items, resp.note
