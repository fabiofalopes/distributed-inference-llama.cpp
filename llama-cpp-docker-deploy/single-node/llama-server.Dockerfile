FROM nvidia/cuda:12.6.0-devel-ubuntu22.04 AS build

# Set environment variables for CUDA
ENV PATH /usr/local/cuda/bin:${PATH}
ENV LD_LIBRARY_PATH /usr/local/cuda/lib64:/usr/local/cuda/lib64/stubs:${LD_LIBRARY_PATH}
ENV CUDA_HOME /usr/local/cuda

# Set working directory
WORKDIR /app

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    git \
    libgomp1 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Clone llama.cpp repository
RUN git clone https://github.com/ggerganov/llama.cpp.git /app/llama.cpp

# Build llama.cpp with CUDA support
WORKDIR /app/llama.cpp

# --- Make CUDA architecture configurable ---
ARG CUDA_ARCHITECTURES=all

RUN mkdir -p build && cd build && \
    export CUDA_PATH=/usr/local/cuda && \
    export CUDA_TOOLKIT_ROOT_DIR=/usr/local/cuda && \
    export LD_LIBRARY_PATH=/usr/local/cuda/lib64:/usr/local/cuda/extras/CUPTI/lib64:$LD_LIBRARY_PATH && \
    cmake .. \
    -DGGML_CUDA=ON \
    -DCMAKE_CUDA_ARCHITECTURES="$CUDA_ARCHITECTURES" \
    -DCMAKE_CXX_STANDARD=17 \
    -DCMAKE_EXE_LINKER_FLAGS="-Wl,-rpath,/usr/local/cuda/lib64 -Wl,--allow-shlib-undefined" && \
    cmake --build . --config Release -j$(nproc)

# --- Create a smaller runtime stage ---
FROM nvidia/cuda:12.6.0-runtime-ubuntu22.04

WORKDIR /app

# Install libgomp1 in the runtime image
RUN apt-get update && apt-get install -y --no-install-recommends libgomp1 && rm -rf /var/lib/apt/lists/*

# Copy only the necessary files from the build stage
COPY --from=build /app/llama.cpp/build/bin/llama-server /app/

# Create directories for libraries
RUN mkdir -p /app/lib /usr/local/lib/cuda

# Copy shared libraries - using RUN to handle wildcards
RUN --mount=from=build,src=/app/llama.cpp/build/bin,target=/tmp/bin \
    cp /tmp/bin/libllama.so /app/lib/ || true && \
    cp /tmp/bin/libggml*.so /app/lib/ || true

# Copy CUDA libraries
RUN --mount=from=build,src=/usr/local/cuda/lib64,target=/tmp/cuda \
    cp /tmp/cuda/libcudart.so* /usr/local/lib/cuda/ && \
    cp /tmp/cuda/libcublas.so* /usr/local/lib/cuda/ && \
    cp /tmp/cuda/libcublasLt.so* /usr/local/lib/cuda/ && \
    cp /tmp/cuda/libcuda.so* /usr/local/lib/cuda/ || true

# Set LD_LIBRARY_PATH in the runtime environment
ENV LD_LIBRARY_PATH=/app/lib:/usr/local/lib/cuda:/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH

# Create a directory for models
RUN mkdir -p /app/models

# Expose the server port
EXPOSE 8080

# Healthcheck
HEALTHCHECK CMD ["curl", "-f", "http://localhost:8080/health"]

# Command to run the llama-server (will be overridden in docker-compose)
CMD ["./llama-server", "-m", "/app/models/your-model.gguf", "--host", "0.0.0.0", "--port", "8080"] 
