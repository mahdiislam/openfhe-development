from fastapi import FastAPI

from .config import settings
from .grpc_client import score_encrypted_query
from .model import encode_query_and_docs
from .schemas import RerankRequest, RerankResponse, RerankResult

app = FastAPI(title="Tiny Reranker REST Bridge")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "model": settings.model_name, "grpc_target": settings.grpc_target}


@app.post("/rerank", response_model=RerankResponse)
def rerank(req: RerankRequest) -> RerankResponse:
    query_embedding, doc_embeddings = encode_query_and_docs(req.query, req.documents)
    encrypted_scores, note = score_encrypted_query(
        request_id=req.request_id,
        top_k=req.top_k,
        query_embedding=query_embedding,
        doc_embeddings=doc_embeddings,
    )

    results = [RerankResult(doc_id=doc_id, encrypted_score_b64=enc) for doc_id, enc in encrypted_scores]
    return RerankResponse(
        request_id=req.request_id,
        model_name=settings.model_name,
        results=results,
        note=note,
    )
