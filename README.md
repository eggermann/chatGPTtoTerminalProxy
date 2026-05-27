# chatGPTtoTerminalProxy

Chat-first file bridge for ChatGPT/Codex on macOS.

## Starter Guide

### 1. Open the project

- Use VS Code or Cursor
- Open this repository folder
- Open `.codex-inbox/chat.txt`
- Turn on autosave

### 2. Start the watcher

```bash
chmod +x .codex-inbox/watch-chat-first.sh
./.codex-inbox/watch-chat-first.sh
```

The default config is in `.codex-inbox/config.json`.
- `workflow`: `chat-first`
- `approvalLevel`: `standard`
- `defaultButton`: `Run`
- `notifyChatGPT`: `true`

Return selects `Run` in the approval dialog.

### 3. Use the chat-first flow

```text
Write your prompt or investigation goal into `.codex-inbox/chat.txt`.
Let the conversation grow in `.codex-inbox/conversation.md`.
Use the terminal to inspect the repo, search for context, or test ideas.
When you are ready to execute, write the final shell commands into `.codex-inbox/commands.txt`.
The watcher will ask for approval, then run them in this project folder.
```

### 4. What gets written where

- `.codex-inbox/chat.txt` - prompt input
- `.codex-inbox/conversation.md` - growing conversation and terminal output
- `.codex-inbox/commands.txt` - final shell commands
- `.codex-inbox/log.txt` - execution log
- `.codex-inbox/config.json` - project workflow settings
- `.codex-inbox/watch-chat-first.sh` - chat-first watcher
- `.vscode/settings.json` - editor defaults for this workflow

## Good Project Defaults

- Prefer one prompt per turn
- Prefer project-local investigation first
- Expose terminal commands only at the end in `commands.txt`
- Keep approvals human-visible
- Check `git status` before approving bigger commands

## Safety

- No blind `eval` path
- Human approval is required before execution
- `fswatch` is used when available, polling is the fallback
- The completion ping is best effort and may fail if macOS automation is blocked
