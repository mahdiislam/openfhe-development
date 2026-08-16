from pydantic import BaseModel


class Settings(BaseModel):
    grpc_target: str = "localhost:50051"
    model_name: str = "sentence-transformers/all-MiniLM-L6-v2"


settings = Settings()
