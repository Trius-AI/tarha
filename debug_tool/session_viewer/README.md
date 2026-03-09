# Session Viewer

A web-based debug tool for viewing and managing coding agent sessions.

## Features

- 📋 View all active sessions
- 📊 Session statistics (tokens, messages, tool calls)
- 💬 View conversation history
- 🔄 Auto-refresh capability
- ⏹ Halt sessions
- 📂 See open files per session

## Usage

### Start the Coding Agent HTTP Server

```bash
./coder-http 8080
```

### Open the Session Viewer

Open `index.html` in your browser:

```bash
# Using Python
python3 -m http.server 3000 --directory debug_tool/session_viewer

# Then open http://localhost:3000
```

Or simply open the file directly:
```bash
# Linux
xdg-open debug_tool/session_viewer/index.html

# macOS
open debug_tool/session_viewer/index.html

# Windows
start debug_tool/session_viewer/index.html
```

## API Endpoints Used

The session viewer connects to these HTTP API endpoints:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/sessions` | GET | List all sessions |
| `/status` | GET | Get agent status |
| `/session/:id` | GET | Get session details |
| `/session/:id/halt` | POST | Halt a session |

## Configuration

- **API URL**: Change the API URL in the input field (default: `http://localhost:8080`)
- **Auto-refresh**: Toggle automatic refresh every 5 seconds

## Session Card Info

Each session card displays:

- **Session ID** (truncated)
- **Status**: Idle (green) or Busy (yellow, pulsing)
- **Model**: Current AI model
- **Messages**: Number of messages in history
- **Tokens**: Estimated or actual token count
- **Tool Calls**: Number of tool invocations

## Session Detail Panel

Click on a session card or "Stats" button to see:

- Full session ID
- Model name
- Context window size
- Token usage breakdown
- Working directory
- Open files
- Full message history

## Development

The session viewer is a standalone HTML/CSS/JS application with no build step required.

```
session_viewer/
├── index.html    # Main HTML structure
├── style.css     # Styling
├── app.js        # Application logic
└── README.md     # This file
```

## Browser Compatibility

Works in modern browsers with:
- Fetch API
- ES6+ JavaScript
- CSS Grid/Flexbox