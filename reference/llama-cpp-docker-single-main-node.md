A Docker Compose setup for running `llama.cpp` as a server (without RPC) on each machine, specifically tailored for the `DeepSeek-R1-Distill-Llama-8B-Q6_K.gguf` model. This will be a single-node setup per machine, preparing for a later distributed deployment.

**I. Project Structure**

We'll organize the files like this:

```
llama-cpp-docker-single/
├── docker-compose.yml
├── llama-server.Dockerfile
└── models/  (You'll place your DeepSeek model here)
```

**II. Dockerfile (llama-server.Dockerfile)**

We'll create a custom Dockerfile based on the existing `cuda.Dockerfile` to ensure CUDA support and streamline the build process for our specific use case. We're aiming for simplicity and reproducibility.

```dockerfile
FROM nvidia/cuda:12.6.0-devel-ubuntu22.04

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
RUN mkdir -p build && cd build && \
    cmake .. -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES="86" -DCMAKE_CXX_STANDARD=17 && \
    cmake --build . --config Release -j$(nproc)

# Create a directory for models
RUN mkdir -p /app/models

# Expose the server port
EXPOSE 8080

# Healthcheck
HEALTHCHECK CMD ["curl", "-f", "http://localhost:8080/health"]

```90:90:.devops/cpu.Dockerfile
HEALTHCHECK CMD [ "curl", "-f", "http://localhost:8080/health" ]
```

```dockerfile
# Command to run the llama-server (will be overridden in docker-compose)
CMD ["./build/bin/llama-server", "-m", "/app/models/your-model.gguf", "--host", "0.0.0.0", "--port", "8080"]
```

**III. Docker Compose (docker-compose.yml)**

This file defines the `llama-server` service, mounts the models directory, exposes the port, and sets the necessary environment variables.

```yaml
version: '3.8'

services:
  llama-server:
    build:
      context: .
      dockerfile: llama-server.Dockerfile
    image: llama-cpp-server-single # A descriptive name for the image
    ports:
      - "8080:8080"
    volumes:
      - ./models:/app/models  # Mount the models directory
    environment:
      - MODEL=/app/models/DeepSeek-R1-Distill-Llama-8B-Q6_K.gguf # Specific model
      - N_GPU_LAYERS=99  # Offload all layers to the GPU
      - HOST=0.0.0.0
      - PORT=8080
      - CTX_SIZE=2048 # Example context size, adjust as needed
      - ALIAS=deepseek-8b # Add an alias for the model
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
```

**IV.  Reference Document Snippet**

Here's how you would incorporate this into your reference document:

```markdown
## Single-Node Docker Deployment (Per Machine)

This section describes how to deploy `llama.cpp` as a standalone server on each machine using Docker. This setup is suitable for running smaller models or for testing before implementing the full distributed setup.  We'll use the `DeepSeek-R1-Distill-Llama-8B-Q6_K.gguf` model as an example.

### 1. Project Structure

Organize your files as follows:

```
llama-cpp-docker-single/
├── docker-compose.yml
├── llama-server.Dockerfile
└── models/  (Place your DeepSeek-R1-Distill-Llama-8B-Q6_K.gguf model here)
```

### 2. Dockerfile (llama-server.Dockerfile)

Create a file named `llama-server.Dockerfile` with the following content:

```dockerfile
FROM nvidia/cuda:12.6.0-devel-ubuntu22.04

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
RUN mkdir -p build && cd build && \
    cmake .. -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES="86" -DCMAKE_CXX_STANDARD=17 && \
    cmake --build . --config Release -j$(nproc)

# Create a directory for models
RUN mkdir -p /app/models

# Expose the server port
EXPOSE 8080

# Healthcheck (see .devops/cpu.Dockerfile, lines 90-90)
HEALTHCHECK CMD ["curl", "-f", "http://localhost:8080/health"]

# Command to run the llama-server (will be overridden in docker-compose)
CMD ["./build/bin/llama-server", "-m", "/app/models/your-model.gguf", "--host", "0.0.0.0", "--port", "8080"]
```

This Dockerfile is based on the `cuda.Dockerfile` provided in the `llama.cpp` repository but is simplified for our specific use case.  It uses the `nvidia/cuda:12.6.0-devel-ubuntu22.04` base image, installs dependencies, clones the `llama.cpp` repository, builds `llama-server` with CUDA support, and sets up a healthcheck.

### 3. Docker Compose (docker-compose.yml)

Create a file named `docker-compose.yml` with the following content:

```yaml
version: '3.8'

services:
  llama-server:
    build:
      context: .
      dockerfile: llama-server.Dockerfile
    image: llama-cpp-server-single
    ports:
      - "8080:8080"
    volumes:
      - ./models:/app/models  # Mount the models directory
    environment:
      - MODEL=/app/models/DeepSeek-R1-Distill-Llama-8B-Q6_K.gguf
      - N_GPU_LAYERS=99
      - HOST=0.0.0.0
      - PORT=8080
      - CTX_SIZE=2048
      - ALIAS=deepseek-8b
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
```

This `docker-compose.yml` file defines a single service, `llama-server`, which builds and runs the `llama.cpp` server.  It mounts the `models` directory, exposes port 8080, and sets environment variables to configure the server.  Crucially, it uses the `deploy` section to ensure the container has access to the GPU.

### 4. Deployment Steps

1.  **Prerequisites:** Ensure Docker and the NVIDIA Container Toolkit are installed and configured on each machine.
2.  **Model:** Download the `DeepSeek-R1-Distill-Llama-8B-Q6_K.gguf` model and place it in the `models` directory.
3.  **Build (Optional):** If you're not using a pre-built image, build the image:
    ```bash
    docker compose build
    ```
4.  **Run:** Start the server:
    ```bash
    docker compose up -d
    ```
5.  **Verify:**
    *   Check running containers: `docker ps`
    *   Check logs: `docker compose logs llama-server`
    *   Test API: `curl http://localhost:8080/v1/models` (or use the machine's IP address from another machine on the network)
6. **Stop:**
    ```bash
    docker compose down
    ```

### 5.  Important Notes

*   **CUDA Architecture:** The Dockerfile uses `-DCMAKE_CUDA_ARCHITECTURES="86"`.  This is appropriate for your RTX 3060 Ti cards (Ampere architecture). If you use different GPUs, adjust this value accordingly.
* **Model Path:** The `MODEL` environment variable in `docker-compose.yml` specifies the path to the model *inside the container* (`/app/models/DeepSeek-R1-Distill-Llama-8B-Q6_K.gguf`).
* **Host:** The `HOST=0.0.0.0` setting makes the server accessible from other machines on your network.
* **Healthcheck:** The `HEALTHCHECK` instruction in the Dockerfile allows Docker to monitor the health of the server.
* **Alias:** The `ALIAS=deepseek-8b` sets a user-friendly name for the model, which will be returned by the `/v1/models` API endpoint.
* **Repeat:** Repeat these steps on each of your 7 machines.

This setup provides a solid foundation for running `llama.cpp` as a standalone server on each machine.  You can later expand this to a distributed setup using the RPC functionality.
```


