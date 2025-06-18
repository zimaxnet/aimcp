# ai-mcp-system
Reusable AI system with React frontend, Azure B2C auth, CosmosDB memory, and 100+ MCP server integrations
# AI MCP System

A comprehensive AI system featuring React frontend, Azure B2C authentication, CosmosDB memory storage, and integration with 100+ Model Context Protocol (MCP) servers.

![Architecture](docs/architecture.png)

## Features

- 🔐 **Azure B2C Authentication** - Secure user management
- 🧠 **Multi-LLM Orchestration** - Sequential thinking with OpenAI + Anthropic
- 💾 **Persistent Memory** - CosmosDB-backed conversation history
- 🛠 **100+ MCP Servers** - Extensive tool ecosystem integration
- 📁 **File Processing** - OneDrive, Azure File Share, multimodal support
- 🔍 **Web Search** - Brave Search integration
- 🔗 **Service Integration** - GitHub, Slack, Gmail, Notion, and more

## Architecture

```mermaid
graph TB
    subgraph "Frontend"
        A[React App with Azure B2C]
    end
    
    subgraph "Backend"
        B[Express.js API]
        C[MCP Server Manager]
        D[LLM Orchestrator]
    end
    
    subgraph "Data Layer"
        E[CosmosDB Memory]
        F[Azure File Share]
        G[OneDrive Integration]
    end
    
    subgraph "MCP Ecosystem"
        H[100+ MCP Servers]
    end
    
    A --> B
    B --> C
    B --> D
    D --> E
    B --> F
    B --> G
    C --> H