A Docker Compose configuration for a distributed setup with one main node and two worker nodes, targeting the `DeepSeek-R1-Distill-Qwen-32B-Q4_K_M.gguf` model. We'll create separate Docker Compose files for the main node and the worker nodes to reflect the deployment on different machines.

**I. Project Structure (Main Node)**

```
llama-cpp-docker-main/
├── docker-compose.yml
├── llama-server.Dockerfile
└── models/  (Place your DeepSeek-R1-Distill-Qwen-32B-Q4_K_M.gguf model here)
```

**II. Dockerfile (Main Node - llama-server.Dockerfile)**

This remains largely the same as the single-node setup, but we ensure `GGML_RPC` is enabled during the build.

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

# Build llama.cpp with CUDA and RPC support
WORKDIR /app/llama.cpp
RUN mkdir -p build && cd build && \
    cmake .. -DGGML_CUDA=ON -DGGML_RPC=ON -DCMAKE_CUDA_ARCHITECTURES="86" -DCMAKE_CXX_STANDARD=17 && \
    cmake --build . --config Release -j$(nproc)

# Create a directory for models
RUN mkdir -p /app/models

# Expose the server port
EXPOSE 8080

# Healthcheck
```

```92:92:.devops/cuda.Dockerfile
HEALTHCHECK CMD [ "curl", "-f", "http://localhost:8080/health" ]
```

```dockerfile
HEALTHCHECK CMD ["curl", "-f", "http://localhost:8080/health"]

# Command to run the llama-server (will be overridden in docker-compose)
CMD ["./build/bin/llama-server", "-m", "/app/models/your-model.gguf", "--host", "0.0.0.0", "--port", "8080"]
```

**III. Docker Compose (Main Node - docker-compose.yml)**

```yaml
version: '3.8'

services:
  llama-server:
    build:
      context: .
      dockerfile: llama-server.Dockerfile
    image: llama-cpp-main-server
    ports:
      - "8080:8080"
    volumes:
      - ./models:/app/models  # Mount the models directory
    environment:
      - MODEL=/app/models/DeepSeek-R1-Distill-Qwen-32B-Q4_K_M.gguf
      - RPC_SERVERS=worker1_ip:50052,worker2_ip:50052  # Replace with actual worker IPs
      - N_GPU_LAYERS=99
      - HOST=0.0.0.0
      - PORT=8080
      - CTX_SIZE=2048
      - ALIAS=deepseek-qwen-32b
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
```

**Important:** Replace `worker1_ip` and `worker2_ip` with the *actual IP addresses* of your worker nodes on the network.  Unlike the all-in-one Docker Compose setup, we *cannot* use service names here because the worker containers are running on different hosts.

**IV. Project Structure (Worker Nodes)**

Each worker node will have a similar structure:

```
llama-cpp-docker-worker/
├── docker-compose.yml
└── rpc-server.Dockerfile
```

**V. Dockerfile (Worker Node - rpc-server.Dockerfile)**

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
    && rm -rf /var/lib/apt/lists/*

# Clone llama.cpp repository
RUN git clone https://github.com/ggerganov/llama.cpp.git /app/llama.cpp

# Build llama.cpp with CUDA and RPC support
WORKDIR /app/llama.cpp
RUN mkdir -p build && cd build && \
    cmake .. -DGGML_CUDA=ON -DGGML_RPC=ON -DCMAKE_CUDA_ARCHITECTURES="86" -DCMAKE_CXX_STANDARD=17 && \
    cmake --build . --config Release -j$(nproc)

# Expose the RPC port
EXPOSE 50052

# Command to run the RPC server
CMD ["./build/bin/rpc-server", "-H", "0.0.0.0", "-p", "50052"]
```

**VI. Docker Compose (Worker Node - docker-compose.yml)**

```yaml
version: '3.8'

services:
  llama-rpc-server:
    build:
      context: .
      dockerfile: rpc-server.Dockerfile
    image: llama-cpp-rpc-server
    ports:
      - "50052:50052" # Expose port to the host
    environment:
      - HOST=0.0.0.0
      - PORT=50052
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
```

**VII. Reference Document Additions**

