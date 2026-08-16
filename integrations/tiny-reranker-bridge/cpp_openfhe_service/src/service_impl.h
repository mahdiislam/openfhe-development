#pragma once

#include <grpcpp/grpcpp.h>

#include "openfhe_engine.h"
#include "reranker.grpc.pb.h"
#include "reranker.pb.h"

class RerankServiceImpl final : public reranker::v1::RerankService::Service {
  public:
    grpc::Status Health(grpc::ServerContext* context,
                        const reranker::v1::HealthRequest* request,
                        reranker::v1::HealthResponse* response) override;

    grpc::Status ScoreEncryptedQuery(grpc::ServerContext* context,
                                     const reranker::v1::ScoreEncryptedQueryRequest* request,
                                     reranker::v1::ScoreEncryptedQueryResponse* response) override;

  private:
    OpenFheEngine engine_;
};
