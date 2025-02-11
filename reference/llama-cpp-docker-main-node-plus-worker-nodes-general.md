A more generalized and flexible Docker Compose configuration for a distributed `llama.cpp` setup, allowing for a variable number of worker nodes and supporting different models. This builds upon the previous configurations, adding more configurability and best practices.

**I. Project Structure (Main Node)**

```
llama-cpp-docker-main/
├── docker-compose.yml
├── llama-server.Dockerfile
└── models/  (Place your models here)
```

**II. Dockerfile (Main Node - llama-server.Dockerfile)**

This remains the same as the previous distributed setup, ensuring `GGML_RPC` is enabled.

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

This is where we introduce more flexibility.

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
      - MODEL=/app/models/${MODEL_FILE:-your-model.gguf} # Use environment variable for model
      - RPC_SERVERS=${WORKER_IPS:-worker1_ip:50052,worker2_ip:50052} # Comma-separated list of worker IPs
      - N_GPU_LAYERS=${N_GPU_LAYERS:-99}  # Number of GPU layers
      - HOST=0.0.0.0
      - PORT=8080
      - CTX_SIZE=${CTX_SIZE:-2048} # Context size
      - ALIAS=${MODEL_ALIAS:-llama-model} # Model alias
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
```

**Key Changes:**

*   **Environment Variables with Defaults:** We use environment variables for all configurable parameters, providing default values:
    *   `MODEL_FILE`:  The name of the model file (default: `your-model.gguf`).
    *   `WORKER_IPS`:  A comma-separated list of worker IP addresses and ports (default: `worker1_ip:50052,worker2_ip:50052`).  **You still need to replace these defaults with actual IP addresses.**
    *   `N_GPU_LAYERS`: The number of layers to offload to the GPU (default: 99).
    *   `CTX_SIZE`: The context size (default: 2048).
    *   `MODEL_ALIAS`:  A user-friendly name for the model (default: `llama-model`).
*   **Flexibility:** This allows you to easily change the model, the number of workers, and other parameters *without modifying the `docker-compose.yml` file itself*. You can set these environment variables in your shell before running `docker compose up`, or use a `.env` file.

**IV. Project Structure (Worker Nodes)**

Each worker node will have the same structure as before:

```
llama-cpp-docker-worker/
├── docker-compose.yml
└── rpc-server.Dockerfile
```

**V. Dockerfile (Worker Node - rpc-server.Dockerfile)**

This remains unchanged from the previous distributed setup.

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

This also remains unchanged.

```yaml
version: '3.8'

services:
  llama-rpc-server:
    build:
      context: .
      dockerfile: rpc-server.Dockerfile
    image: llama-cpp-rpc-server
    ports:
      - "50052:50052"
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
## Flexible Distributed Docker Deployment (Variable Workers)

This section describes a highly configurable distributed `llama.cpp` deployment using Docker, allowing for a variable number of worker nodes and easy model switching.

### Main Node Setup

#### 1. Project Structure

```
llama-cpp-docker-main/
├── docker-compose.yml
├── llama-server.Dockerfile
└── models/  (Place your models here)
```

#### 2. Dockerfile (llama-server.Dockerfile)

```dockerfile
# (Content as provided above)
```

#### 3. Docker Compose (docker-compose.yml)

```yaml
# (Content as provided above)
```

**Key Features:**

*   **Environment Variables:**  All critical configuration parameters are controlled by environment variables, making the setup highly flexible.
*   **`MODEL_FILE`:**  Specifies the model file to use.  You can change this *without* modifying the `docker-compose.yml` file.
*   **`WORKER_IPS`:**  A comma-separated list of worker IP addresses and ports.  **You must provide the correct IP addresses for your worker nodes.**
*   **Other Variables:** `N_GPU_LAYERS`, `CTX_SIZE`, and `MODEL_ALIAS` provide further customization.

#### 4. Deployment (Main Node)

1.  **Prerequisites:** Docker and NVIDIA Container Toolkit.
2.  **Model:** Place your desired model file in the `models` directory.
3.  **Set Environment Variables (Choose one method):**
    *   **Shell:**
        ```bash
        export MODEL_FILE=your-model.gguf
        export WORKER_IPS="192.168.1.101:50052,192.168.1.102:50052,192.168.1.103:50052"  # Example with 3 workers
        # Set other variables as needed
        ```
    *   **`.env` file:** Create a file named `.env` in the same directory as your `docker-compose.yml` file:
        ```
        MODEL_FILE=your-model.gguf
        WORKER_IPS=192.168.1.101:50052,192.168.1.102:50052,192.168.1.103:50052
        N_GPU_LAYERS=99
        CTX_SIZE=4096
        MODEL_ALIAS=my-custom-model
        ```
        Docker Compose automatically reads environment variables from a `.env` file.
4.  **Build (Optional):** `docker compose build`
5.  **Run:** `docker compose up -d`
6.  **Verify:** `docker ps`, `docker compose logs llama-server`, and `curl http://<main_node_ip>:8080/v1/models`

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

#### 3. Docker Compose (docker-compose.yml)

```yaml
# (Content as provided above)
```

#### 4. Deployment (Worker Nodes)

1.  **Prerequisites:** Docker and NVIDIA Container Toolkit.
2.  **Build (Optional):** `docker compose build`
3.  **Run:** `docker compose up -d`
4.  **Verify:** `docker ps`, `docker compose logs llama-rpc-server`

### VIII.  Important Considerations

*   **Network:**  Ensure all machines are on the same network and can communicate.
*   **Firewall:** Allow traffic on ports 50052 and 8080.
*   **IP Addresses:** Use static IPs for worker nodes.
*   **Startup Order:** Start worker nodes before the main server.
*   **Monitoring:** Use `nvtop` and `docker logs`.
*   **`.env` File:** Using a `.env` file is highly recommended for managing environment variables, especially when you have multiple configurations or need to switch between models frequently.
* **Scaling Workers:** To add more workers, simply deploy the worker node setup on additional machines and update the `WORKER_IPS` environment variable on the main node *before* restarting the `llama-server` container. You do *not* need to modify the `docker-compose.yml` file on the main node to add or remove workers.
* **Model Changes:** To change the model, update the `MODEL_FILE` environment variable and restart the `llama-server` container: `docker compose restart llama-server`.

This final, flexible configuration provides a robust and scalable solution for deploying `llama.cpp` in a distributed environment. It leverages environment variables for easy configuration and allows for a variable number of worker nodes without requiring changes to the core Docker Compose files. The use of a `.env` file further simplifies configuration management.


