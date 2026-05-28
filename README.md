# chatGPTtoTerminalProxy

Chat-first file bridge for ChatGPT/Codex on macOS.

## Starter Guide

### 1. Open the project

- Use VS Code or Cursor
- Open this repository folder
- Open `.codex-inbox/chat.txt`
- Turn on autosave after delay

### 1a. Keep these apps open

- ChatGPT app
- VS Code with this repo open
- Terminal running `./.codex-inbox/watch-chat-first.sh`
- Optional: Cursor instead of VS Code

### 1b. Enable Work with Apps

- In ChatGPT, open `Work with Apps`
- Select VS Code
- Keep `.codex-inbox/chat.txt` open in VS Code
- Keep Terminal visible for watcher output

### 1c. Tutorial

See [`docs/tutorial.md`](docs/tutorial.md) for:
- plain HTML hello world
- npm project with `src` and bundler
- the default project rule of thumb

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
- `runMode`: `auto`
- `activateWatchOnSave.chat`: `true`
- `activateWatchOnSave.commands`: `true`

Return selects `Run` in the approval dialog.
`runMode` controls where commands run:
- `auto` sends blocking commands like `npm start` to a new Terminal session
- `inline` keeps everything in the watcher terminal
- `new-terminal` sends all approved commands to a new Terminal session
- `background` detaches approved commands into the background
`activateWatchOnSave` controls whether the watcher reacts to saved changes in each file.

### 3. Prepare the ChatGPT side

Use this as the instruction to ChatGPT:

```text
You are working in a chat-first local project bridge.
Read `.codex-inbox/memory.md` first.
Write prompts and investigation notes into `.codex-inbox/chat.txt`.
Grow the conversation in `.codex-inbox/conversation.md` as you learn more.
Use `.codex-inbox/last-output.md` before deciding the next step.
Only expose final shell commands in `.codex-inbox/commands.txt` at the end.
Do not put terminal commands in `chat.txt` unless you are still exploring.
Keep commands project-local unless I explicitly ask otherwise.
Wait for terminal output before continuing after a command run.
```

### 4. Use the chat-first flow

```text
Write your prompt or investigation goal into `.codex-inbox/chat.txt`.
Let the conversation grow in `.codex-inbox/conversation.md`.
Use the terminal to inspect the repo, search for context, or test ideas.
When you are ready to execute, write the final shell commands into `.codex-inbox/commands.txt`.
The watcher will ask for approval, then run them in this project folder.
```

### 5. Keep a short memory

- Use `.codex-inbox/memory.md` for stable facts only
- Keep it minimal
- Good entries:
  - project title
  - project path
  - branch name
  - one-line purpose
- Do not turn it into a transcript
- Read it first when you return to the project

### 6. What gets written where

- `.codex-inbox/chat.txt` - prompt input
- `.codex-inbox/memory.md` - short persistent memory
- `.codex-inbox/conversation.md` - growing conversation and terminal output
- `.codex-inbox/last-output.md` - latest command output snapshot
- `.codex-inbox/commands.txt` - final shell commands, kept visible after run
- `.codex-inbox/log.txt` - execution log
- `.codex-inbox/config.json` - project workflow settings
- `.codex-inbox/watch-chat-first.sh` - chat-first watcher
- `.vscode/settings.json` - editor defaults for this workflow

Legacy command bridge files were removed from this branch for clarity.

## Good Project Defaults

- Prefer one prompt per turn
- Prefer project-local investigation first
- Expose terminal commands only at the end in `commands.txt`
- Keep `commands.txt` visible; the watcher dedupes by content hash
- Keep `memory.md` tiny and durable
- Read `last-output.md` before deciding the next command
- Keep approvals human-visible
- Check `git status` before approving bigger commands

## Safety

- No blind `eval` path
- Human approval is required before execution
- `fswatch` is used when available, polling is the fallback
- The completion ping is best effort and may fail if macOS automation is blocked
