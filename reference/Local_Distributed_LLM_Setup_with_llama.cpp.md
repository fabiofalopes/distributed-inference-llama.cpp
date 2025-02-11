# Local Distributed LLM Setup with llama.cpp
Complete Documentation & Cookbook

> Note: This guide uses example IPs in the 192.168.1.0/24 range. In production, replace with your actual network configuration.

## Local Environment 
```
7x Identical Machines
Network Configuration: Local network with GB networking for optimal speeds
Total Combined VRAM: 56GB (7x 8GB RTX 3060 Ti)

### Hardware Specifications (Per Machine)
OS: Pop!_OS 22.04 LTS x86_64
CPU: 11th Gen Intel i7-11700K
GPU: NVIDIA GeForce RTX 3060 Ti (8GB VRAM)
RAM: 16GB
Network: Local network with GB networking

### Network Configuration Examples

#### Basic Setup (2 Machines - 22B Model)
```
[Main Node] 192.168.1.161 (API Server + Worker)
    │
    ├── Model: Mistral-Small-Instruct-2409-Q4_K_L.gguf (13Gb)
    └── Connected to
            │
            └── [Worker Node] 192.168.1.162 (RPC Server)
```

#### Medium Setup (3 Machines - 32B Model)
```
[Main Node] 192.168.1.161 (API Server + Worker)
    │
    ├── Model: DeepSeek-R1-Distill-Qwen-32B-Q4_K_M.gguf (19Gb)
    └── Connected to
            │
            ├── [Worker Node 1] 192.168.1.162 (RPC Server)
            └── [Worker Node 2] 192.168.1.164 (RPC Server)
```

#### Large Setup (7 Machines - 70B Model)
```
[Main Node] 192.168.1.161 (API Server + Worker)
    │
    ├── Model: Llama-3.3-70B-Instruct-Q4_K_M.gguf (40Gb)
    └── Connected to
            │
            ├── [Worker Node 1] 192.168.1.162 (RPC Server)
            ├── [Worker Node 2] 192.168.1.163 (RPC Server)
            ├── [Worker Node 3] 192.168.1.164 (RPC Server)
            ├── [Worker Node 4] 192.168.1.165 (RPC Server)
            ├── [Worker Node 5] 192.168.1.166 (RPC Server)
            └── [Worker Node 6] 192.168.1.167 (RPC Server)
```

Notes:
- All nodes connected via GB networking
- Each node has RTX 3060 Ti (8GB VRAM)
- Main Node runs both API server (8080) and participates as a worker
- Worker Nodes run RPC server on port 50052
- Model is loaded and managed by Main Node

## Installation Process

### 0. Reminders 

#### 0.1 Change hosts names
```bash
sudo hostnamectl set-hostname hostnamehere
```

#### 0.2 Install nvtop
```bash 
sudo apt install nvtop
```

### 1. Prerequisites (ALL Machines)
```bash
# System updates
sudo apt update && sudo apt upgrade -y

# Required packages
sudo apt install -y build-essential cmake git nvidia-cuda-toolkit
```

### 2. CUDA Setup (ALL Machines)
```bash
# Add to ~/.bashrc
export CUDA_HOME=/usr/local/cuda-12.6
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH

# Apply changes
source ~/.bashrc
```

### 3. llama.cpp Installation (ALL Machines)
```bash
# Clone repository
git clone https://github.com/ggerganov/llama.cpp.git
cd llama.cpp

# Setup build directory
mkdir build-cuda-rpc
cd build-cuda-rpc

# Configure with CUDA and RPC
cmake .. \
    -DCMAKE_CUDA_COMPILER=/usr/local/cuda-12.6/bin/nvcc \
    -DGGML_CUDA=ON \
    -DGGML_RPC=ON \
    -DCMAKE_CUDA_ARCHITECTURES="75" \
    -DCMAKE_CXX_STANDARD=17 \
    -DCMAKE_CUDA_FLAGS="-allow-unsupported-compiler"

