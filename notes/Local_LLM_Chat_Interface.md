# Local LLM Chat Interface

## Requirements
```bash
pip install requests rich
```

## Scripts Overview

### 1. API Client (`llama_client.py`)
Basic API wrapper for llama.cpp server endpoints.

```python
from llama_client import LlamaCppClient

# Initialize client
client = LlamaCppClient(base_url="http://192.168.1.33:8080")

# Simple chat request
response = client.chat_completion([
    {"role": "user", "content": "Hello!"}
])
```

### 2. Interactive Chat (`chat.py`)
Console-based chat interface with rich formatting.

```python
python chat.py
```

## Configuration

### Server Settings
```python
# Default settings (modify as needed)
base_url = "http://192.168.1.33:8080"
model_name = "phi-4-Q4_K_M.gguf"
```

### Chat Parameters
```python
# Adjustable parameters
temperature = 0.7
max_tokens = 512
```

## Usage Examples

### Basic API Usage
```python
from llama_client import LlamaCppClient

client = LlamaCppClient()

# Chat completion
response = client.chat_completion([
    {"role": "user", "content": "What is Python?"}
])

# Text completion
response = client.completion(
    prompt="Write a poem about coding",
    temperature=0.8
)

# Get available models
models = client.get_models()
```

### Interactive Chat Commands
```
quit  - Exit the chat
clear - Reset conversation history
```

## Error Handling
The scripts include handling for:
- Network connectivity issues
- API errors
- Invalid responses
- Server timeouts

## Best Practices

### Memory Management
```python
# Clear conversation history periodically
bot.clear_history()  # Available in chat interface
```

### Request Optimization
```python
# Adjust based on your needs
max_tokens = 512     # Length of responses
temperature = 0.7    # Creativity vs determinism
```

### Network Resilience
```python
# Timeout settings
timeout = (5, 30)  # (connect timeout, read timeout)
```

## Customization

### Adding Custom Commands
```python
if user_input.lower() == 'custom':
    # Handle custom command
    pass
```

### Modifying Output Format
```python
# Rich formatting examples
console.print("[bold red]Error:[/bold red]", message)
console.print(Markdown(response))
```

## Known Issues & Solutions

### Connection Errors
```python
try:
    response = requests.post(...)
except requests.exceptions.ConnectionError:
    print("Server unavailable")
```

### Response Timeout
```python
# Increase timeouts for longer responses
response = requests.post(
    url,
    timeout=(5, 60)  # (connect, read)
)
```

## TODO
1. Web interface 
2. Response streaming
3. Model parameter adjustment interface
4. Chat history export/import
5. System prompt customization
## Acknowledgments
- llama.cpp project
- Rich library for console formatting
- Requests library for API communication


