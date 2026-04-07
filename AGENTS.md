# Coding Agent - Erlang Implementation

This is an Erlang-based coding agent using Ollama with tool calling capabilities.

## Project Structure

```
src/
├── coding_agent.app.src          # App config
├── coding_agent_app.erl          # Application module
├── coding_agent_sup.erl          # Supervisor
├── coding_agent_ollama.erl       # Ollama API client
├── coding_agent_tools.erl        # 30+ tools (read_file, write_file, etc.)
├── coding_agent.erl              # Single-shot agent
├── coding_agent_session_sup.erl  # Session supervisor
├── coding_agent_session.erl      # Conversational session
├── coding_agent_self.erl         # Self-modification, checkpoints
├── coding_agent_healer.erl       # Crash analysis, auto-fix
├── coding_agent_process_monitor.erl # Process monitoring, GC, crash tracking
├── coding_agent_conv_memory.erl  # Conversational memory (MEMORY.md + HISTORY.md)
├── coding_agent_skills.erl       # Skills loader (workspace + builtin)
├── coding_agent_repl.erl         # Interactive REPL
├── coding_agent_cli.erl          # CLI interface
└── coding_agent_config.erl       # Config loader

priv/
└── skills/
    └── example/SKILL.md          # Example builtin skill

skills/                           # Workspace skills (user-defined)
└── my-skill/SKILL.md

memory/
├── MEMORY.md                     # Long-term memory (facts, preferences)
└── HISTORY.md                    # Grep-searchable conversation history

config.yaml                        # Example configuration
coder                              # REPL launcher script
rebar.config                       # Dependencies: hackney, jsx
```

## Build & Run

```bash
# Build
rebar3 compile

# Run REPL
./coder
```

## Conversational Memory

The agent has a two-layer memory system similar to nanobot:

1. **MEMORY.md** - Long-term memory storing facts, preferences, and important info
2. **HISTORY.md** - Grep-searchable log of conversations with timestamps

Memory is automatically included in the system prompt for all sessions, allowing the agent to remember preferences and context across sessions.

### Memory Consolidation

When triggered (either manually or automatically after enough messages), the agent uses an LLM to:
1. Summarize old conversations into HISTORY.md entries
2. Extract important facts and update MEMORY.md

## Model Configuration

Set the model via environment variable:
```bash
OLLAMA_MODEL=glm-5:cloud ./coder
```

Or in `config.yaml`:
```yaml
ollama:
  model: glm-5:cloud
  host: http://localhost:11434
```

## Architecture Notes

- Sessions stored in ETS table `coding_agent_sessions`
- Conversational memory stored in `memory/MEMORY.md` and `memory/HISTORY.md`
- Tool calling requires `think: true` flag in Ollama API

## IMPORTANT

- THIS IS NOT A NODE PROJECT, THIS IS NOT A NODE PROJECT, THIS IS NOT A NODE PROJECT, DO NOT USE NPM TEST. DO NOT USE NPM TEST. DO NOT USE NPM TEST.