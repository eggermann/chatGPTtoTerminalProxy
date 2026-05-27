# chatGPTtoTerminalProxy

Local file-based command bridge for ChatGPT/Codex on macOS.

## Layout

- `.codex-inbox/command.txt` - writable command slot
- `.codex-inbox/log.txt` - command output log
- `.codex-inbox/watch-codex.sh` - approval + execution loop

## Run

```bash
chmod +x .codex-inbox/watch-codex.sh
./.codex-inbox/watch-codex.sh
```

## Use

1. Have ChatGPT write one raw shell command into `.codex-inbox/command.txt`.
2. The watcher shows an approval dialog.
3. If approved, the command runs in this folder.
4. Output is appended to `.codex-inbox/log.txt`.
5. A completion ping is copied and sent back to ChatGPT if available.

## Safety

- No blind `eval` path.
- Human approval is required before execution.
- Keep commands scoped to this folder unless you explicitly want more reach.
