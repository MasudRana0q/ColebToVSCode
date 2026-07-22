#!/usr/bin/env python3
"""
MCP Server for Ollama Integration
This server allows VS Code AI assistants to use Ollama models running on Colab
"""

import asyncio
import json
import os
from typing import Any
from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import Tool, TextContent
import httpx

# Configuration
OLLAMA_API_BASE = os.environ.get("OLLAMA_API_BASE", "http://127.0.0.1:11434")
MODEL_NAME = os.environ.get("MODEL_NAME", "qwen3-coder:latest")

# Create MCP server
server = Server("ollama-mcp-server")


@server.list_tools()
async def list_tools() -> list[Tool]:
    """List available tools for the MCP server"""
    return [
        Tool(
            name="ollama_chat",
            description="Send a chat message to Ollama model and get response",
            inputSchema={
                "type": "object",
                "properties": {
                    "message": {
                        "type": "string",
                        "description": "The message to send to the model"
                    },
                    "context": {
                        "type": "string",
                        "description": "Optional context or previous conversation history"
                    }
                },
                "required": ["message"]
            }
        ),
        Tool(
            name="ollama_generate",
            description="Generate text using Ollama model",
            inputSchema={
                "type": "object",
                "properties": {
                    "prompt": {
                        "type": "string",
                        "description": "The prompt for text generation"
                    },
                    "system": {
                        "type": "string",
                        "description": "Optional system prompt"
                    }
                },
                "required": ["prompt"]
            }
        ),
        Tool(
            name="ollama_status",
            description="Check Ollama server status and available models",
            inputSchema={
                "type": "object",
                "properties": {},
                "required": []
            }
        )
    ]


@server.call_tool()
async def call_tool(name: str, arguments: Any) -> list[TextContent]:
    """Handle tool calls"""
    
    async with httpx.AsyncClient(timeout=120.0) as client:
        if name == "ollama_chat":
            message = arguments.get("message", "")
            context = arguments.get("context", "")
            
            # Build messages array
            messages = []
            if context:
                messages.append({"role": "system", "content": context})
            messages.append({"role": "user", "content": message})
            
            try:
                response = await client.post(
                    f"{OLLAMA_API_BASE}/api/chat",
                    json={
                        "model": MODEL_NAME,
                        "messages": messages,
                        "stream": False
                    }
                )
                response.raise_for_status()
                result = response.json()
                return [TextContent(
                    type="text",
                    text=result.get("message", {}).get("content", "No response")
                )]
            except Exception as e:
                return [TextContent(
                    type="text",
                    text=f"Error calling Ollama: {str(e)}"
                )]
        
        elif name == "ollama_generate":
            prompt = arguments.get("prompt", "")
            system = arguments.get("system", "")
            
            try:
                response = await client.post(
                    f"{OLLAMA_API_BASE}/api/generate",
                    json={
                        "model": MODEL_NAME,
                        "prompt": prompt,
                        "system": system,
                        "stream": False
                    }
                )
                response.raise_for_status()
                result = response.json()
                return [TextContent(
                    type="text",
                    text=result.get("response", "No response")
                )]
            except Exception as e:
                return [TextContent(
                    type="text",
                    text=f"Error calling Ollama: {str(e)}"
                )]
        
        elif name == "ollama_status":
            try:
                # Check server status
                response = await client.get(f"{OLLAMA_API_BASE}/api/tags")
                response.raise_for_status()
                result = response.json()
                
                models = result.get("models", [])
                model_list = "\n".join([f"- {m.get('name', 'unknown')}" for m in models])
                
                status_text = f"""Ollama Server Status:
- API Base: {OLLAMA_API_BASE}
- Default Model: {MODEL_NAME}
- Available Models:
{model_list if model_list else "No models found"}
"""
                return [TextContent(type="text", text=status_text)]
            except Exception as e:
                return [TextContent(
                    type="text",
                    text=f"Error checking Ollama status: {str(e)}"
                )]
    
    return [TextContent(type="text", text="Unknown tool")]


async def main():
    """Main entry point for the MCP server"""
    async with stdio_server() as (read_stream, write_stream):
        await server.run(
            read_stream,
            write_stream,
            server.create_initialization_options()
        )


if __name__ == "__main__":
    asyncio.run(main())