```markdown
## Distributed Docker Deployment (Main Node + 2 Workers)

This section describes how to deploy `llama.cpp` in a distributed configuration with one main node (running `llama-server`) and two worker nodes (running `rpc-server`). We'll use the `DeepSeek-R1-Distill-Qwen-32B-Q4_K_M.gguf` model as an example.

### Main Node Setup

#### 1. Project Structure

```
llama-cpp-docker-main/
├── docker-compose.yml
├── llama-server.Dockerfile
└── models/  (Place your DeepSeek-R1-Distill-Qwen-32B-Q4_K_M.gguf model here)
```

#### 2. Dockerfile (llama-server.Dockerfile)

```dockerfile
# (Content as provided above)
```
This Dockerfile is similar to the single-node setup, but ensures that `GGML_RPC` is enabled during the build process. This is crucial for the main node to communicate with the worker nodes.

#### 3. Docker Compose (docker-compose.yml)
```yaml
# (Content as provided above)
```

**Key Points:**

*   **`RPC_SERVERS`:** This environment variable is critical.  You *must* replace `worker1_ip` and `worker2_ip` with the actual IP addresses of your worker nodes on your local network (e.g., `192.168.1.101:50052,192.168.1.102:50052`).  Because the worker nodes are running on separate hosts, we cannot use Docker Compose service names for networking.
*  **Model Path:** Ensure the `MODEL` environment variable points to the correct location of your model file within the mounted `models` directory.

#### 4. Deployment (Main Node)

1.  **Prerequisites:** Docker and NVIDIA Container Toolkit installed.
2.  **Model:** Place the `DeepSeek-R1-Distill-Qwen-32B-Q4_K_M.gguf` model in the `models` directory.
3.  **Build (Optional):** `docker compose build`
4.  **Run:** `docker compose up -d`
5.  **Verify:** `docker ps`, `docker compose logs llama-server`, and `curl http://<main_node_ip>:8080/v1/models`

### Worker Node Setup (Repeat for each worker)

#### 1. Project Structure

```
llama-cpp-docker-worker/
├── docker-compose.yml
└── rpc-server.Dockerfile
```

#### 2. Dockerfile (rpc-server.Dockerfile)

```dockerfile
# (Content as provided above)
```

This Dockerfile builds the `rpc-server` with CUDA and RPC support.

#### 3. Docker Compose (docker-compose.yml)

```yaml
# (Content as provided above)
```

This Docker Compose file defines the `llama-rpc-server` service, exposes port 50052, and ensures the container has access to the GPU.

#### 4. Deployment (Worker Nodes)

6.  **Prerequisites:** Docker and NVIDIA Container Toolkit installed.
7.  **Build (Optional):** `docker compose build`
8.  **Run:** `docker compose up -d`
9.  **Verify:** `docker ps`, `docker compose logs llama-rpc-server`

### VIII.  Important Considerations

*   **Network Connectivity:** Ensure all machines (main node and worker nodes) are on the same local network and can communicate with each other.  Test connectivity using `ping` before deploying the Docker containers.
*   **Firewall:**  Make sure your firewall allows traffic on port 50052 (for the RPC servers) and port 8080 (for the main server).
*   **IP Addresses:**  Carefully manage the IP addresses of your worker nodes.  Static IPs are recommended to avoid issues with DHCP lease changes.
* **Startup Order:** While the main server has retry logic, it's generally good practice to start the worker nodes *before* starting the main server.
* **Monitoring:** Use `nvtop` (or `nvidia-smi`) on each machine to monitor GPU utilization and ensure the load is being distributed correctly.  Use `docker logs` to check for any errors.
* **Model Compatibility:** The provided setup assumes the model is compatible with the available VRAM on your GPUs, considering the distribution across the main node and workers. Adjust `N_GPU_LAYERS` and potentially the model quantization if needed.

This detailed guide provides the necessary steps and configurations for deploying `llama.cpp` in a distributed manner using Docker, with separate configurations for the main node and worker nodes. It emphasizes the critical aspects of network configuration, IP address management, and GPU access. Remember to adapt the IP addresses and model paths to your specific environment.


