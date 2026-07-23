# Colab to VS Code সহজ গাইড

Repo link:

- `https://github.com/MasudRana0q/ColebToVSCode`

## কী কাজ করবে

- Colab-এ AI chat
- VS Code-এ API দিয়ে coding

## প্রথমে কী করবেন

- Google Colab খুলুন
- একটি নতুন notebook নিন
- নিচের `Step 1` cell চালান

## Step 1: Setup চালান

এই code টি Colab-এর normal code cell-এ চালান:

```python
!rm -rf /content/ColebToVSCode
!git clone https://github.com/MasudRana0q/ColebToVSCode.git
%cd /content/ColebToVSCode
!chmod +x colab_ai.sh
!bash colab_ai.sh setup
```

**মডেল সিলেকশন:**
- স্ক্রিপ্ট রান করার সময় আপনাকে একটি মডেল সিলেক্ট করতে বলা হবে
- জনপ্রিয় মডেলের লিস্ট দেখানো হবে:
  - `phi3:mini` (ছোট, দ্রুত, ~2GB)
  - `phi3:3.8b` (ভারসাম্যপূর্ণ, ~2.3GB)
  - `llama3:8b` (ভালো কোয়ালিটি, ~4.7GB)
  - `mistral:7b` (ভালো কোয়ালিটি, ~4.1GB)
  - `gemma:2b` (ছোট, ~1.6GB)
  - `qwen:0.5b` (খুব ছোট, ~0.4GB)
  - `gemma4:e4b` (Gemma 4, ~9.2GB)
- আপনি চাইলে অন্য যেকোনো Ollama মডেল নাম দিতে পারেন

**Custom model সরাসরি ব্যবহার করতে চাইলে:**

```python
!rm -rf /content/ColebToVSCode
%cd /content
!git clone https://github.com/MasudRana0q/ColebToVSCode.git
%cd /content/ColebToVSCode
!chmod +x colab_ai.sh
!MODEL_NAME=gemma4:e4b bash colab_ai.sh setup
```

এতে যা হবে:

- repo clone হবে
- `colab-xterm` install হবে
- Tailscale install হবে
- Ollama install হবে
- server start হবে
- selected model download হবে
- পরে `chat` বা `api` চালাতে অনেক কম সময় লাগবে

যদি Tailscale login link আসে, সেটি খুলে login complete করুন।

## Step 2: Chat করার ধরন বেছে নিন

### Option A: Browser tab-এ chat

Colab-এর normal code cell-এ এটা চালান:

```python
!bash /content/ColebToVSCode/colab_ai.sh webchat
```

এতে আপনি একটি URL পাবেন।

- `Tailscale URL` browser-এর নতুন tab-এ খুলুন
- terminal hang না হয়ে browser page-এ chat করতে পারবেন
- অন্য tab-এ গেলেও chat interface খোলা থাকবে

### Option B: Terminal chat

Setup শেষ হলে নতুন একটি Colab code cell-এ এটা চালান:

```python
%load_ext colabxterm
%xterm
```

এতে নিচে terminal open হবে।

## Colab-এ Chat করতে চাইলে

খোলা terminal-এর ভিতরে এটা চালান:

```bash
cd /content/ColebToVSCode
bash colab_ai.sh chat
```

তারপর terminal-এর ভিতরে normal text এর মতো লিখুন:

```text
Hi
Write a Python hello world program.
```

নোট:

- browser-based chat চাইলে `webchat` ব্যবহার করা ভালো
- `chat` command normal Colab cell-এ চালাবেন না
- terminal-এর ভিতরে চালাবেন
- `setup` একবার শেষ হলে `chat` command সাধারণত শুধু ready model ব্যবহার করবে

## VS Code-এ ব্যবহার করতে চাইলে

Colab-এর normal code cell-এ এটা চালান:

```python
!bash /content/ColebToVSCode/colab_ai.sh api
```

এতে আপনি পাবেন:

- Tailscale IP
- Ollama API Base
- Continue config
- `setup` আগে হয়ে থাকলে এখানে আর বড় model download হবে না

