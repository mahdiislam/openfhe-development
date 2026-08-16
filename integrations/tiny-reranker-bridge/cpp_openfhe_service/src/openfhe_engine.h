#pragma once

#include <string>
#include <utility>
#include <vector>

struct Candidate {
    std::string doc_id;
    std::vector<float> embedding;
};

class OpenFheEngine {
  public:
    std::vector<std::pair<std::string, std::string>> ScoreEncryptedQuery(
        const std::string& encryptedQueryBytes,
        const std::vector<Candidate>& candidates,
        int topK,
        std::string& note) const;
};
