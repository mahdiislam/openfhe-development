cmake_minimum_required(VERSION 3.16)
project(tiny_reranker_openfhe_service CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(OpenFHE CONFIG REQUIRED)
find_package(Protobuf REQUIRED)
find_package(gRPC CONFIG REQUIRED)

add_executable(openfhe_reranker_service
  src/main.cpp
  src/service_impl.cpp
  src/openfhe_engine.cpp
  generated/reranker.pb.cc
  generated/reranker.grpc.pb.cc
)

target_include_directories(openfhe_reranker_service PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/src
  ${CMAKE_CURRENT_SOURCE_DIR}/generated
)

target_link_libraries(openfhe_reranker_service PRIVATE
  OPENFHEpke
  OPENFHEbinfhe
  OPENFHEcore
  protobuf::libprotobuf
  gRPC::grpc++
)
