#!/usr/bin/env python3

import json
import os
import requests
import streamlit as st

MODEL_NAME = os.environ.get("MODEL_NAME", "")
OLLAMA_CHAT_URL = os.environ.get("OLLAMA_CHAT_URL", "http://127.0.0.1:11434/api/chat")
OLLAMA_BASE_URL = OLLAMA_CHAT_URL.replace("/api/chat", "")
SYSTEM_PROMPT = os.environ.get("SYSTEM_PROMPT", "")

st.set_page_config(page_title="Colab Ollama Chat", page_icon="🤖")

if not MODEL_NAME:
    st.error("❌ ERROR: No model selected!")
    st.info("Please run the setup script with a model selection first:")
    st.code("bash colab_ai.sh setup", language="bash")
    st.stop()

st.title(f"Colab Ollama Chat")
st.caption(f"Model: {MODEL_NAME}")

# System prompt input
if not SYSTEM_PROMPT:
    SYSTEM_PROMPT = st.text_area(
        "System Prompt (optional - sets AI behavior)",
        placeholder="তুমি একজন বিশেষজ্ঞ কোডার...",
        height=100
    )
else:
    st.caption(f"System prompt set via environment variable")
    with st.expander("View/Edit System Prompt"):
        SYSTEM_PROMPT = st.text_area("System Prompt", value=SYSTEM_PROMPT, height=100)

# Connection status check
try:
    response = requests.get(f"{OLLAMA_BASE_URL}/api/tags", timeout=5)
    if response.status_code == 200:
        st.success("✅ Connected to Ollama server")
    else:
        st.error(f"❌ Ollama server returned status {response.status_code}")
except Exception as e:
    st.error(f"❌ Cannot connect to Ollama server: {str(e)}")
    st.info(f"Make sure Ollama is running at {OLLAMA_BASE_URL}")

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
        
        # Add system prompt if provided
        if SYSTEM_PROMPT.strip():
            messages = [{"role": "system", "content": SYSTEM_PROMPT.strip()}] + messages

        try:
            response = requests.post(
                OLLAMA_CHAT_URL,
                json={"model": MODEL_NAME, "messages": messages, "stream": True, "keep_alive": "48h"},
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
        except requests.exceptions.Timeout:
            full_response = "Error: Request timeout. The model may still be loading."
            message_placeholder.markdown(full_response)
        except requests.exceptions.ConnectionError:
            full_response = f"Error: Cannot connect to Ollama at {OLLAMA_CHAT_URL}. Make sure the server is running."
            message_placeholder.markdown(full_response)
        except Exception as e:
            full_response = f"Error: {str(e)}"
            message_placeholder.markdown(full_response)

    st.session_state.messages.append({"role": "assistant", "content": full_response})
