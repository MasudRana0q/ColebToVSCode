#!/usr/bin/env python3

import json
import os
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


MODEL_NAME = os.environ.get("MODEL_NAME", "qwen3-coder:latest")
HOST = os.environ.get("CHAT_UI_HOST", "0.0.0.0")
PORT = int(os.environ.get("CHAT_UI_PORT", "8080"))
OLLAMA_CHAT_URL = os.environ.get("OLLAMA_CHAT_URL", "http://127.0.0.1:11434/api/chat")


HTML_PAGE = """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Colab Ollama Chat</title>
  <style>
    :root {
      color-scheme: dark;
      --bg: #0b1020;
      --panel: #121936;
      --panel-2: #192247;
      --text: #e8ecff;
      --muted: #9fb0ee;
      --accent: #6ea8fe;
      --accent-2: #8fbc8f;
      --border: #2a376a;
      --danger: #ff8c8c;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: Arial, sans-serif;
      background: linear-gradient(180deg, #09101e 0%, #121936 100%);
      color: var(--text);
    }
    .wrap {
      max-width: 980px;
      margin: 0 auto;
      padding: 20px;
    }
    .topbar {
      display: flex;
      justify-content: space-between;
      align-items: center;
      gap: 16px;
      margin-bottom: 16px;
    }
    .title {
      font-size: 24px;
      font-weight: 700;
    }
    .subtitle {
      color: var(--muted);
      font-size: 14px;
      margin-top: 4px;
    }
    .actions {
      display: flex;
      gap: 10px;
      flex-wrap: wrap;
    }
    button {
      border: 1px solid var(--border);
      background: var(--panel-2);
      color: var(--text);
      padding: 10px 14px;
      border-radius: 10px;
      cursor: pointer;
      font-size: 14px;
    }
    button.primary {
      background: var(--accent);
      color: #08101f;
      border-color: #7bb2ff;
      font-weight: 700;
    }
    button:disabled {
      opacity: 0.6;
      cursor: not-allowed;
    }
    .card {
      background: rgba(18, 25, 54, 0.92);
      border: 1px solid var(--border);
      border-radius: 16px;
      padding: 16px;
      box-shadow: 0 18px 50px rgba(0, 0, 0, 0.35);
    }
    .status {
      margin-bottom: 14px;
      color: var(--muted);
      font-size: 14px;
    }
    .chat-box {
      height: 60vh;
      overflow-y: auto;
      border: 1px solid var(--border);
      border-radius: 12px;
      padding: 14px;
      background: rgba(9, 16, 32, 0.7);
    }
    .msg {
      padding: 12px 14px;
      border-radius: 12px;
      margin-bottom: 12px;
      white-space: pre-wrap;
      line-height: 1.5;
    }
    .user {
      background: #243465;
      margin-left: 10%;
    }
    .assistant {
      background: #17213f;
      margin-right: 10%;
      border: 1px solid #263669;
    }
    .system {
      background: #112b1d;
      color: #c6f1c6;
      border: 1px solid #29573e;
    }
    .error {
      background: #3c1f27;
      color: #ffd3d8;
      border: 1px solid #7a3848;
    }
    .composer {
      display: grid;
      grid-template-columns: 1fr auto;
      gap: 12px;
      margin-top: 14px;
    }
    textarea {
      min-height: 96px;
      resize: vertical;
      background: rgba(9, 16, 32, 0.9);
      color: var(--text);
      border: 1px solid var(--border);
      border-radius: 12px;
      padding: 12px;
      font-size: 15px;
      font-family: Arial, sans-serif;
    }
    .hint {
      color: var(--muted);
      font-size: 13px;
      margin-top: 10px;
    }
    .pill {
      display: inline-block;
      margin-top: 10px;
      padding: 6px 10px;
      border-radius: 999px;
      background: #122542;
      border: 1px solid #254976;
      color: #c9ddff;
      font-size: 12px;
    }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="topbar">
      <div>
        <div class="title">Colab Ollama Chat</div>
        <div class="subtitle">Model: __MODEL_NAME__</div>
      </div>
      <div class="actions">
        <button id="newChat">New Chat</button>
        <button id="stopBtn">Stop Current Reply</button>
      </div>
    </div>

    <div class="card">
      <div id="status" class="status">Ready.</div>
      <div id="chatBox" class="chat-box"></div>
      <div class="pill">Open this page in another tab and keep chatting without blocking the terminal.</div>
      <div class="composer">
        <textarea id="prompt" placeholder="Write your message here... Shift+Enter for new line"></textarea>
        <button id="sendBtn" class="primary">Send</button>
      </div>
      <div class="hint">Enter = send, Shift+Enter = new line</div>
    </div>
  </div>

  <script>
    const modelName = "__MODEL_NAME__";
    const chatBox = document.getElementById("chatBox");
    const promptEl = document.getElementById("prompt");
    const sendBtn = document.getElementById("sendBtn");
    const stopBtn = document.getElementById("stopBtn");
    const newChatBtn = document.getElementById("newChat");
    const statusEl = document.getElementById("status");
    let messages = [];
    let currentController = null;

    function setStatus(text) {
      statusEl.textContent = text;
    }

    function scrollToBottom() {
      chatBox.scrollTop = chatBox.scrollHeight;
    }

    function addMessage(role, content) {
      const el = document.createElement("div");
      el.className = "msg " + role;
      el.textContent = content;
      chatBox.appendChild(el);
      scrollToBottom();
      return el;
    }

    function resetChat() {
      messages = [];
      chatBox.innerHTML = "";
      addMessage("system", "New chat started. Model: " + modelName);
      setStatus("Ready.");
      promptEl.focus();
    }

    async function sendMessage() {
      const content = promptEl.value.trim();
      if (!content || currentController) {
        return;
      }

      messages.push({ role: "user", content });
      addMessage("user", content);
      promptEl.value = "";
      const assistantEl = addMessage("assistant", "");
      setStatus("Generating reply...");
      sendBtn.disabled = true;

      currentController = new AbortController();
      let assistantText = "";

      try {
        const response = await fetch("/api/chat", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ messages }),
          signal: currentController.signal
        });

        if (!response.ok || !response.body) {
          throw new Error("Failed to start chat response.");
        }

        const reader = response.body.getReader();
        const decoder = new TextDecoder();
        let buffer = "";

        while (true) {
          const { value, done } = await reader.read();
          if (done) {
            break;
          }

          buffer += decoder.decode(value, { stream: true });
          const lines = buffer.split("\\n");
          buffer = lines.pop();

          for (const line of lines) {
            if (!line.trim()) {
              continue;
            }

            const item = JSON.parse(line);

            if (item.error) {
              throw new Error(item.error);
            }

            if (item.message && item.message.content) {
              assistantText += item.message.content;
              assistantEl.textContent = assistantText;
              scrollToBottom();
            }
          }
        }

        if (buffer.trim()) {
          const item = JSON.parse(buffer);
          if (item.error) {
            throw new Error(item.error);
          }
          if (item.message && item.message.content) {
            assistantText += item.message.content;
            assistantEl.textContent = assistantText;
          }
        }

        messages.push({ role: "assistant", content: assistantText || "(empty response)" });
        setStatus("Ready.");
      } catch (error) {
        assistantEl.className = "msg error";
        assistantEl.textContent = "Error: " + error.message;
        setStatus("Error.");
      } finally {
        currentController = null;
        sendBtn.disabled = false;
        scrollToBottom();
      }
    }

    sendBtn.addEventListener("click", sendMessage);

    stopBtn.addEventListener("click", () => {
      if (currentController) {
        currentController.abort();
        currentController = null;
        sendBtn.disabled = false;
        setStatus("Stopped.");
      }
    });

    newChatBtn.addEventListener("click", resetChat);

    promptEl.addEventListener("keydown", (event) => {
      if (event.key === "Enter" && !event.shiftKey) {
        event.preventDefault();
        sendMessage();
      }
    });

    resetChat();
  </script>
</body>
</html>
"""