# Build
cmake --build . --config Release -j4
```

## System Configuration

### 1. Worker Nodes Setup (POP_02 and POP_03)
```bash
cd ~/llama.cpp/build-cuda-rpc
CUDA_VISIBLE_DEVICES=0 ./bin/rpc-server -H 0.0.0.0 -p 50052
```

### 2. Main Node Setup (POP_01)

#### Minimal Working Version
```bash
cd ~/llama.cpp/build-cuda-rpc
./bin/llama-cli \
    -m /home/dsi/Downloads/models/phi-4-Q4_K_M.gguf \
    --rpc 192.168.1.39:50052,192.168.1.34:50052 \
    -ngl 33 \
    -c 2048 \
    -n 256 \
    -p "Enter your prompt here"
```
#### Basic Distributed Inference
```bash
cd ~/llama.cpp/build-cuda-rpc
./bin/llama-cli -m /path/to/model.gguf \
    --rpc 192.168.1.39:50052,192.168.1.34:50052 \
    -ngl 99 -c 2048 -n 256 \
    --gpu-layers 99 \
    --tensor-split 0.33,0.33,0.34 \
    -p "Your prompt here"
```

#### Optimized Version with Maximum GPU Usage

```bash
./bin/llama-cli \
    -m /home/dsi/Downloads/models/phi-4-Q4_K_M.gguf \
    --rpc 192.168.1.39:50052,192.168.1.34:50052 \
    -ngl 99 \
    -c 2048 \
    -n 256 \
    --gpu-layers 99 \
    --tensor-split 0.33,0.33,0.34 \
    -p "Enter your prompt here"

```

#### OpenAI-Compatible Server
```bash
cd ~/llama.cpp/build-cuda-rpc
./bin/llama-server -m /path/to/model.gguf \
    --rpc 192.168.1.39:50052,192.168.1.34:50052 \
    -ngl 99 \
    --gpu-layers 99 \
    --tensor-split 0.33,0.33,0.34 \
    --host 0.0.0.0 \
    --port 8080
```

#### Serve 70B Model with 6 Workers in a Local Network
```bash
./bin/llama-server \
    -m /home/dsi/Downloads/models/Llama-3.3-70B-Instruct-Q4_K_M.gguf \
    --rpc 192.168.1.2:50052,192.168.1.3:50052,192.168.1.4:50052,192.168.1.5:50052,192.168.1.6:50052,192.168.1.7:50052 \
    -c 1024 \
    -n 256 \
    --gpu-layers 99 \
    --host 0.0.0.0 \
    --port 8080
```

## Server Configuration Examples

### Single GPU Setup (7B Models)
```bash
./bin/llama-server \
    -m /home/dsi/Downloads/models/DeepSeek-R1-Distill-Llama-8B-Q6_K.gguf \
    --rpc 192.168.1.2:50052 \
    --gpu-layers 99 \
    --host 0.0.0.0 \
    --port 8080 \
    --alias DeepSeek-R1-Distill-Llama-8B-Q6_K
```

### Multi-GPU Setup (27B Models)
```bash
./bin/llama-server \
    -m /home/dsi/Downloads/models/gemma-2-27b-it-Q4_K_S.gguf \
    --rpc 192.168.1.2:50052,192.168.1.3:50052,192.168.1.4:50052 \
    --gpu-layers 99 \
    --host 0.0.0.0 \
    --port 8080 \
    --alias gemma-2-27b-it
```

### Distributed Setup (32B Models)
```bash
./bin/llama-server \
    -m /home/dsi/Downloads/models/DeepSeek-R1-Distill-Qwen-32B-Q4_K_M.gguf \
    --rpc 192.168.1.2:50052,192.168.1.3:50052,192.168.1.4:50052,192.168.1.5:50052 \
    --gpu-layers 99 \
    --host 0.0.0.0 \
    --port 8080 \
    --alias DeepSeek-Qwen-32B
```

### Large Model Setup (70B Models)
```bash
./bin/llama-server \
    -m /home/dsi/Downloads/models/Llama-3.3-70B-Instruct-Q4_K_M.gguf \
    --rpc 192.168.1.2:50052,192.168.1.3:50052,192.168.1.4:50052,192.168.1.5:50052,192.168.1.6:50052 \
    --gpu-layers 99 \
    --host 0.0.0.0 \
    --port 8080 \
    --alias llama-70b-instruct
