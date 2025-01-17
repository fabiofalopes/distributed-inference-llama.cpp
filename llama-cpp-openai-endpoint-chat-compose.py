import requests
import json
from typing import List, Dict
import time
from datetime import datetime
from rich.console import Console
from rich.markdown import Markdown

MODEL = "gemma-2-27b-it-IQ2_XS.gguf"

# Define the system prompt for LLM header generation
HEADER_SYSTEM_PROMPT = """You are an assistant that generates a detailed summary header for a chat session. Include:
1. Model name
2. Session start time
3. Key topics or intents of the conversation based on the user's input.
Output this information in Markdown format.
"""

SYSTEM_PROMPT = """"
system text
"""

class ChatBot:
    def __init__(self, base_url: str = "http://192.168.1.33:8080"):
        self.base_url = base_url
        self.console = Console()
        self.conversation_history = [{"role": "system", "content": SYSTEM_PROMPT}]
        self.session_start_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        self.header = ""

    def chat(self, message: str) -> str:
        """Send a message and get a response from the LLM."""
        self.conversation_history.append({"role": "user", "content": message})

        payload = {
            "model": MODEL,
            "messages": self.conversation_history,
            "temperature": 0.7,
            "max_tokens": 4080
        }

        headers = {"Content-Type": "application/json"}

        try:
            response = requests.post(
                f"{self.base_url}/v1/chat/completions",
                json=payload,
                headers=headers
            )
            response.raise_for_status()

            assistant_message = response.json()['choices'][0]['message']['content']
            self.conversation_history.append({"role": "assistant", "content": assistant_message})
            return assistant_message

        except requests.exceptions.RequestException as e:
            return f"Error: {str(e)}"

    def clear_history(self):
        """Clear conversation history."""
        self.conversation_history = [{"role": "system", "content": SYSTEM_PROMPT}]
        self.console.print("\n[yellow]Conversation history cleared![/yellow]\n")

    def generate_header(self):
        """Generate a Markdown header for the chat session."""
        payload = {
            "model": MODEL,
            "messages": [
                {"role": "system", "content": HEADER_SYSTEM_PROMPT},
                {"role": "user", "content": f"Model: {MODEL}\nSession Start: {self.session_start_time}"}
            ],
            "temperature": 0.7,
            "max_tokens": 500
        }

        headers = {"Content-Type": "application/json"}

        try:
            response = requests.post(
                f"{self.base_url}/v1/chat/completions",
                json=payload,
                headers=headers
            )
            response.raise_for_status()
            self.header = response.json()['choices'][0]['message']['content']
        except requests.exceptions.RequestException as e:
            self.console.print(f"Error generating header: {str(e)}", style="red")

    def save_chat_to_markdown(self, filename: str):
        """Save the chat history to a Markdown file."""
        try:
            with open(filename, "w", encoding="utf-8") as f:
                # Write header if available
                if self.header:
                    f.write(self.header + "\n\n")

                # Write chat history
                for message in self.conversation_history:
                    role = "### User" if message["role"] == "user" else "### Assistant"
                    content = message["content"]
                    f.write(f"{role}:\n{content}\n\n")
            self.console.print(f"\n[green]Chat successfully saved to {filename}[/green]\n")
        except IOError as e:
            self.console.print(f"Error saving chat: {str(e)}", style="red")

def main():
    console = Console()
    
    # ASCII Art Welcome
    welcome_text = f"""
    🤖 Local LLM Chat Interface 🤖
    Model: {MODEL}
    Type 'quit' to exit, 'clear' to reset chat history, 'save' to export chat as Markdown
    ----------------------------------------
    """
    console.print(f"[bold blue]{welcome_text}[/bold blue]")

    bot = ChatBot()
    bot.generate_header()

    while True:
        user_input = console.input("[bold green]You:[/bold green] ")

        if user_input.lower() == 'quit':
            filename = f"chat_{datetime.now().strftime('%Y%m%d_%H%M%S')}.md"
            bot.save_chat_to_markdown(filename)
            console.print("\n[bold red]Goodbye![/bold red]\n")
            break
        elif user_input.lower() == 'clear':
            bot.clear_history()
            continue
        elif user_input.lower() == 'save':
            filename = f"chat_{datetime.now().strftime('%Y%m%d_%H%M%S')}.md"
            bot.save_chat_to_markdown(filename)
            continue

        with console.status("[bold yellow]Thinking...[/bold yellow]"):
            response = bot.chat(user_input)

        console.print("\n[bold blue]Assistant:[/bold blue]")
        console.print(Markdown(response))
        console.print("\n----------------------------------------\n")

if __name__ == "__main__":
    main()

