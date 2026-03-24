# Prehook.ai

A Claude Code plugin that streams lifecycle events to the Prehook.ai API for real-time analysis, observability, and tool-use gating.

## What it does

Every Claude Code session emits events — sessions starting, tools being invoked, agents spawning. This plugin captures those events and forwards them to your Prehook.ai dashboard.

For **PreToolUse** events, the API can respond with an allow/deny decision to block dangerous or unauthorized tool calls before they execute. All other events are fire-and-forget for observability.

### Tracked events

| Event | Description | Can block? |
|-------|-------------|------------|
| `SessionStart` | Session begins or resumes | No |
| `SessionEnd` | Session terminates | No |
| `PreToolUse` | Before a tool executes | **Yes** |
| `PostToolUse` | After a tool succeeds | No |
| `PostToolUseFailure` | After a tool fails | No |
| `Stop` | Claude finishes responding | No |
| `StopFailure` | Turn ends due to API error | No |
| `Notification` | Claude sends a notification | No |
| `SubagentStart` | A subagent spawns | No |
| `SubagentStop` | A subagent finishes | No |

## Prerequisites

- [Claude Code](https://claude.ai/code) CLI or VS Code extension
- [`jq`](https://jqlang.github.io/jq/download/) installed and on your PATH
- A Prehook.ai API key

## Setup

### 1. Create the config file

```bash
mkdir -p ~/.prehook
cat > ~/.prehook/config.json << 'EOF'
{
  "api_url": "https://www.prehook.ai/api/v1/events",
  "api_key": "YOUR_API_KEY"
}
EOF
```

Replace `YOUR_API_KEY` with the key from your Prehook.ai dashboard.

### 2. Install the plugin

In Claude Code, run:

```
/plugin marketplace add myleshosford/prehook-plugin
```

Then install the plugin:

```
/plugin install Hook-Plugin@myleshosford/prehook-plugin
```

Or use the interactive plugin manager by running `/plugin` and adding the marketplace from the **Marketplaces** tab.

Claude Code will prompt you to approve the plugin's hooks on first run.

### 3. Verify

Start a new Claude Code session and check the local log:

```bash
tail -f ~/.prehook/logs/events.log
```

You should see a `SessionStart` event appear.

## Configuration

### Config file (`~/.prehook/config.json`)

| Field | Required | Description |
|-------|----------|-------------|
| `api_url` | Yes | Prehook.ai API endpoint |
| `api_key` | Yes | Your API key (starts with `ph_`) |

### Environment variable overrides

For local development or testing, you can override config values with environment variables:

| Variable | Overrides |
|----------|-----------|
| `PREHOOK_API_URL` | `api_url` |
| `PREHOOK_API_KEY` | `api_key` |

## How PreToolUse blocking works

When Claude is about to use a tool, the plugin sends the event to your API **synchronously** (3s timeout). Your API can respond with:

**Allow the tool (default):**
```json
{ "decision": "allow" }
```

**Block the tool:**
```json
{ "decision": "deny", "reason": "Destructive command not permitted" }
```

The reason is shown to Claude as feedback. If the API is unreachable or times out, the plugin **fails open** (tool proceeds).

## Local logs

All events are logged locally for debugging:

| File | Contents |
|------|----------|
| `~/.prehook/logs/events.log` | All events sent |
| `~/.prehook/logs/failed-events.log` | Events that failed to send (non-2xx) |

## License

MIT
