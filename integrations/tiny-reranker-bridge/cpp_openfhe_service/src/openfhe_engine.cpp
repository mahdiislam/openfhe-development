#include "openfhe_engine.h"

#include <algorithm>
#include <cmath>
#include <cstdint>

std::vector<std::pair<std::string, std::string>> OpenFheEngine::ScoreEncryptedQuery(
    const std::string& encryptedQueryBytes,
    const std::vector<Candidate>& candidates,
    int topK,
    std::string& note) const {
    (void)encryptedQueryBytes;

    // Minimal placeholder: this returns deterministic pseudo-ciphertexts per document.
    // Replace with real CKKS ciphertext operations and serialization.
    std::vector<std::pair<std::string, std::string>> out;
    out.reserve(candidates.size());

    for (const auto& c : candidates) {
        double l2 = 0.0;
        for (float x : c.embedding) {
            l2 += static_cast<double>(x) * static_cast<double>(x);
        }
        const int32_t quant = static_cast<int32_t>(std::lround(l2 * 100000.0));
        std::string fakeCipher(reinterpret_cast<const char*>(&quant), sizeof(quant));
        out.emplace_back(c.doc_id, fakeCipher);
    }

    std::sort(out.begin(), out.end(), [](const auto& a, const auto& b) {
        return a.first < b.first;
    });

    if (topK > 0 && static_cast<size_t>(topK) < out.size()) {
        out.resize(static_cast<size_t>(topK));
    }

    note = "stub-encryption: replace OpenFheEngine::ScoreEncryptedQuery with CKKS eval";
    return out;
}
