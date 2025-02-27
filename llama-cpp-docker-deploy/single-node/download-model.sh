#!/bin/bash

# This script helps download GGUF models from Hugging Face

# Check if huggingface-cli is installed
if ! command -v huggingface-cli &> /dev/null; then
    echo "huggingface-cli not found. Installing..."
    pip install huggingface_hub
fi

# Create models directory if it doesn't exist
mkdir -p models

# Function to download a model
download_model() {
    local repo=$1
    local filename=$2
    
    echo "Downloading $filename from $repo..."
    huggingface-cli download $repo $filename --local-dir models --local-dir-use-symlinks False
}

# Display help message
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Download GGUF models from Hugging Face."
    echo ""
    echo "Options:"
    echo "  -r, --repo REPO      Hugging Face repository (e.g., TheBloke/DeepSeek-R1-Distill-Llama-8B-GGUF)"
    echo "  -f, --file FILENAME  Model filename (e.g., DeepSeek-R1-Distill-Llama-8B-Q6_K.gguf)"
    echo "  -h, --help           Display this help message"
    echo ""
    echo "Example:"
    echo "  $0 -r TheBloke/DeepSeek-R1-Distill-Llama-8B-GGUF -f DeepSeek-R1-Distill-Llama-8B-Q6_K.gguf"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--repo)
            REPO="$2"
            shift 2
            ;;
        -f|--file)
            FILENAME="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Check if required arguments are provided
if [ -z "$REPO" ] || [ -z "$FILENAME" ]; then
    echo "Error: Repository and filename are required."
    show_help
    exit 1
fi

# Download the model
download_model "$REPO" "$FILENAME"

# Update .env file
if [ -f ".env" ]; then
  # Use more robust sed commands that handle different line endings and quoting
  sed -i 's|^MODEL_FILE=.*|MODEL_FILE='"$FILENAME"'|' .env
  sed -i 's|^MODEL_ALIAS=.*|MODEL_ALIAS='"${FILENAME%.*}"'|' .env
  echo "Updated .env file with new model information."
else
    echo "Creating .env file..."
    cat <<EOF > .env
MODEL_FILE=$FILENAME
MODEL_ALIAS=${FILENAME%.*}
N_GPU_LAYERS=99
CTX_SIZE=2048  # IMPORTANT: Set this to the model's trained context size!
N_GQA=8 # Important for some models.
HOST=0.0.0.0
PORT=8080
CUDA_ARCHITECTURES=75
EOF
    echo "Created .env file.  Please review and edit it!"
fi

echo "Done! Model downloaded to models/$FILENAME"
echo "You can now run 'docker compose up -d' to start the server."

# Make the script executable
chmod +x download-model.sh 