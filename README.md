# chatGPTtoTerminalProxy

Local file bridge for ChatGPT/Codex on macOS.

## Starter Guide

### 1. Open the project

- Use VS Code or Cursor
- Open this repository folder
- Open `.codex-inbox/command.txt`
- Turn on autosave

### 2. Start the watcher

```bash
chmod +x .codex-inbox/watch-codex.sh
./.codex-inbox/watch-codex.sh
```

### 3. Give ChatGPT this rule

```text
You control my local project through `.codex-inbox/command.txt`.
Write exactly one raw shell command into that file when you want the daemon to run something.
Rules:
- raw command only
- no markdown
- no explanation
- no destructive commands unless I explicitly ask
- prefer project-local paths
- wait for the terminal output after execution
```

### 4. Use it

1. Ask ChatGPT/Codex for the next command.
2. It writes the command into `.codex-inbox/command.txt`.
3. Approve the macOS dialog.
4. Read the result in the terminal or in `.codex-inbox/log.txt`.

## Project Layout

- `.codex-inbox/command.txt` - writable command slot
- `.codex-inbox/log.txt` - command output log
- `.codex-inbox/watch-codex.sh` - approval + execution loop
- `.vscode/settings.json` - editor defaults for this workflow

## Good Project Defaults

- Prefer one command per turn
- Prefer non-destructive commands
- Prefer project-local paths
- Use Git from the start if this becomes real work
- Check `git status` before approving bigger commands

## Safety

- No blind `eval` path
- Human approval is required before execution
- `fswatch` is used when available, polling is the fallback
- The completion ping is best effort and may fail if macOS automation is blocked
