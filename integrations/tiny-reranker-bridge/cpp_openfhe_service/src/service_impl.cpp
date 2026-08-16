#include "service_impl.h"

#include <vector>

grpc::Status RerankServiceImpl::Health(grpc::ServerContext* context,
                                       const reranker::v1::HealthRequest* request,
                                       reranker::v1::HealthResponse* response) {
    (void)context;
    (void)request;
    response->set_status("ok");
    return grpc::Status::OK;
}

grpc::Status RerankServiceImpl::ScoreEncryptedQuery(grpc::ServerContext* context,
                                                    const reranker::v1::ScoreEncryptedQueryRequest* request,
                                                    reranker::v1::ScoreEncryptedQueryResponse* response) {
    (void)context;

    std::vector<Candidate> candidates;
    candidates.reserve(static_cast<size_t>(request->candidates_size()));
    for (const auto& item : request->candidates()) {
        Candidate c;
        c.doc_id = item.doc_id();
        c.embedding.assign(item.embedding().begin(), item.embedding().end());
        candidates.push_back(std::move(c));
    }

    std::string note;
    auto scores = engine_.ScoreEncryptedQuery(request->encrypted_query_ckks(), candidates, request->top_k(), note);

    response->set_request_id(request->request_id());
    response->set_note(note);
    for (const auto& s : scores) {
        auto* out = response->add_encrypted_scores();
        out->set_doc_id(s.first);
        out->set_encrypted_score_ckks(s.second);
    }

    return grpc::Status::OK;
}
