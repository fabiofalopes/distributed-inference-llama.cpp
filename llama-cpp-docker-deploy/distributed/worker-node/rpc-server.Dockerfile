FROM nvidia/cuda:12.6.0-devel-ubuntu22.04

# Set environment variables for CUDA
ENV PATH /usr/local/cuda/bin:${PATH}
ENV LD_LIBRARY_PATH /usr/local/cuda/lib64:${LD_LIBRARY_PATH}
ENV CUDA_HOME /usr/local/cuda

# Set working directory
WORKDIR /app

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    git \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Clone llama.cpp repository
RUN git clone https://github.com/ggerganov/llama.cpp.git /app/llama.cpp

# Build llama.cpp with CUDA and RPC support
WORKDIR /app/llama.cpp
RUN mkdir -p build && cd build && \
    export CUDA_PATH=/usr/local/cuda && \
    export CUDA_TOOLKIT_ROOT_DIR=/usr/local/cuda && \
    cmake .. \
    -DGGML_CUDA=ON \
    -DGGML_RPC=ON \
    -DCMAKE_CUDA_ARCHITECTURES="86" \
    -DCMAKE_CXX_STANDARD=17 && \
    cmake --build . --config Release -j$(nproc)

# Expose the RPC port
EXPOSE 50052

# Command to run the RPC server
CMD ["./build/bin/rpc-server", "-H", "0.0.0.0", "-p", "50052"] 