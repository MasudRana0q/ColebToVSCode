# Colab to VS Code Automation

This repo turns the manual Colab + Tailscale + Ollama process into a small automation flow.

## What You Get

- `chat` mode: talk to the model directly inside Colab using `ollama run`
- `api` mode: start a remote Ollama endpoint for VS Code / Continue
- `config` output: prints a ready-to-copy Continue config using the current Tailscale IP
- `status` output: shows whether Tailscale, Ollama, and the model are ready

## Files

- `colab_ai.sh` - main automation script
- `continue-config-template.yaml` - static template for Continue
- `Coleb-To-VS-Code.ipynb` - Colab notebook template
- `Coleb To VS Code.md` - original manual step-by-step notes

## Recommended GitHub Flow

1. Push this folder to GitHub.
2. Open Colab.
3. Upload or open `Coleb-To-VS-Code.ipynb`.
4. Update the repository URL in the notebook.
5. Run the notebook cells from top to bottom.

## Quick Start Without Notebook

Run these commands inside a Colab terminal:

```bash
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git
cd YOUR_REPO
chmod +x colab_ai.sh
bash colab_ai.sh setup
```

After setup, choose one of the two modes below.

## Mode 1: Chat Inside Colab

This mode opens the model directly in Colab so you can chat there.

```bash
bash colab_ai.sh chat
```

Example prompts:

```text
Hi
Write a Python hello world program.
Create a React Todo App.
```

## Mode 2: API For VS Code

This mode starts Ollama, ensures the model exists, prints the Tailscale IP, and prints a Continue config.

```bash
bash colab_ai.sh api
```

You will get output like:

```text
Ollama API Base : http://100.x.x.x:11434
OpenAI Base URL : http://100.x.x.x:11434/v1
Dummy API Key   : ollama
```

## Important API Key Note

Ollama does not create a real secure API key like cloud providers do.

- For `Continue` with `provider: ollama`, use `apiBase` and do not depend on an API key.
- For tools that require a non-empty OpenAI-style key field, you can use the dummy value `ollama`.
- The actual connection is controlled by your Tailscale network, not by the dummy key.

## Continue Setup

Run:

```bash
bash colab_ai.sh config
```

Then copy the printed YAML into your Continue config, or start from `continue-config-template.yaml` and replace `YOUR_TAILSCALE_IP`.

## Useful Commands

```bash
bash colab_ai.sh status
bash colab_ai.sh config
bash colab_ai.sh stop
```

## Runtime Notes

- If the Colab runtime resets, you need to run the setup again.
- If the model already exists in the same runtime storage, `ollama pull` is skipped.
- Tailscale login may still need manual approval when the runtime changes.
- The Tailscale IP can change when you reconnect.
