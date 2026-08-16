#include <grpcpp/grpcpp.h>

#include <iostream>
#include <memory>
#include <string>

#include "service_impl.h"

int main() {
    const std::string address = "0.0.0.0:50051";
    RerankServiceImpl service;

    grpc::ServerBuilder builder;
    builder.AddListeningPort(address, grpc::InsecureServerCredentials());
    builder.RegisterService(&service);

    std::unique_ptr<grpc::Server> server(builder.BuildAndStart());
    if (!server) {
        std::cerr << "failed to start gRPC service" << std::endl;
        return 1;
    }

    std::cout << "OpenFHE reranker service listening on " << address << std::endl;
    server->Wait();
    return 0;
}
