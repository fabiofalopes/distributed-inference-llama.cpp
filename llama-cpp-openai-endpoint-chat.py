import requests
import json
from typing import List, Dict
import time
from rich.console import Console
from rich.markdown import Markdown

class ChatBot:
    def __init__(self, base_url: str = "http://192.168.1.33:8080"):
        self.base_url = base_url
        self.console = Console()
        self.conversation_history = []
        
    def chat(self, message: str) -> str:
        """Send a message and get response from the LLM"""
        
        # Add user message to history
        self.conversation_history.append({"role": "user", "content": message})
        
        payload = {
            "model": "phi-4-Q4_K_M.gguf",
            #"model": "mixtral-8x7b-instruct-v0.1.Q3_K_M.gguf",
            "messages": self.conversation_history,
            "temperature": 0.7,
            "max_tokens": 512
        }
        
        headers = {"Content-Type": "application/json"}
        
        try:
            response = requests.post(
                f"{self.base_url}/v1/chat/completions",
                json=payload,
                headers=headers
            )
            response.raise_for_status()
            
            # Extract assistant's message
            assistant_message = response.json()['choices'][0]['message']['content']
            
            # Add assistant's response to history
            self.conversation_history.append({"role": "assistant", "content": assistant_message})
            
            return assistant_message
            
        except requests.exceptions.RequestException as e:
            return f"Error: {str(e)}"

    def clear_history(self):
        """Clear conversation history"""
        self.conversation_history = []
        self.console.print("\n[yellow]Conversation history cleared![/yellow]\n")

def main():
    console = Console()
    
    # ASCII Art Welcome
    welcome_text = """
    🤖 Local LLM Chat Interface 🤖
    Model: Phi-4
    Type 'quit' to exit, 'clear' to reset chat history
    ----------------------------------------
    """
    
    console.print(f"[bold blue]{welcome_text}[/bold blue]")
    
    # Initialize chatbot
    bot = ChatBot()
    
    while True:
        # Get user input
        user_input = console.input("[bold green]You:[/bold green] ")
        
        # Check for commands
        if user_input.lower() == 'quit':
            console.print("\n[bold red]Goodbye![/bold red]\n")
            break
        elif user_input.lower() == 'clear':
            bot.clear_history()
            continue
        
        # Show thinking indicator
        with console.status("[bold yellow]Thinking...[/bold yellow]"):
            response = bot.chat(user_input)
        
        # Print response with markdown formatting
        console.print("\n[bold blue]Assistant:[/bold blue]")
        console.print(Markdown(response))
        console.print("\n----------------------------------------\n")

if __name__ == "__main__":
    main()