def build_html():
    return HTML_PAGE.replace("__MODEL_NAME__", MODEL_NAME)


class ChatUIHandler(BaseHTTPRequestHandler):
    server_version = "ColabChatUI/1.0"

    def log_message(self, format, *args):
        return

    def _send_json(self, status_code, payload):
        data = json.dumps(payload).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path in ("/", "/index.html"):
            page = build_html().encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(page)))
            self.end_headers()
            self.wfile.write(page)
            return

        if self.path == "/health":
            self._send_json(200, {"ok": True, "model": MODEL_NAME})
            return

        self._send_json(404, {"error": "Not found"})

    def do_POST(self):
        if self.path != "/api/chat":
            self._send_json(404, {"error": "Not found"})
            return

        content_length = int(self.headers.get("Content-Length", "0"))
        if content_length <= 0:
            self._send_json(400, {"error": "Missing request body"})
            return

        raw_body = self.rfile.read(content_length)
        try:
            payload = json.loads(raw_body.decode("utf-8"))
        except json.JSONDecodeError:
            self._send_json(400, {"error": "Invalid JSON"})
            return

        messages = payload.get("messages")
        if not isinstance(messages, list) or not messages:
            self._send_json(400, {"error": "messages must be a non-empty list"})
            return

        ollama_payload = json.dumps(
            {
                "model": MODEL_NAME,
                "messages": messages,
                "stream": True,
            }
        ).encode("utf-8")

        request = urllib.request.Request(
            OLLAMA_CHAT_URL,
            data=ollama_payload,
            headers={"Content-Type": "application/json"},
            method="POST",
        )

        self.send_response(200)
        self.send_header("Content-Type", "application/x-ndjson; charset=utf-8")
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()

        try:
            with urllib.request.urlopen(request, timeout=600) as response:
                while True:
                    line = response.readline()
                    if not line:
                        break
                    self.wfile.write(line)
                    self.wfile.flush()
        except urllib.error.HTTPError as error:
            message = error.read().decode("utf-8", errors="replace")
            payload = json.dumps({"error": f"Ollama HTTP error: {message}"}).encode("utf-8")
            self.wfile.write(payload + b"\n")
            self.wfile.flush()
        except Exception as error:
            payload = json.dumps({"error": f"Chat backend error: {error}"}).encode("utf-8")
            self.wfile.write(payload + b"\n")
            self.wfile.flush()


def main():
    server = ThreadingHTTPServer((HOST, PORT), ChatUIHandler)
    print(f"Chat UI listening on http://{HOST}:{PORT}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
