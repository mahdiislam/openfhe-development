from sentence_transformers import SentenceTransformer

from .config import settings


_model: SentenceTransformer | None = None


def get_model() -> SentenceTransformer:
    global _model
    if _model is None:
        _model = SentenceTransformer(settings.model_name)
    return _model


def encode_query_and_docs(query: str, docs: list[str]) -> tuple[list[float], list[list[float]]]:
    model = get_model()
    query_vec = model.encode(query, normalize_embeddings=True).tolist()
    doc_vecs = model.encode(docs, normalize_embeddings=True).tolist()
    return query_vec, doc_vecs
