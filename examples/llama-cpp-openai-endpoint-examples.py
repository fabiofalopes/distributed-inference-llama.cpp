import requests
import json
from typing import List, Dict
import time

class LlamaCppClient:
    def __init__(self, base_url: str = "http://192.168.1.33:8080"):
        self.base_url = base_url
        
    def chat_completion(
        self, 
        messages: List[Dict[str, str]], 
        model: str = "phi-4-Q4_K_M.gguf",
        temperature: float = 0.7,
        max_tokens: int = 256
    ) -> Dict:
        """
        Send a chat completion request to the llama.cpp server
        """
        endpoint = f"{self.base_url}/v1/chat/completions"
        
        payload = {
            "model": model,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": max_tokens
        }
        
        headers = {
            "Content-Type": "application/json"
        }
        
        try:
            response = requests.post(endpoint, json=payload, headers=headers)
            response.raise_for_status()  # Raise exception for bad status codes
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"Error making request: {e}")
            return None

    def completion(
        self, 
        prompt: str, 
        model: str = "phi-4-Q4_K_M.gguf",
        temperature: float = 0.7,
        max_tokens: int = 256
    ) -> Dict:
        """
        Send a text completion request to the llama.cpp server
        """
        endpoint = f"{self.base_url}/v1/completions"
        
        payload = {
            "model": model,
            "prompt": prompt,
            "temperature": temperature,
            "max_tokens": max_tokens
        }
        
        headers = {
            "Content-Type": "application/json"
        }
        
        try:
            response = requests.post(endpoint, json=payload, headers=headers)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"Error making request: {e}")
            return None

    def get_models(self) -> Dict:
        """
        Get available models from the server
        """
        endpoint = f"{self.base_url}/v1/models"
        
        try:
            response = requests.get(endpoint)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"Error making request: {e}")
            return None

def main():
    # Initialize client
    client = LlamaCppClient()
    
    # Example 1: Chat completion
    messages = [
        {"role": "user", "content": "What is artificial intelligence?"}
    ]
    
    print("\nTesting chat completion...")
    response = client.chat_completion(messages)
    if response:
        print(json.dumps(response, indent=2))
    
    # Example 2: Text completion
    prompt = "Write a short poem about programming:"
    
    print("\nTesting text completion...")
    response = client.completion(prompt)
    if response:
        print(json.dumps(response, indent=2))
    
    # Example 3: Get models
    print("\nGetting available models...")
    response = client.get_models()
    if response:
        print(json.dumps(response, indent=2))

    # Example 4: Multi-turn conversation
    print("\nTesting multi-turn conversation...")
    conversation = [
        {"role": "user", "content": "Hi, I'd like to learn about quantum computing."},
        {"role": "assistant", "content": "I'd be happy to help you learn about quantum computing. What specific aspect would you like to know about?"},
        {"role": "user", "content": "What are qubits?"}
    ]
    
    response = client.chat_completion(conversation)
    if response:
        print(json.dumps(response, indent=2))

if __name__ == "__main__":
    main()
