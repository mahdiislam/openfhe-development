from pydantic import BaseModel, Field


class RerankRequest(BaseModel):
    request_id: str = Field(default="req-001")
    query: str
    documents: list[str]
    top_k: int = Field(default=5, ge=1, le=100)


class RerankResult(BaseModel):
    doc_id: str
    encrypted_score_b64: str


class RerankResponse(BaseModel):
    request_id: str
    model_name: str
    results: list[RerankResult]
    note: str
