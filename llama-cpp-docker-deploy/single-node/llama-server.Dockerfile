FROM nvidia/cuda:12.6.0-devel-ubuntu22.04

# Set environment variables for CUDA
ENV PATH /usr/local/cuda/bin:${PATH}
ENV LD_LIBRARY_PATH /usr/local/cuda/lib64:/usr/local/cuda/lib64/stubs:${LD_LIBRARY_PATH}
ENV CUDA_HOME /usr/local/cuda

# Set working directory
WORKDIR /app

# Install dependencies and create CUDA symlinks
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    git \
    libgomp1 \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s /usr/local/cuda/lib64/stubs/libcuda.so /usr/local/cuda/lib64/stubs/libcuda.so.1 \
    && ln -s /usr/local/cuda/lib64/stubs/libcuda.so /usr/local/cuda/lib64/libcuda.so.1

# Clone llama.cpp repository
RUN git clone https://github.com/ggerganov/llama.cpp.git /app/llama.cpp

# Build llama.cpp with CUDA support
WORKDIR /app/llama.cpp
RUN mkdir -p build && cd build && \
    export CUDA_PATH=/usr/local/cuda && \
    export CUDA_TOOLKIT_ROOT_DIR=/usr/local/cuda && \
    cmake .. \
    -DGGML_CUDA=ON \
    -DCMAKE_CUDA_ARCHITECTURES="86" \
    -DCMAKE_CXX_STANDARD=17 \
    -DCUDA_TOOLKIT_ROOT_DIR=/usr/local/cuda \
    -DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc \
    -DCMAKE_LIBRARY_PATH=/usr/local/cuda/lib64/stubs \
    -DCMAKE_EXE_LINKER_FLAGS="-L/usr/local/cuda/lib64/stubs -L/usr/local/cuda/lib64 -lcuda" \
    -DCMAKE_BUILD_TYPE=Release \
    && cmake --build . --config Release -j$(nproc)

# Create a directory for models
RUN mkdir -p /app/models

# Expose the server port
EXPOSE 8080

# Healthcheck
HEALTHCHECK CMD ["curl", "-f", "http://localhost:8080/health"]

# Command to run the llama-server (will be overridden in docker-compose)
CMD ["./build/bin/llama-server", "-m", "/app/models/your-model.gguf", "--host", "0.0.0.0", "--port", "8080"] 