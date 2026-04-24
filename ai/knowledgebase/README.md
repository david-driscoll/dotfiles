# Local AI Knowledgebase

A local Neo4j knowledge graph builder running on Windows with LM Studio as the LLM backend.

## Prerequisites

- **Docker Desktop for Windows** — set ≥8 GiB memory in Docker Desktop → Settings → Resources
- **Git**
- **LM Studio** with `google/gemma-4-e2b` model loaded and running
  - Download from: https://lmstudio.ai/models/google/gemma-4-e2b
  - Enable "Local Server" in LM Studio, load the model
  - Default port: 1234

## Quick Start

1. Copy `.env.example` to `.env` and set `NEO4J_PASSWORD`
2. Run `.\run.ps1 --start`
3. Wait for all services to start

## Services

| Service | URL | Description |
|---------|-----|-------------|
| Neo4j Browser | http://localhost:7474 | Graph database UI |
| Neo4j Bolt | bolt://localhost:7687 | Bolt protocol connection |
| Graph Builder UI | http://localhost:8080 | LLM graph builder frontend |
| Graph Builder API | http://localhost:8082 | FastAPI backend |
| Neo4j MCP | http://localhost:8000/mcp/ | MCP server for AI agents |

## Commands

| Command | Description |
|---------|-------------|
| `.\run.ps1 --start` | Start all services |
| `.\run.ps1 --stop` | Stop graph builder (Neo4j keeps running) |
| `.\run.ps1 --stop --all` | Stop everything including Neo4j |
| `.\run.ps1 --reset-db` | Clear all graph data (destructive!) |
| `.\run.ps1 --help` | Show help |

## Architecture

Two Docker Compose stacks:

- **`neo4j/`** — Always-on: Neo4j database + MCP server
- **`graph-builder/`** — On-demand: llm-graph-builder backend + frontend

## LM Studio Setup

LM Studio must be running with the `google/gemma-4-e2b` model loaded **before** starting the graph builder stack. The model is accessed via its OpenAI-compatible API at `http://localhost:1234/v1`.

## Notes for Windows

- Docker Desktop must allocate enough memory (≥8 GiB recommended)
- `host.docker.internal` resolves to the Windows host from inside containers
- LM Studio server must be enabled (not just the model loaded)
