# Single-Node llama.cpp Docker Deployment

This directory contains the necessary files to deploy llama.cpp as a server on a single node using Docker.

## Prerequisites

- Docker and Docker Compose
- NVIDIA GPU with CUDA support
- NVIDIA Container Toolkit installed and configured

## Setup

1. Place your GGUF model file(s) in the `models` directory.
2. Update the `.env` file with your model configuration:
   ```
   MODEL=/app/models/your-model-file.gguf
   ALIAS=your-model-alias
   N_GPU_LAYERS=99  # Number of layers to offload to GPU
   CTX_SIZE=2048    # Context size.  **VERY IMPORTANT!** See below.
   N_GQA=8          # Number of group query attention heads (model specific)
   ```

   **CRITICAL: Context Size (`CTX_SIZE`)**

   *   You *must* set `CTX_SIZE` appropriately.  Do *not* set it arbitrarily large.
   *   Find the model's documentation (usually on its Hugging Face page) and determine the maximum context length it was trained with.
   *   Setting `CTX_SIZE` significantly larger than the model's trained context length will likely lead to nonsensical results.
   *   Setting `CTX_SIZE` too large for your available VRAM will cause the server to crash.  You *must* have enough VRAM for both the model and the context.
   * If you are unsure, start with a smaller value (e.g., 2048) and gradually increase it while monitoring GPU memory usage (`nvidia-smi`).

3. **Optional**: Edit the `.env` file to change the `HOST` and `PORT` if needed.

## Building and Running

1. Build the Docker image:
   ```bash
   docker compose build
   ```

2. Start the server:
   ```bash
   docker compose up -d
   ```

3. Check the logs:
   ```bash
   docker compose logs -f
   ```

## Testing the Server

Once the server is running, you can test it with a simple curl command:

```bash
curl -X POST http://localhost:8080/completion -H "Content-Type: application/json" -d '{
  "prompt": "Hello, my name is",
  "n_predict": 128
}'
```

## Stopping the Server

```bash
docker compose down
```

## Troubleshooting

If you encounter issues:

1. Check that your NVIDIA drivers and CUDA are properly installed
2. Verify that the NVIDIA Container Toolkit is correctly configured
3. Ensure your model file is compatible with llama.cpp
4. Check the logs for specific error messages:
   ```bash
   docker compose logs
   ```

## Advanced Options (llama.cpp)

The following options can be added to the `command` in `docker-compose.yml` by appending them after `--n-gqa ${N_GQA}`.  For example: `--n-gqa ${N_GQA} --verbose-prompt`.

*   `--verbose-prompt`: Print the prompt before generating text.  Useful for debugging.
*   `--mmap`: Use memory mapping for the model.  This can improve performance, but can also lead to issues if the model file is modified while the server is running.
*   `--no-mmap`: Disable memory mapping.
*   `--mlock`: Lock the model in memory.  This can prevent it from being swapped out, but can also cause the system to run out of memory.
*   `--numa`: Enable NUMA optimizations.  Relevant for systems with multiple NUMA nodes.

See the `llama.cpp` documentation for a complete list of options. 