```

### Alternative Configurations

#### 32B Model with 2 GPUs
```bash
./bin/llama-server \
    -m /home/dsi/Downloads/models/DeepSeek-R1-Distill-Qwen-32B-Q4_K_M.gguf \
    --rpc 192.168.1.2:50052,192.168.1.3:50052 \
    --gpu-layers 99 \
    --host 0.0.0.0 \
    --port 8080 \
    --alias DeepSeek-Qwen-32B
```

#### 27B Model with 2 GPUs
```bash
./bin/llama-server \
    -m /home/dsi/Downloads/models/gemma-2-27b-it-Q4_K_S.gguf \
    --rpc 192.168.1.2:50052,192.168.1.3:50052 \
    --gpu-layers 99 \
    --host 0.0.0.0 \
    --port 8080 \
    --alias gemma-2-27b-it
```

#### Single GPU 7B Model
```bash
./bin/llama-server \
    -m /home/dsi/Downloads/models/Janus-Pro-7B-LM.Q6_K.gguf \
    --gpu-layers 99 \
    --host 0.0.0.0 \
    --port 8080 \
    --alias janus-pro-7b
```

### Important Command Flags
- `--alias`: Specify a custom name for the model in API responses (e.g., `--alias gemma-2-27b-it`)
- `--gpu-layers`: Number of layers to offload to GPU (use 99 for maximum GPU utilization)
- `--rpc`: Comma-separated list of RPC worker addresses (e.g., `--rpc 192.168.1.2:50052,192.168.1.3:50052`)
- `--host`: Interface to bind the server (use `0.0.0.0` to listen on all interfaces)
- `--port`: Port for the API server (commonly `8080`)
- `-m`: Path to the model file (e.g., `-m /home/dsi/Downloads/models/model-name.gguf`)
- `-c`: Context window size (e.g., `-c 2048` or `-c 1024`)
- `-n`: Number of tokens to predict (e.g., `-n 256`)
- `-ngl`: Alias for `--gpu-layers`
- `--tensor-split`: Distribution of layers across GPUs (e.g., `--tensor-split 0.33,0.33,0.34` for 3 GPUs)

### Common Command Patterns

#### Server Mode
```bash
./bin/llama-server \
    -m /path/to/model.gguf \
    --rpc worker1:50052,worker2:50052 \
    --gpu-layers 99 \
    --host 0.0.0.0 \
    --port 8080 \
    --alias model-name
```

#### CLI Mode
```bash
./bin/llama-cli \
    -m /path/to/model.gguf \
    --rpc worker1:50052,worker2:50052 \
    -ngl 99 \
    -c 2048 \
    -n 256 \
    -p "Your prompt here"
```

### GPU Distribution Patterns
- Single GPU: No `--rpc` needed
- 2 GPUs: `--rpc worker1:50052,worker2:50052`
- 3 GPUs: `--rpc worker1:50052,worker2:50052,worker3:50052`
- 4+ GPUs: Add more workers as needed, recommended for 32B+ models

### Model-Specific Configurations
- 7B models: Single GPU usually sufficient
- 27B models: 2-3 GPUs recommended
- 32B models: 2-4 GPUs recommended
- 70B models: 5+ GPUs recommended

## Important Technical Notes

### CUDA Version Management
```bash
# Multiple CUDA versions found
/usr/local/cuda        # Base symlink
/usr/local/cuda-12/    # CUDA 12
/usr/local/cuda-12.6/  # CUDA 12.6 (Our target version)
```

### Model Compatibility & Memory
GGUF Models required
Memory Requirements (approximate):
- 7B models: ~6GB VRAM (Q4)
- 13B models: ~12GB VRAM (Q4)
- 34B models: ~28GB VRAM (Q4)
- 70B models: ~40GB VRAM (Q4)

### GPU Architecture Notes
RTX 3060 Ti (Our Setup): [Compute Capability](https://developer.nvidia.com/cuda-gpus) 8.6
- Use -DCMAKE_CUDA_ARCHITECTURES="86" for optimal performance
- Our "75" setting worked but wasn't optimal

## Monitoring and Maintenance

### System Monitoring
```bash
# GPU monitoring
watch -n 1 nvidia-smi