## VS Code-এ কোনটা বসাবেন

- `apiBase` হবে:

```text
http://YOUR_TAILSCALE_IP:11434
```

- যদি কোনো app API key চাইতেই থাকে, dummy key হিসেবে এটা দিতে পারেন:

```text
ollama
```

## Trae AI / Cursor / Windsurf এ ব্যবহার করতে চাইলে

### Trae AI এর জন্য নির্দিষ্ট সেটিংস:

1. Trae AI খুলুন এবং **Add Model** এ ক্লিক করুন
2. **Custom Config** ট্যাব সিলেক্ট করুন
3. নিচের মানগুলো দিন:

   - **API Format**: `OpenAI Chat Completions`
   - **Custom Request URL**:
     - **Full URL** toggle কর **ON** করুন
     - URL: `http://YOUR_TAILSCALE_IP:11434/v1`
   - **Model ID**: আপনার সিলেক্ট করা মডেল
   - **API Key**: `ollama` (dummy key)
   - **Multimodal**: **OFF**

4. **Advanced Settings** এ ক্লিক করুন:
   - **Tools** বা **Function Calling** বন্ধ করে দিন
   - ছোট মডেলগুলোতে tools support নেই থাকতে পারে

5. **Add Model** বাটনে ক্লিক করুন

### Cursor / Windsurf এর জন্য:

- **Base URL**: `http://YOUR_TAILSCALE_IP:11434`
- **Model**: আপনার সিলেক্ট করা মডেল
- **API Key**: `ollama` (অথবা যেকোনো dummy key)
- Tools/Function Calling বন্ধ করে দিন

**গুরুত্বপূর্ণ:**
- অবশ্যই Tailscale IP ব্যবহার করবেন, localhost বা 127.0.0.1 ব্যবহার করবেন না
- ছোট মডেলগুলোতে (যেমন phi3:mini, qwen:0.5b) tools support নেই থাকতে পারে, তাই tools বন্ধ করতে হবে

## দরকারি command

Status দেখার জন্য:

```python
!bash /content/ColebToVSCode/colab_ai.sh status
```

Config আবার দেখার জন্য:

```python
!bash /content/ColebToVSCode/colab_ai.sh config
```

# Activity monitor দেখতে
!bash colab_ai.sh monitor

# Keep-alive log দেখতে
!cat /tmp/keep_alive.log

Server বন্ধ করার জন্য:

```python
!bash /content/ColebToVSCode/colab_ai.sh stop
```

Web chat চালু করার জন্য:

```python
!bash /content/ColebToVSCode/colab_ai.sh webchat
```

## যদি runtime reset হয়

Colab runtime reset হলে আবার `Step 1` থেকে শুরু করবেন।

## এক লাইনে মনে রাখুন

- `Step 1` = setup + model preload
- `Step 2` = `webchat` বা terminal open
- `webchat` = browser tab-এ chat
- `chat` = terminal-এর ভিতরে CLI chat
- `api` = normal Colab cell-এ

## সার্ভার আবার চালু করতে চাইলে

কোডিং করার জন্য server নতুন করে চালু করতে চাইলে এটা চালান:

```python
!bash /content/ColebToVSCode/colab_ai.sh restart
```

এতে যা হবে:

- পুরনো Ollama server বন্ধ হবে
- নতুন করে server চালু হবে
- API info আবার দেখাবে

## সার্ভার চলছে কিনা দেখবেন যেভাবে

```python
!bash /content/ColebToVSCode/colab_ai.sh status
```

এতে দেখতে পাবেন:

- `tailscaled` চলছে কিনা
- `tailscale login` connected কিনা
- `ollama serve` চলছে কিনা
- model install আছে কিনা

## সার্ভার বন্ধ করতে চাইলে

```python
!bash /content/ColebToVSCode/colab_ai.sh stop
```


Check Logs 
```python
!cat /tmp/colab-chat-ui.log
```
or
```python
!bash /content/ColebToVSCode/colab_ai.sh log
```