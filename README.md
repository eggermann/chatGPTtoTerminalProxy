# chatGPTtoTerminalProxy

Chat-first file bridge for ChatGPT/Codex on macOS.

> EXPERIMENTAL
> Intended only for personal experimentation and stack-dependent tinkering.
> Not production-ready.

## Quickstart

### 1. Install the CLI

```bash
chmod +x ./bin/install-parasit.sh
./bin/install-parasit.sh
```

This installs a global `parasit` command so you can bootstrap any project from any shell.

### 2. Bootstrap a project

```bash
parasit setup /Users/eggermann/Desktop/speedProjects/modal-hacka
```

`parasit setup <path>` creates the project-local `.codex-inbox/`, writes the workspace settings, and starts the watcher.

If you pass a file path, `parasit` uses its parent folder. If you run it from inside a project folder, that folder name becomes the default session branch slug.

### 3. Keep the workflow open

- ChatGPT app
- VS Code with the target project open
- Terminal showing `./bin/watch-chat-first.sh`

### 4. Optional prompt-concator mode

Enable `promptConcator.enabled` in `.codex-inbox/config.json` if you want `input-prompt.txt` to stay updated automatically. The watcher then runs `npx --yes prompt-concator --watch` and reads `prompt.config.json` from the project root when present.

### 5. Session flow

If the project is already bootstrapped, `./parasit.sh fresh` starts a new session branch and launches the watcher automatically.

The important inbox files are:

- `.codex-inbox/chat.txt` for prompts
- `.codex-inbox/commands.txt` for final shell commands
- `.codex-inbox/memory.md` for short persistent memory
- `.codex-inbox/last-output.md` for the latest command output

Use [`docs/tutorial.md`](docs/tutorial.md) for the longer examples.

### 6. ChatGPT instruction

```text
You are working in a chat-first local project bridge.
Read `.codex-inbox/memory.md` first.
If `input-prompt.txt` exists and is maintained by prompt-concator, read it before scanning the repo manually.
Treat `input-prompt.txt` as generated project context; if it looks stale, update `prompt.config.json` or rerun `npx prompt-concator` instead of pasting ad-hoc file dumps into chat.
Write prompts and investigation notes into `.codex-inbox/chat.txt`.
Grow the conversation in `.codex-inbox/conversation.md` as you learn more.
Use `.codex-inbox/last-output.md` before deciding the next step.
Only expose final shell commands in `.codex-inbox/commands.txt` at the end.
Do not put terminal commands in `chat.txt` unless you are still exploring.
Keep commands project-local unless I explicitly ask otherwise.
Wait for terminal output before continuing after a command run.
Do not mention or rely on `oboe.edit_file`.
If direct file editing is unavailable, create or modify files with shell commands in `.codex-inbox/commands.txt`.
```

### 7. More docs

- [`docs/parasit.de.md`](docs/parasit.de.md) for the short German overview
- [`docs/parasit-manual.de.md`](docs/parasit-manual.de.md) for the long manual

## Good Project Defaults

- Prefer one prompt per turn
- Prefer project-local investigation first
- Expose terminal commands only at the end in `commands.txt`
- `commands.txt` is consumed and cleared after approval
- Keep `memory.md` tiny and durable
- Read `last-output.md` before deciding the next command
- `last-output.md` is the output trigger; watcher pings ChatGPT after it changes
- if `autocommit` is `true` and the command succeeds, the watcher stages and commits changes, and the ping says `Output ready. Commit ready.`
- the file is replaced only after the command finishes
- the header includes `session_id`, `source`, and `command`
- For manual terminals, use `./bin/capture-output.sh "<command>"`
- Keep approvals human-visible
- Check `git status` before approving bigger commands

## Safety

- No blind `eval` path
- Human approval is required before execution
- `fswatch` is used when available, polling is the fallback
- The completion ping is best effort and may fail if macOS automation is blocked