# Network connections
sudo netstat -tulpn | grep 50052  # RPC servers
sudo netstat -tulpn | grep 8080   # API server

# GPU Memory Fragmentation
nvidia-smi --query-gpu=memory.free,memory.used,memory.total --format=csv

# Temperature Monitoring
watch -n 1 "nvidia-smi --query-gpu=temperature.gpu --format=csv"
```

### Verification Commands
```bash
# Test RPC connectivity
nc -zv 192.168.1.39 50052
nc -zv 192.168.1.34 50052

# Test API server
curl http://192.168.1.33:8080/v1/models
```

## Troubleshooting

### Common Issues and Solutions

1. RPC Connection Issues
```bash
# Check server binding
sudo netstat -tulpn | grep 50052

# Allow port through firewall
sudo ufw allow 50052/tcp
sudo ufw allow 8080/tcp
```

2. GPU Issues
```bash
# Reset GPU if unresponsive
sudo nvidia-smi --gpu-reset

# Clear CUDA memory
sudo rmmod nvidia_uvm
sudo modprobe nvidia_uvm
```

3. Process Management
```bash
# Kill hanging processes
sudo fuser -k 8080/tcp  # API server
sudo fuser -k 50052/tcp # RPC server
```

## API Usage Examples

### REST API
```bash
curl http://192.168.1.33:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "phi-4-Q4_K_M.gguf",
    "messages": [
      {
        "role": "user",
        "content": "Hello, how are you?"
      }
    ]
  }'
```

## Security Considerations
1. Network Security
   - System designed for closed network
   - No authentication implemented
   - Keep within secure local network

2. Access Control
   - Implement firewall rules as needed
   - Monitor access logs
   - Restrict port access to known IPs

## References
- https://github.com/ggerganov/llama.cpp
- https://github.com/ggerganov/llama.cpp/tree/master/examples/rpc
- https://github.com/ollama/ollama/issues/4643
- https://www.reddit.com/r/LocalLLaMA/comments/1cyzi9e/llamacpp_now_supports_distributed_inference/
- https://github.com/ggerganov/llama.cpp/discussions/795

## Model Load Time Monitoring

### Monitor Port Script
The `monitor_port.sh` script helps track and measure model loading times by monitoring when the server becomes responsive. This is particularly useful for large models that can take significant time to load into VRAM.

### Usage
```bash
# Basic monitoring (after starting model server)
./monitor_port.sh

# Automatic model launch and monitoring
./monitor_port.sh ./bin/llama-server -m /path/to/model.gguf [other_params]

# Custom timeout (in seconds)
TIMEOUT=1800 ./monitor_port.sh  # 30 minute timeout
```

### Features
- Automatically measures server startup time
- Monitors HTTP status until server becomes responsive
- Displays total loading time
- Configurable timeout protection (default 1 hour)
- Can automatically launch and monitor model process
- Automatic cleanup of background processes

### Example Integration
For 70B models that take longer to load:
```bash
./monitor_port.sh ./bin/llama-server \
    -m /home/dsi/Downloads/models/Llama-3.3-70B-Instruct-Q4_K_M.gguf \
    --rpc 192.168.1.2:50052,192.168.1.3:50052,192.168.1.4:50052,192.168.1.5:50052,192.168.1.6:50052 \
    --gpu-layers 99 \
    --host 0.0.0.0 \
    --port 8080 \
    --alias llama-70b-instruct
```

### Automation Setup
Add to your `.bashrc` or `.zshrc`:
```bash
alias run_model='f() { ./monitor_port.sh ./bin/llama-server -m "$@"; }; f'
```

Then use:
```bash
run_model /path/to/model.gguf [other_params]
```

This script is particularly useful when:
- Testing different model configurations
- Benchmarking load times across different hardware setups
- Monitoring distributed setup initialization
- Ensuring all workers are properly connected before use
