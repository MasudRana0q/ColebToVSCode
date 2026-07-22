# MCP Setup Guide - Coleb Ollama Integration

এই গাইডে আপনি শিখবেন কিভাবে Coleb-এ রান করা Ollama মডেলকে VS Code-এ MCP (Model Context Protocol) এর মাধ্যমে ব্যবহার করবেন।

## পূর্বশর্ত

1. **Coleb সেটআপ সম্পন্ন** - Colab-এ `bash colab_ai.sh setup` এবং `bash colab_ai.sh api` চালিয়ে Ollama server চালু থাকতে হবে
2. **Tailscale IP** - Colab থেকে পাওয়া Tailscale IP নোট করে রাখতে হবে
3. **VS Code** - আপনার লোকাল মেশিনে VS Code ইনস্টল থাকতে হবে
4. **Python 3.8+** - লোকাল মেশিনে Python ইনস্টল থাকতে হবে

## Step 1: Colab-এ Ollama Server চালু করুন

Colab-এ নিচের কমান্ড চালান:

```python
!bash /content/ColebToVSCode/colab_ai.sh api
```

এতে আপনি একটি Tailscale IP পাবেন, যেমন: `100.x.x.x`

## Step 2: লোকাল মেশিনে প্রজেক্ট ক্লোন করুন

```bash
git clone https://github.com/MasudRana0q/ColebToVSCode.git
cd ColebToVSCode
```

## Step 3: MCP Server Dependencies ইনস্টল করুন

```bash
pip install -r mcp-server/requirements.txt
```

## Step 4: VS Code MCP Configuration সেটআপ করুন

### Option A: Cline/Windsurf/Continue এর জন্য

VS Code-এ আপনার AI এক্সটেনশনের settings এ যান এবং MCP configuration যোগ করুন:

**Cline এর জন্য (`.cline/settings.json`):**
```json
{
  "mcpServers": {
    "ollama-colab": {
      "command": "python",
      "args": [
        "mcp-server/ollama-mcp-server.py"
      ],
      "env": {
        "OLLAMA_API_BASE": "http://YOUR_TAILSCALE_IP:11434",
        "MODEL_NAME": "qwen3-coder:latest"
      }
    }
  }
}
```

**Windsurf এর জন্য (`.windsurfmcp.json`):**
```json
{
  "mcpServers": {
    "ollama-colab": {
      "command": "python",
      "args": [
        "mcp-server/ollama-mcp-server.py"
      ],
      "env": {
        "OLLAMA_API_BASE": "http://YOUR_TAILSCALE_IP:11434",
        "MODEL_NAME": "qwen3-coder:latest"
      }
    }
  }
}
```

**Continue এর জন্য (`~/.continue/config.json`):**
```json
{
  "mcpServers": {
    "ollama-colab": {
      "command": "python",
      "args": [
        "/path/to/ColebToVSCode/mcp-server/ollama-mcp-server.py"
      ],
      "env": {
        "OLLAMA_API_BASE": "http://YOUR_TAILSCALE_IP:11434",
        "MODEL_NAME": "qwen3-coder:latest"
      }
    }
  }
}
```

**গুরুত্বপূর্ণ:** `YOUR_TAILSCALE_IP` কে Colab থেকে পাওয়া আসল Tailscale IP দিয়ে প্রতিস্থাপন করুন।

### Option B: VS Code Native MCP এর জন্য

VS Code settings এ যান (Ctrl+,) এবং নিচের configuration যোগ করুন:

```json
{
  "mcp.serverConfigs": {
    "ollama-colab": {
      "command": "python",
      "args": [
        "${workspaceFolder}/mcp-server/ollama-mcp-server.py"
      ],
      "env": {
        "OLLAMA_API_BASE": "http://YOUR_TAILSCALE_IP:11434",
        "MODEL_NAME": "qwen3-coder:latest"
      }
    }
  }
}
```

## Step 5: VS Code Restart করুন

VS Code বন্ধ করে আবার চালু করুন যাতে MCP configuration লোড হয়।

## Step 6: MCP Server টেস্ট করুন

VS Code-এ আপনার AI এক্সটেনশন খুলুন এবং নিচের প্রম্পট দিন:

```
Check Ollama server status using the ollama_status tool
```

এটি কাজ করলে MCP server সফলভাবে কানেক্ট হয়েছে।

## ব্যবহার করার নিয়ম

### Available Tools

MCP server টি ৩টি tool প্রদান করে:

1. **ollama_chat** - Chat করার জন্য
   - Input: `message` (required), `context` (optional)
   - Example: "Send 'Hello, how are you?' to ollama_chat"

2. **ollama_generate** - Text generation এর জন্য
   - Input: `prompt` (required), `system` (optional)
   - Example: "Generate code for a hello world function using ollama_generate"

3. **ollama_status** - Server status চেক করার জন্য
   - Input: None
   - Example: "Check Ollama server status"

### Example Prompts

```
Use ollama_chat to ask the model to write a Python function that sorts a list
```

```
Use ollama_generate with the prompt 'Explain quantum computing in simple terms'
```

```
Check if the Ollama server is running and what models are available
```

## Troubleshooting

### Problem: MCP server connection failed

**Solution:**
1. Colab-এ Ollama server চলছে কিনা চেক করুন:
   ```python
   !bash /content/ColebToVSCode/colab_ai.sh status
   ```

2. Tailscale IP সঠিক কিনা যাচাই করুন
3. লোকাল মেশিন থেকে Colab Tailscale IP এ ping করুন:
   ```bash
   ping YOUR_TAILSCALE_IP
   ```

### Problem: Python dependencies missing

**Solution:**
```bash
pip install -r mcp-server/requirements.txt
```

### Problem: Permission denied

**Solution:**
```bash
chmod +x mcp-server/ollama-mcp-server.py
```

### Problem: Model not responding

**Solution:**
1. Colab-এ model warm-up চেক করুন:
   ```python
   !bash /content/ColebToVSCode/colab_ai.sh monitor
   ```

2. Keep-alive process চলছে কিনা দেখুন

## উন্নত কনফিগারেশন

### ভিন্ন Model ব্যবহার করতে চাইলে

`MODEL_NAME` environment variable পরিবর্তন করুন:

```json
"env": {
  "OLLAMA_API_BASE": "http://YOUR_TAILSCALE_IP:11434",
  "MODEL_NAME": "llama3:latest"
}
```

### Custom API Base ব্যবহার করতে চাইলে

যদি আপনি অন্য কোন Ollama server ব্যবহার করতে চান:

```json
"env": {
  "OLLAMA_API_BASE": "http://localhost:11434",
  "MODEL_NAME": "qwen3-coder:latest"
}
```

## সুবিধাসমূহ

✅ লোকাল VS Code থেকে Colab-এর GPU power ব্যবহার
✅ কোন API key প্রয়োজন নেই
✅ ফ্রি Colab GPU ব্যবহার
✅ MCP স্ট্যান্ডার্ড ফলো করে
✅ একাধিক AI এক্সটেনশনে কাজ করে

## সীমাবদ্ধতা

⚠️ Colab runtime disconnect হলে connection বিচ্ছিন্ন হবে
⚠️ Tailscale connection stable থাকতে হবে
⚠️ Internet connection প্রয়োজন

## সাহায্য প্রয়োজন হলে

- GitHub Issues: https://github.com/MasudRana0q/ColebToVSCode/issues
- README: প্রজেক্টের main README দেখুন
