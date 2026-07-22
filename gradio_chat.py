#!/usr/bin/env python3

import json
import os
import requests
import gradio as gr

MODEL_NAME = os.environ.get("MODEL_NAME", "qwen3-coder:latest")
OLLAMA_CHAT_URL = os.environ.get("OLLAMA_CHAT_URL", "http://127.0.0.1:11434/api/chat")
OLLAMA_REQUEST_KEEP_ALIVE = os.environ.get("OLLAMA_REQUEST_KEEP_ALIVE", "-1")


def chat_response(message, history):
    messages = [{"role": "user", "content": msg} for msg, _ in history]
    messages.append({"role": "user", "content": message})
    
    try:
        response = requests.post(
            OLLAMA_CHAT_URL,
            json={
                "model": MODEL_NAME,
                "messages": messages,
                "stream": True,
                "keep_alive": OLLAMA_REQUEST_KEEP_ALIVE,
            },
            stream=True,
            timeout=600
        )
        response.raise_for_status()
        
        full_response = ""
        for line in response.iter_lines():
            if line:
                try:
                    data = json.loads(line)
                    if "message" in data and "content" in data["message"]:
                        full_response += data["message"]["content"]
                        yield full_response
                except json.JSONDecodeError:
                    continue
    except Exception as e:
        yield f"Error: {str(e)}"


def create_interface():
    with gr.Blocks(title="Colab Ollama Chat") as demo:
        gr.Markdown(f"# Colab Ollama Chat\n\n**Model:** {MODEL_NAME}")
        
        chatbot = gr.Chatbot()
        msg = gr.Textbox()
        submit = gr.Button("Send")
        clear = gr.Button("Clear")
        
        def user_message(user_message, history):
            return "", history + [[user_message, None]]
        
        def bot_response(history):
            user_msg = history[-1][0]
            history[-1][1] = ""
            for chunk in chat_response(user_msg, history[:-1]):
                history[-1][1] = chunk
                yield history
        
        msg.submit(user_message, [msg, chatbot], [msg, chatbot], queue=False).then(
            bot_response, chatbot, chatbot
        )
        
        submit.click(user_message, [msg, chatbot], [msg, chatbot], queue=False).then(
            bot_response, chatbot, chatbot
        )
        
        clear.click(lambda: None, None, chatbot, queue=False)
    
    return demo


if __name__ == "__main__":
    demo = create_interface()
    demo.launch(
        server_name="0.0.0.0",
        server_port=int(os.environ.get("CHAT_UI_PORT", "8080")),
        share=False,
        show_error=True
    )
