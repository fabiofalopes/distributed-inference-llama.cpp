# Local Distributed LLM Setup with llama.cpp
Complete Documentation & Cookbook
## Local Environment 
```
3x Identical Machines (POP_01, POP_02, POP_03)
Network Configuration: Local network
Total Combined VRAM: 24GB (3x 8GB RTX 3060 Ti)

### Hardware Specifications (Per Machine)
OS: Pop!_OS 22.04 LTS x86_64
CPU: 11th Gen Intel i7-11700K
GPU: NVIDIA GeForce RTX 3060 Ti (8GB VRAM)
RAM: 16GB
Network: Local network (192.168.1.x)

### Network Configuration
POP_01 (Main Node): 192.168.1.33
POP_02 (Worker): 192.168.1.39
POP_03 (Worker): 192.168.1.34

```
## Installation Process

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

### Python Client
```python
import requests

def send_message(message, timeout=(5, 30)):
    url = "http://192.168.1.33:8080/v1/chat/completions"
    payload = {
        "model": "phi-4-Q4_K_M.gguf",
        "messages": [{"role": "user", "content": message}]
    }
    headers = {"Content-Type": "application/json"}
    
    response = requests.post(url, json=payload, headers=headers, timeout=timeout)
    return response.json()
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