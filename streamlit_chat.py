#!/usr/bin/env python3

import json
import os
import requests
import streamlit as st

MODEL_NAME = os.environ.get("MODEL_NAME", "qwen3-coder:latest")
OLLAMA_CHAT_URL = os.environ.get("OLLAMA_CHAT_URL", "http://127.0.0.1:11434/api/chat")

st.set_page_config(page_title="Colab Ollama Chat", page_icon="🤖")

st.title(f"Colab Ollama Chat")
st.caption(f"Model: {MODEL_NAME}")

if "messages" not in st.session_state:
    st.session_state.messages = []

for message in st.session_state.messages:
    with st.chat_message(message["role"]):
        st.markdown(message["content"])

if prompt := st.chat_input("Type your message here..."):
    st.session_state.messages.append({"role": "user", "content": prompt})
    with st.chat_message("user"):
        st.markdown(prompt)

    with st.chat_message("assistant"):
        message_placeholder = st.empty()
        full_response = ""
        
        messages = [{"role": m["role"], "content": m["content"]} for m in st.session_state.messages]
        
        try:
            response = requests.post(
                OLLAMA_CHAT_URL,
                json={"model": MODEL_NAME, "messages": messages, "stream": True},
                stream=True,
                timeout=600
            )
            response.raise_for_status()
            
            for line in response.iter_lines():
                if line:
                    try:
                        data = json.loads(line)
                        if "message" in data and "content" in data["message"]:
                            full_response += data["message"]["content"]
                            message_placeholder.markdown(full_response + "▌")
                    except json.JSONDecodeError:
                        continue
            
            message_placeholder.markdown(full_response)
        except Exception as e:
            full_response = f"Error: {str(e)}"
            message_placeholder.markdown(full_response)
    
    st.session_state.messages.append({"role": "assistant", "content": full_response})
