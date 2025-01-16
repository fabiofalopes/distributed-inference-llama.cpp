# Chat with llama cpp 

Simple chat interface for a distributed llama.cpp setup.

## Setup

1. Install dependencies:
```bash
pip install requests rich
```

2. Configure server URL in `config.py`:
```python
base_url = "http://192.168.1.33:8080"  # Your llama.cpp server address
```

3. Run chat:
```bash
python chat.py
```

## Commands
- `quit` - Exit
- `clear` - Reset history

> For llama.cpp backend setup details, see [notes/Local_Distributed_LLM_Setup.md](notes/Local_Distributed_LLM_Setup.md)
> For this chat [notes/Local_LLM_Chat_Interface.md](notes/Local_LLM_Chat_Interface.md)

