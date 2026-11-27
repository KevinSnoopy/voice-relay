#if defined(__x86_64__)
#include "../../vendor/sherpa-onnx-v2.0.3-osx-x64-shared/include/sherpa-onnx/c-api/c-api.h"
#elif defined(__aarch64__)
#include "../../vendor/sherpa-onnx-v2.0.3-osx-arm64-shared/include/sherpa-onnx/c-api/c-api.h"
#else
#error "Unsupported architecture"
#endif
